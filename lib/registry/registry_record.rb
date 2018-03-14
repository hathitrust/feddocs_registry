require 'mongoid'
require 'securerandom'
require 'pp'
require 'registry/source_record'
require 'registry/collator'
require 'mysql2'

module Registry
  # Registry Records are defined as a cluster of Source bib records and a
  # unique enumeration/chronology string (sometimes the empty string).
  # Fields are extracted from the base source fields and stored for
  # convenience.
  class RegistryRecord
    include Mongoid::Document
    include Mongoid::Attributes::Dynamic
    store_in collection: 'registry'
    field :registry_id, type: String
    field :last_modified, type: DateTime
    field :ancestors, type: Array
    field :deprecated_reason, type: String
    field :deprecated_timestamp, type: DateTime
    field :series, type: Array, default: []
    field :source_record_ids, type: Array
    field :source_org_codes, type: Array
    field :creation_notes, type: String
    field :enumchron_display, type: String
    field :suppressed, type: Boolean, default: false
    field :ht_ids_fv
    field :ht_ids_lv
    field :ht_availability
    field :subject_t
    field :author_lccns, type: Array
    field :added_entry_lccns, type: Array
    field :electronic_resources, type: Array
    field :print_holdings_t, type: Array

    @@collator = Collator.new(__dir__ + '/../../config/'\
                                        'traject_registry_record_config.rb')
    @@db_conn = Mysql2::Client.new(host: ENV['db_host'],
                                   username: ENV['db_user'],
                                   password: ENV['db_pw'],
                                   database: ENV['db_name'],
                                   reconnect: true)

    # Creates RegistryRecord.
    #
    # sid_cluster - Array of source record ids.
    # enum_chron  - Enumeration/chronology string. Possibly "".
    # notes       - Tracks reason for creation, e.g. merge or split.
    # ancestors   - Tracks id for deprecated RegistryRecords this was split or
    #               merged from.
    def initialize(sid_cluster, enum_chron, notes, ancestors = nil)
      super()
      # collate the source records into a coherent whole
      self.source_record_ids = sid_cluster
      self.source_org_codes ||= []
      @sources = SourceRecord.where(:source_id.in => sid_cluster)
      @@collator.extract_fields(@sources)\
                .each_with_index { |(k, v), _i| self[k] = v }

      @sources.each do |src|
        if src.series&.any?
          self.series = src.series.map { |s| s.gsub(/([A-Z])/, ' \1').strip }
        end
      end
      series.uniq!

      self.ancestors = ancestors
      self.creation_notes = notes
      self.registry_id ||= SecureRandom.uuid
      self.enumchron_display = enum_chron
      set_ht_availability
      if (print_holdings_t.nil? || print_holdings_t.count.zero?) &&
         oclcnum_t.any?
        print_holdings
      end
    end

    # Sets HT availability based on ht_ids_fv and ht_ids_lv fields
    def set_ht_availability
      self.ht_availability = if ht_ids_fv.any?
                               'Full View'
                             elsif ht_ids_lv.any?
                               'Limited View'
                             else
                               'Not In HathiTrust'
                             end
    end

    # Adds a source record to the cluster.
    #
    # source_record - SourceRecord object
    #
    # So we don't have to recollate an entire cluster for the
    # addition of one rec
    def add_source(source_record)
      # if it's already in this record then we have to recollate.
      # otherwise we have no way of removing old data extractions
      if source_record_ids.include? source_record.source_id
        recollate
      else
        source_record_ids << source_record.source_id
        self.source_org_codes << source_record.org_code
        @@collator.extract_fields([source_record]).each do |field, value|
          self[field] ||= []
          self[field] << value
          self[field] = self[field].flatten.uniq
        end
        source_record_ids.uniq!
        self.source_org_codes.uniq!
        if source_record.series&.any?
          self.series = source_record.series.map do |s|
            s.gsub(/([A-Z])/, ' \1').strip
          end
          series.uniq!
        end
      end
      set_ht_availability
      save
    end

    # Runs the collation of source records again.
    # Typically performed after a source record has been added or updated.
    def recollate
      @sources = SourceRecord.where(:source_id.in => source_record_ids)
      self.source_org_codes = @sources.collect(&:org_code)
      self.source_org_codes.uniq!
      @@collator.extract_fields(@sources)
                .each_with_index { |(k, v), _i| self[k] = v }
      save
    end

    # Splits registry record into two or more successor records.
    # Deprecates self.
    #
    # sid_clusters - hash of arrays to enum/chron
    #                {[source_ids]: "enum_chron", [source_ids]: "enum_chron"}
    # reason       - Why?
    #
    # Examples
    #  rec.split({ ["<sid_1>", "<sid_2>"] => "v. 1",
    #              ["<sid_3>", "<sid_4>"] => "v. 1"},
    #            "We were wrong. Not related.")
    #  rec.split({ ["<sid_1>", "<sid_2>"] => "v. 1",
    #              ["<sid_3>"] => "v. 4"},
    #            "Looked in the wrong spot for the enum/chrons.")
    def split(sid_clusters, reason)
      new_recs = []
      sid_clusters.each do |cluster, enum_chron|
        new_recs << RegistryRecord.new(cluster,
                                       enum_chron,
                                       reason,
                                       [self.registry_id])
      end

      deprecate(reason, new_recs.collect(&:registry_id))
      save
      new_recs
    end

    # Deprecation of a RegistryRecord.
    # Caused by splits, merges, or out of scope. Tracks successor records
    # from splits and merges.
    def deprecate(reason, successors = nil)
      # successors is an optional array of new RegistryRecordsthat replaced this
      self.deprecated_reason = reason
      self.deprecated_timestamp = Time.now.utc
      self.suppressed = true
      self[:successors] = successors if successors

      save
    end

    # Merging of two or more RegistryRecords.
    # Deprecates ancestor records.
    #
    # ids - RegistryRecord ids that will be replaced with a new record.
    # enum_chon
    # reason
    def self.merge(ids, enum_chron, reason)
      # merge existing reg records
      recs = RegistryRecord.where(:registry_id.in => ids)
      all_src_ids = recs.collect(&:source_record_ids).flatten.uniq
      new_rec = RegistryRecord.new(all_src_ids, enum_chron, reason, ids)
      new_rec.save
      recs.each { |r| r.deprecate(reason, [new_rec.registry_id]) }
      new_rec
    end

    # Collect the SourceRecords based on source_record_ids.
    #
    # todo: Possible to do this with something built into MongoDB or Mongoid?
    def sources
      @sources ||= SourceRecord.where(:source_id.in => source_record_ids)
      @sources
    end

    # If any of the source records are for monograph bibs
    # return true
    def monograph?
      sources.select { |s| s.source['leader'] =~ /^.{7}m/ }.any?
    end

    def save
      # make sure our source records are uniq and that we have 1
      self.source_record_ids = source_record_ids.uniq
      raise 'No source recs for this Reg Rec' if source_record_ids.count.zero?
      self.last_modified = Time.now.utc
      super
    end

    # Find a RegistryRecord that matches the given source record and enumchron
    #
    # s - a SourceRecord
    # enum_chron - an enumchron string
    def self.cluster(s, enum_chron)
      # OCLC first
      if s.oclc_resolved.any?
        rec = RegistryRecord.where(oclcnum_t: s.oclc_resolved,
                                   enumchron_display: enum_chron,
                                   deprecated_timestamp: { "$exists": 0 }).first
      end
      # lccn
      if s.lccn_normalized.any? && !rec
        rec = RegistryRecord.where(lccn_t: s.lccn_normalized,
                                   enumchron_display: enum_chron,
                                   deprecated_timestamp: { "$exists": 0 }).first
      end
      # isbn
      if s.isbns_normalized.any? && !rec
        rec = RegistryRecord.where(isbn_t: s.isbns_normalized,
                                   enumchron_display: enum_chron,
                                   deprecated_timestamp: { "$exists": 0 }).first
      end
      # issn
      if s.issn_normalized.any? && !rec
        rec = RegistryRecord.where(issn_t: s.issn_normalized,
                                   enumchron_display: enum_chron,
                                   deprecated_timestamp: { "$exists": 0 }).first
      end
      # sudoc
      if s.sudocs.any? && !rec
        rec = RegistryRecord.where(sudoc_display: s.sudocs,
                                   enumchron_display: enum_chron,
                                   deprecated_timestamp: { "$exists": 0 }).first
      end
      rec
    end

    def print_holdings(oclcs = nil)
      oclcs ||= oclcnum_t
      self.print_holdings_t = []
      if oclcs.any?
        get_holdings = "SELECT DISTINCT(member_id) from holdings_memberitem
                        WHERE oclc IN(#{@@db_conn.escape(oclcs.join(','))})"
        @results = @@db_conn.query(get_holdings)
        @results.each do |row|
          print_holdings_t << row['member_id']
        end
      end
      print_holdings_t.uniq
    end
  end
end
