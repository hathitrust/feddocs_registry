require 'mongoid'
require 'securerandom'
require 'pp'
require 'registry/source_record'
require 'registry/collator'

module Registry
  class RegistryRecord
    include Mongoid::Document
    include Mongoid::Attributes::Dynamic
    store_in collection: "registry"
    field :registry_id, type: String
    field :last_modified, type: DateTime
    field :ancestors, type: Array
    field :deprecated_reason, type: String
    field :deprecated_timestamp, type: DateTime
    field :series, type: String
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

    @@collator = Collator.new(__dir__+'/../../config/traject_config.rb')
    @@db_conn = Mysql2::Client.new(:host => ENV['db_host'], 
                              :username => ENV['db_user'],
                              :password => ENV['db_pw'],
                              :database => ENV['db_name'],
                              :reconnect => true
                             )


    # Creates RegistryRecord. 
    # 
    # sid_cluster - Array of source record ids. 
    # enum_chron  - Enumeration/chronology string. Possibly "". 
    # notes       - Tracks reason for creation, e.g. merge or split.
    # ancestors   - Tracks id for deprecated RegistryRecords this was split or
    #               merged from.  
    def initialize( sid_cluster, enum_chron, notes, ancestors=nil )
      super()
      #collate the source records into a coherent whole 
      self.source_record_ids = sid_cluster
      self.source_org_codes ||= []
      @sources = SourceRecord.where(:source_id.in => sid_cluster)
      @@collator.extract_fields(@sources).each_with_index {|(k,v),i| self[k] = v}
        
      @sources.each do |s|
        if !s.series.nil? and s.series != ''
          self.series = s.series.gsub(/([A-Z])/, ' \1').strip
        end
      end

      self.ancestors = ancestors
      self.creation_notes = notes
      self.registry_id ||= SecureRandom.uuid()
      self.enumchron_display = enum_chron
      self.set_ht_availability()
    end  

    # Sets HT availability based on ht_ids_fv and ht_ids_lv fields
    def set_ht_availability
      if self.ht_ids_fv.count > 0 
        self.ht_availability = 'Full View'
      elsif self.ht_ids_lv.count > 0 
        self.ht_availability = 'Limited View'
      else
        self.ht_availability = 'Not In HathiTrust'
      end
    end


    # Adds a source record to the cluster. 
    #
    # source_record - SourceRecord object
    #
    # So we don't have to recollate an entire cluster for the addition of one rec
    def add_source source_record
      # if it's already in this record then we have to recollate.
      # otherwise we have no way of removing old data extractions
      if self.source_record_ids.include? source_record.source_id
        self.recollate
      else
        self.source_record_ids << source_record.source_id
        self.source_org_codes << source_record.org_code
        @@collator.extract_fields([source_record]).each do | field, value |
          self[field] ||= []
          self[field] << value
          self[field] = self[field].flatten.uniq
        end
        self.source_record_ids.uniq!
        self.source_org_codes.uniq!
        if !source_record.series.nil? and source_record.series != ''
          self.series = source_record.series.gsub(/([A-Z])/, ' \1').strip
        end
      end
      self.set_ht_availability() 
      self.save
    end

    # Runs the collation of source records again. 
    # Typically performed after a source record has been added or updated. 
    def recollate 
      @sources = SourceRecord.where(:source_id.in => self.source_record_ids)
      self.source_org_codes = @sources.collect {|s| s.org_code}
      self.source_org_codes.uniq!
      @@collator.extract_fields(@sources).each_with_index {|(k,v),i| self[k] = v}
      self.save
    end

    # Splits registry record into two or more successor records.
    # Deprecates self. 
    #
    # sid_clusters - hash of arrays to enum/chron
    #                {[source_ids] => "enum_chron", [source_ids] => "enum_chron"}
    # reason       - Why? 
    # 
    # Examples 
    #  rec.split({ ["<sid_1>", "<sid_2>"] => "v. 1", 
    #              ["<sid_3>", "<sid_4>"] => "v. 1"},
    #            "We were wrong. Not related.")
    #  rec.split({ ["<sid_1>", "<sid_2>"] => "v. 1",
    #              ["<sid_3>"] => "v. 4"},
    #            "Looked in the wrong spot for the enum/chrons.")
    def split( sid_clusters, reason )
      new_recs = []
      sid_clusters.each do | cluster, enum_chron |
        new_recs << RegistryRecord.new(cluster, enum_chron, reason, [self.registry_id])
      end
      
      self.deprecate(reason, new_recs.collect{|r| r.registry_id})
      self.save 
      return new_recs
    end

    # Deprecation of a RegistryRecord. 
    # Caused by splits, merges, or out of scope. Tracks successor records
    # from splits and merges. 
    def deprecate( reason, successors=nil )
      #successors is an optional array of new RegistryRecords that replaced this one
      self.deprecated_reason = reason
      self.deprecated_timestamp = Time.now.utc
      self.suppressed = true
      if successors 
        self[:successors] = successors
      end

      self.save
    end

    # Merging of two or more RegistryRecords. 
    # Deprecates ancestor records.
    #
    # ids - RegistryRecord ids that will be replaced with a new record.
    # enum_chon 
    # reason
    def RegistryRecord.merge( ids, enum_chron, reason )
      #merge existing reg records
      recs = RegistryRecord.where(:registry_id.in => ids) 
      new_rec = RegistryRecord.new(recs.collect { |r| r.source_record_ids }.flatten.uniq, enum_chron, reason, ids)
      new_rec.save
      recs.each {|r| r.deprecate( reason, [new_rec.registry_id] )}
      return new_rec
    end

    # Collect the SourceRecords based on source_record_ids.
    # 
    # todo: Possible to do this with something built into MongoDB or Mongoid?
    def sources
      @sources ||= SourceRecord.where(:source_id.in => self.source_record_ids)
      return @sources
    end

    # If any of the source records are for monograph bibs
    # return true
    def is_monograph?
      self.sources.select {|s| s.source['leader'] =~ /^.{7}m/}.count > 0 
    end

    def save
      #make sure our source records are uniq and that we have 1
      self.source_record_ids = self.source_record_ids.uniq
      if self.source_record_ids.count == 0
        raise "No source records for this Reg Rec"
      end
      self.last_modified = Time.now.utc
      super
    end


    # Find a RegistryRecord that matches the given source record and enumchron
    #
    # s - a SourceRecord
    # enum_chron - an enumchron string
    def RegistryRecord.cluster( s, enum_chron )
      # OCLC first
      if s.oclc_resolved.count > 0
        rec = RegistryRecord.where(oclcnum_t: s.oclc_resolved, 
                                   enumchron_display: enum_chron,
                                   deprecated_timestamp:{"$exists":0}).first
      end
      # lccn
      if s.lccn_normalized.count > 0 and !rec
        rec = RegistryRecord.where(lccn_t: s.lccn_normalized,
                                   enumchron_display:enum_chron,
                                   deprecated_timestamp:{"$exists":0}).first
      end 
      # isbn
      if s.isbns_normalized.count > 0 and !rec
        rec = RegistryRecord.where(isbn_t: s.isbns_normalized,
                                   enumchron_display:enum_chron,
                                   deprecated_timestamp:{"$exists":0}).first
      end
      # issn
      if s.issn_normalized.count > 0 and !rec
        rec = RegistryRecord.where(issn_t: s.issn_normalized,
                                   enumchron_display:enum_chron,
                                   deprecated_timestamp:{"$exists":0}).first
      end
      # sudoc
      if s.sudocs.count > 0 and !rec
        rec = RegistryRecord.where(sudoc_display: s.sudocs,
                                   enumchron_display: enum_chron,
                                   deprecated_timestamp:{"$exists":0}).first
      end
      return rec
    end
    
    def print_holdings(oclcs=nil)
      oclcs ||= self.oclcnum_t
      self.print_holdings_t = []
      if oclcs.count > 0
        get_holdings = "SELECT DISTINCT(member_id) from holdings_memberitem 
                        WHERE oclc IN(#{@@db_conn.escape(oclcs.join(','))})"
        @results = @@db_conn.query(get_holdings)
        @results.each do |row|
          self.print_holdings_t << row['member_id']
        end
      end
      self.print_holdings_t.uniq 
    end  
  end

end
