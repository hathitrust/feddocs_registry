require 'mongoid'
require 'securerandom'
require 'marc'
require 'pp'
require 'dotenv'
require 'registry/collator'
require 'registry/series'
require 'yaml'
require 'digest'
require 'filter/blacklist'
require 'filter/whitelist'
require 'filter/authority_list'
require 'nauth/authority'
require 'oclc_authoritative'
Authority = Nauth::Authority

Dir[File.dirname(__FILE__) + '/series/*.rb'].each { |file| require file }

module Registry
  # Source Record is a MARC bibliographic record along with extracted and
  # calculated features.
  class SourceRecord
    include Mongoid::Document
    include Mongoid::Attributes::Dynamic
    include Registry::Series
    include OclcAuthoritative
    store_in collection: 'source_records'

    field :author_parts
    field :author_headings
    field :author_lccns, type: Array
    field :added_entry_lccns, type: Array
    field :author_addl_headings
    field :cataloging_agency
    field :deprecated_reason, type: String
    field :deprecated_timestamp, type: DateTime
    field :electronic_resources, type: Array
    field :electronic_versions, type: Array
    field :enum_chrons
    field :ec
    field :file_path, type: String
    field :formats, type: Array
    field :gpo_item_numbers, type: Array
    field :holdings
    field :ht_item_ids
    field :in_registry, type: Boolean, default: false
    field :isbns
    field :isbns_normalized
    field :issn_normalized
    field :lccn_normalized
    field :last_modified, type: DateTime
    field :line_number, type: Integer
    field :local_id, type: String
    field :oclc_alleged
    field :oclc_resolved
    field :org_code, type: String, default: 'miaahdl'
    field :pub_date
    field :publisher_headings
    field :report_numbers, type: Array
    field :series, type: Array, default: []
    field :source
    field :source_id, type: String
    field :sudocs
    field :invalid_sudocs # bad MARC, not necessarily bad SuDoc
    field :non_sudocs
    attr_writer :marc

    # this stuff is extra ugly
    Dotenv.load
    @@extractor = Traject::Indexer.new
    source_traject = __dir__ + '/../../config/traject_source_record_config.rb'
    @@extractor.load_config_file(source_traject)

    @@contrib001 = {}
    open(__dir__ + '/../../config/contributors_w_001_oclcs.txt').each do |l|
      @@contrib001[l.chomp] = 1
    end

    @@marc_profiles = {}

    # OCLCPAT taken from traject, except middle o made optional
    OCLCPAT =
      %r{
          \A\s*
          (?:(?:\(OCo?LC\)) |
      (?:\(OCo?LC\))?(?:(?:ocm)|(?:ocn)|(?:on))
      )(\d+)
      }x

    def initialize(*args)
      super
      self.source_id ||= SecureRandom.uuid
    end

    def marc
      @marc ||= MARC::Record.new_from_hash(source)
    end

    # On assignment of source json string, record is parsed,
    # and identifiers extracted.
    def source=(value)
      @source = JSON.parse(value)
      super(fix_flasus(org_code, @source))
      self.local_id = extract_local_id
      @marc = MARC::Record.new_from_hash(source)
      @extracted = @@extractor.map_record marc
      self.pub_date = @extracted['pub_date']
      self.gpo_item_numbers = @extracted['gpo_item_number'] || []
      self.publisher_headings = @extracted['publisher_heading'] || []
      self.author_headings = @extracted['author_t'] || []
      self.author_parts = @extracted['author_parts'] || []
      self.report_numbers = @extracted['report_numbers'] || []
      extract_identifiers
      electronic_resources
      related_electronic_resources
      electronic_versions
      author_lccns
      added_entry_lccns
      self.series = series # important to do this before extracting enumchrons
      self.ec = extract_enum_chrons
      self.enum_chrons = ec.collect do |_k, fields|
        if !fields['canonical'].nil?
          fields['canonical']
        else
          fields['string']
        end
      end
      enum_chrons << '' if enum_chrons.count.zero?
      extract_holdings marc if org_code == 'miaahdl'
    end

    # A source record may be deprecated if it is out of scope.
    #
    # Typically a RegistryRecord should be identified as out of scope, then
    # associated SourceRecords are dealt with.
    def deprecate(reason)
      self.deprecated_reason = reason
      self.deprecated_timestamp = Time.now.utc
      save
    end

    # Extracts and normalizes identifiers from self.source
    def extract_identifiers
      self.org_code ||= '' # should be set on ingest.
      self.oclc_alleged ||= []
      self.oclc_resolved ||= []
      self.lccn_normalized ||= []
      self.issn_normalized ||= []
      self.sudocs ||= []
      self.invalid_sudocs ||= []
      self.non_sudocs ||= []
      self.isbns ||= []
      self.isbns_normalized ||= []
      self.formats ||= []

      extract_oclcs
      extract_sudocs
      extract_lccns
      extract_issns
      extract_isbns
      self.formats = Traject::Macros::MarcFormatClassifier.new(marc).formats

      self.oclc_resolved = oclc_alleged.map { |o| resolve_oclc(o) }.flatten.uniq
    end

    # Extract the contributing institutions id for this record.
    # Enables update/replacement of source records.
    #
    # Assumes "001" if no field is provided.
    def extract_local_id(field = nil)
      field ||= '001'
      begin
        id = source['fields'].find { |f| f[field] }[field].delete(' ')
        # this will eliminate leading zeros but only for actual integer ids
        id.gsub!(/^0+/, '') if id.match?(/^[0-9]+$/)
      rescue StandardError
        # the field doesn't exist
        id = ''
      end
      id
    end

    # Determine HT availability. 'Full View', 'Limited View', 'not available'
    #
    def ht_availability
      return unless self.org_code == 'miaahdl'
      availability = 'Limited View'
      marc.each_by_tag('974') do |field|
        availability = 'Full View' if field['r'] == 'pd'
      end
      availability
    end

    # Determine if this is a feddoc based on 008 and 086 and 074
    # and OCLC blacklist
    # marc - ruby-marc repesentation of source
    def fed_doc?(m = nil)
      @marc = m unless m.nil?

      # check the blacklist
      self.oclc_resolved.each do |o|
        return true if Whitelist.oclcs.include? o
        return false if Blacklist.oclcs.include? o
      end

      u_and_f? ||
        self.sudocs.count.positive? ||
        extract_sudocs(marc).count.positive? ||
        gpo_item_numbers.count.positive? ||
        approved_author?
    end

    # The 008 field contains a place of publication code at the 17th position,
    # and a governemnt publication code at the 28th.
    # https://www.loc.gov/marc/bibliographic/bd008.html
    def u_and_f?(m = nil)
      @marc = m unless m.nil?
      /^.{17}u.{10}f/.match? @marc['008']&.value
    end

    # Check author_lccns against the list of approved authors
    def approved_author?
      AuthorityList.lccns.intersection(author_lccns).count.positive?
    end

    # Check added_entry_lccns against the list of approved authors
    def approved_added_entry?
      AuthorityList.lccns.intersection(added_entry_lccns).count.positive?
    end

    # Extracts SuDocs
    #
    # marc - ruby-marc representation of source
    def extract_sudocs(m = nil)
      @marc = m unless m.nil?
      self.sudocs = []
      self.invalid_sudocs = [] # curiosity
      self.non_sudocs = []

      marc.each_by_tag('086') do |field|
        # Supposed to be in 086/ind1=0, but some records are dumb.
        if field['a']
          # $2 says its not a sudoc
          # except sometimes $2 is describing subfield z and
          # subfield a is in fact a SuDoc... seriously
          if !field['2'].nil? && field['2'] !~ /^sudoc/i && field['z'].nil?
            self.non_sudocs << field['a'].chomp
            # if ind1 == 0 then it is also bad MARC
            self.invalid_sudocs << field['a'].chomp if field.indicator1 == '0'

          # ind1 says it is
          elsif field.indicator1 == '0' # and no subfield $2 or $2 is sudoc
            self.sudocs << field['a'].chomp

          # sudoc in $2 and it looks like one
          elsif field['a'] =~ /:/ && field['2'] =~ /^sudoc/i
            self.sudocs << field['a'].chomp

          # it looks like one and it isn't telling us it isn't
          # bad MARC but too many to ignore
          elsif (field.indicator1.strip == '') &&
                field['a'] =~ /:/ &&
                field['a'] !~ /^IL/ &&
                field['2'].nil?
            self.sudocs << field['a'].chomp
            self.invalid_sudocs << field['a'].chomp

          # bad MARC and probably not a sudoc
          elsif (field.indicator1.strip == '') && field['2'].nil?
            self.invalid_sudocs << field['a'].chomp
          end
        end
      end
      self.non_sudocs.uniq!
      self.invalid_sudocs.uniq!
      self.sudocs.uniq!
      self.sudocs = (self.sudocs - self.non_sudocs).map { |s| fix_sudoc s }
      self.sudocs
    end

    # takes a SuDoc string and tries to repair it if mangled
    def fix_sudoc(sstring)
      sstring.sub(/^II0 +a/, '')
    end

    def extract_oclcs(m = nil)
      @marc = m unless m.nil?
      self.oclc_alleged = []
      # 035a and 035z
      marc.each_by_tag('035') do |field|
        if field['a'] && OCLCPAT.match(field['a'])
          oclc = ::Regexp.last_match(1).to_i
          self.oclc_alleged << oclc if oclc
        end
      end

      # OCLC prefix in 001
      # or contributor told us to look there
      marc.each_by_tag('001') do |field|
        if OCLCPAT.match(field.value) ||
           (@@contrib001[self.org_code] && field.value =~ /^(\d+)$/x)
          self.oclc_alleged << ::Regexp.last_match(1).to_i
        end
      end

      # Indiana told us 955$o. Not likely, but...
      if self.org_code == 'inu'
        marc.each_by_tag('955') do |field|
          field.subfields.each do |sf|
            if (sf.code == 'o') && sf.value =~ /(\d+)/
              self.oclc_alleged << ::Regexp.last_match(1).to_i
            end
          end
        end
      end

      # We don't care about different physical forms so
      # 776s are valid too.
      marc.each_by_tag('776') do |field|
        subfield_ws = field.find_all { |subfield| subfield.code == 'w' }
        subfield_ws.each do |sub|
          self.oclc_alleged << ::Regexp.last_match(1).to_i if OCLCPAT.match(sub.value)
        end
      end

      self.oclc_alleged = self.oclc_alleged.flatten.uniq
      # if it's bigger than 8 bytes, definitely not valid.
      # (and can't be saved to Mongo anyway)
      self.oclc_alleged.delete_if { |x| x.size > 8 }
    end

    #######
    # LCCN
    def extract_lccns(m = nil)
      @marc = m unless m.nil?
      self.lccn_normalized = []

      marc.each_by_tag('010') do |field|
        if field['a'] && (field['a'] != '')
          field_a = field['a'].sub(/^@@/, '')
          self.lccn_normalized << StdNum::LCCN.normalize(field_a.downcase)
        end
      end
      self.lccn_normalized.delete(nil)
      self.lccn_normalized.uniq!
      self.lccn_normalized
    end

    ########
    # ISSN
    def extract_issns(m = nil)
      @marc = m unless m.nil?
      self.issn_normalized = []

      marc.each_by_tag('022') do |field|
        if field['a'] && (field['a'] != '')
          self.issn_normalized << StdNum::ISSN.normalize(field['a'])
        end
      end

      # We don't care about different physical forms so
      # 776s are valid too.
      marc.each_by_tag('776') do |field|
        subfield_xs = field.find_all { |subfield| subfield.code == 'x' }
        subfield_xs.each do |sub|
          self.issn_normalized << StdNum::ISSN.normalize(sub.value)
        end
      end
      self.issn_normalized.delete(nil)
      self.issn_normalized.uniq!
      self.issn_normalized
    end

    #######
    # ISBN
    # todo: this needs a test
    def extract_isbns(m = nil)
      @marc = m unless m.nil?
      self.isbns_normalized = []

      marc.each_by_tag('020') do |field|
        next unless field['a'] && (field['a'] != '')
        self.isbns << field['a']
        isbn = StdNum::ISBN.normalize(field['a'])
        self.isbns_normalized << isbn if isbn && (isbn != '')
      end

      # We don't care about different physical forms so
      # 776s are valid too.
      marc.each_by_tag('776') do |field|
        subfield_zs = field.find_all { |subfield| subfield.code == 'z' }
        subfield_zs.each do |sub|
          self.isbns_normalized << StdNum::ISBN.normalize(sub.value)
        end
      end
      self.isbns_normalized.delete(nil)
      self.isbns_normalized.uniq!
      self.isbns_normalized
    end

    # extract_enum_chron_strings
    # Finds the correct marc field and returns and array of enumchrons
    def extract_enum_chron_strings(m = nil)
      ec_strings = []
      @marc = m unless m.nil?
      tag, subcode = @@marc_profiles[self.org_code]['enum_chrons'].split(/ /)
      marc.each_by_tag(tag) do |field|
        subfield_codes = field.find_all { |subfield| subfield.code == subcode }
        if subfield_codes.count.positive?
          if self.org_code == 'dgpo'
            # take the second one if it's from gpo?
            if subfield_codes.count > 1
              ec_strings << Normalize.enum_chron(subfield_codes[1].value)
            end
          else
            ec_strings << subfield_codes.map do |sf|
              Normalize.enum_chron(sf.value)
            end
          end
        end
      end
      # a fix for some of George Mason's garbage
      if self.org_code == 'vifgm'
        ec_strings.flatten!
        ec_strings.delete('PP. 1-702')
        ec_strings.delete('1959 DECEMBER')
      end
      # filter out sudocs
      remove_sudocs_from_enumchrons self.sudocs, ec_strings.flatten
    end

    # occassionally SuDocs end up in the enumchron fields.
    # Remove them
    def remove_sudocs_from_enumchrons(sudocs, ecs)
      ecs.each do |e|
        ecs.delete(e) if sudocs.map { |s| s.delete(' ') }.include? e.delete(' ')
      end
      ecs
    end

    #######
    # extract_enum_chrons
    #
    # ecs - {<hashed canonical ec string> : {<parsed features>}, }
    #
    def extract_enum_chrons(m = nil, _o = nil, _e = nil)
      # make sure we've set series
      series
      ecs = {}
      @marc = m unless m.nil?

      ec_strings = extract_enum_chron_strings marc
      ec_strings = [''] if ec_strings == []

      # parse out all of their features
      ec_strings.uniq.each do |ec_string|
        # Series specific parsing
        parsed_ec = parse_ec ec_string

        parsed_ec = {} if parsed_ec.nil?

        parsed_ec['string'] = ec_string
        exploded = explode(parsed_ec, self)

        # anything we can do with it?
        # .explode might be able to use ec_string == '' if there is a relevant
        # pub_date/sudoc in the MARC
        if exploded.keys.count.positive?
          exploded.each do |canonical, features|
            # series may return exploded items all referencing the
            # same feature set.
            # since we are changing it we need multiple copies
            features = features.clone
            features['string'] = ec_string
            features['canonical'] = canonical
            # possible to have multiple ec_strings be reduced
            # to a single ec_string
            if canonical.nil?
              puts "canonical:#{canonical}, ec_string: #{ec_string}"
            end
            ecs[Digest::SHA256.hexdigest(canonical)] ||= features
            ecs[Digest::SHA256.hexdigest(canonical)].merge(features)
          end
        elsif (parsed_ec.keys.count == 1) && (parsed_ec['string'] == '')
          # our enumchron was '' and explode couldn't find anything
          # elsewhere in the MARC, so don't bother with it.
          next
        else # we couldn't explode it.
          ecs[Digest::SHA256.hexdigest(ec_string)] ||= parsed_ec
          ecs[Digest::SHA256.hexdigest(ec_string)].merge(parsed_ec)
        end
      end
      ecs
    end

    # extract_holdings
    #
    # Currently designed for HT records that have individual holding
    # info in 974. Transform those into a coherent holdings field grouped by
    # normalized/parsed enum_chrons.
    # holdings = {<ec_string> :[<each holding>]
    # ht_item_ids = [<holding id>]
    # todo: refactor with extract_enum_chrons. A lot of duplicate code/work
    def extract_holdings(m = nil)
      self.holdings = {}
      self.ht_item_ids = []
      @marc = m unless m.nil?
      marc.each_by_tag('974') do |field|
        ht_item_ids << field['u']
        z = field['z']
        z ||= ''
        ec_string = Normalize.enum_chron(z)

        # possible to parse/explode one enumchron into many for select series
        ecs = []
        if series.nil? || (series == [])
          ecs << ec_string
        else
          parsed_ec = parse_ec ec_string
          if !parsed_ec.nil?
            exploded = explode(parsed_ec, self)
            if exploded.keys.count.positive?
              exploded.each_key do |canonical|
                ecs << canonical
              end
            else # parseable not explodeable
              ecs << ec_string
            end
          else # not parseable
            ecs << ec_string
          end
        end

        ecs.each do |ec|
          # add to holdings field
          # we can't use a raw string because Mongo doesn't like '.' in fields
          ec_digest = Digest::SHA256.hexdigest(ec)
          holdings[ec_digest] ||= [] # array of holdings for this enumchron
          holdings[ec_digest] << { ec: ec,
                                   c: field['c'],
                                   z: field['z'],
                                   y: field['y'],
                                   r: field['r'],
                                   s: field['s'],
                                   u: field['u'] }
        end
      end
      ht_item_ids.uniq!
    end

    # monograph?
    # Occasionally useful wrapper over checking the leader in the source.
    # Note: Just because it is a monograph, does NOT mean it is missing
    # enumchrons.
    def monograph?
      source['leader'] =~ /^.{7}m/
    end

    # Remove from registry.
    # For whatever reason this is a bad record. Remove any reference to it
    # in the Registry. For solo clusters that means deprecating. For clusters
    # in which there are other sources, deprecate and replace with the new
    # smaller cluster. All handled with delete_enumchron
    def remove_from_registry(reason_str = '')
      self.in_registry = false
      num_removed = enum_chrons.count # in theory
      enum_chrons.each do |ec|
        delete_enumchron ec, reason_str
      end
      num_removed
    end

    # Add or update a record's holdings/enumchrons in the registry.
    #
    # Checks for existing enumchrons in registry. Compares to current list
    # for this source record. Handles removal from registry of missing ECs,
    # and creation of new ECs.
    def add_to_registry(reason_str = '')
      ecs_in_reg = RegistryRecord.where(source_record_ids: self.source_id,
                                        deprecated_timestamp: { "$exists": 0 })
                                 .no_timeout.pluck(:enumchron_display)
      new_ecs = enum_chrons - ecs_in_reg
      new_ecs.each { |ec| add_enumchron(ec, reason_str) }
      # make sure it's "in_registry"
      self.in_registry = true
      save # ehhhhhh, maybe not here

      deleted_ecs = ecs_in_reg - enum_chrons
      deleted_ecs.each { |ec| delete_enumchron(ec, reason_str) }

      { num_new: new_ecs.count, num_deleted: deleted_ecs.count }
    end
    alias update_in_registry add_to_registry

    # For whatever reason an enumchron has disappeared from Source Record.
    # Remove from RegistryRecord's associated with this Source Record.
    def delete_enumchron(ec, reason_str = '')
      # in theory should only be one
      RegistryRecord.where(source_record_ids: self.source_id,
                           enumchron_display: ec,
                           deprecated_timestamp: { "$exists": 0 })
                    .no_timeout
                    .each do |reg|
        # just trash it if this is the only source
        if reg.source_record_ids.uniq.count == 1
          reg.deprecate(reason_str)
        # replace old cluster with new
        else
          reason = "#{reason_str} Replaces #{reg.registry_id}."
          cluster = reg.source_record_ids - [self.source_id]
          repl_regrec = RegistryRecord.new(cluster,
                                           ec,
                                           reason)
          repl_regrec.save
          reg.deprecate(reason_str, [repl_regrec.registry_id])
        end
      end
    end

    # This record has an enumchron that needs to be added to the registry.
    # Mostly reliant upon RR::cluster
    #
    def add_enumchron(ec, reason_str = '')
      if (regrec = RegistryRecord.cluster(self, ec))
        # this is expensive if the src is already in the record
        regrec.add_source(self)
      else
        regrec = RegistryRecord.new([self.source_id], ec, reason_str)
      end
      if regrec.source_record_ids.count.zero?
        raise "No source record ids! source_id: #{self.source_id}"
      end
      regrec.save
    end

    # Uses oclc_resolved to identify a series title (and appropriate module)
    def series
      @series ||= []
      # try to set it
      if (self.oclc_resolved.map(&:to_i) &
          Series::FederalRegister.oclcs).count.positive?
        @series << 'FederalRegister'
      end
      if (self.oclc_resolved.map(&:to_i) &
          Series::StatutesAtLarge.oclcs).count.positive?
        @series << 'StatutesAtLarge'
      end
      if (self.oclc_resolved.map(&:to_i) &
          Series::AgriculturalStatistics.oclcs).count.positive?
        @series << 'AgriculturalStatistics'
      end
      if (self.oclc_resolved.map(&:to_i) &
          Series::MonthlyLaborReview.oclcs).count.positive?
        @series << 'MonthlyLaborReview'
      end
      if (self.oclc_resolved.map(&:to_i) &
          Series::MineralsYearbook.oclcs).count.positive?
        @series << 'MineralsYearbook'
      end
      if (self.oclc_resolved.map(&:to_i) &
          Series::StatisticalAbstract.oclcs).count.positive?
        @series << 'StatisticalAbstract'
      end
      if (self.oclc_resolved.map(&:to_i) &
         Series::UnitedStatesReports.oclcs).count.positive? ||
         self.sudocs
             .grep(%r{^#{::Regexp
                        .escape(Series::UnitedStatesReports.sudoc_stem)}})
             .count.positive?
        @series << 'UnitedStatesReports'
      end
      if self.sudocs
             .grep(%r{^#{::Regexp
                        .escape(Series::CivilRightsCommission.sudoc_stem)}})
             .count.positive?
        @series << 'CivilRightsCommission'
      end
      if (self.oclc_resolved.map(&:to_i) &
          Series::CongressionalRecord.oclcs).count.positive?
        @series << 'CongressionalRecord'
      end
      if self.sudocs
             .grep(/^#{::Regexp.escape(Series::ForeignRelations.sudoc_stem)}/)
             .count.positive?
        @series << 'ForeignRelations'
      end
      if (self.oclc_resolved.map(&:to_i) &
          Series::CongressionalSerialSet.oclcs).count.positive? ||
         self.sudocs
             .grep(%r{^#{::Regexp
                        .escape(Series::CongressionalSerialSet.sudoc_stem)}})
             .count.positive?
        @series << 'CongressionalSerialSet'
      end
      if (self.oclc_resolved.map(&:to_i) &
          Series::EconomicReportOfThePresident.oclcs).count.positive? ||
         self.sudocs
             .grep(%r{^#{::Regexp
                        .escape(Series::EconomicReportOfThePresident
                                .sudoc_stem)}})
             .count.positive?
        @series << 'EconomicReportOfThePresident'
      end
      if (self.oclc_resolved.map(&:to_i) &
          Series::ReportsOfInvestigations.oclcs).count.positive?
        @series << 'ReportsOfInvestigations'
      end
      if (self.oclc_resolved.map(&:to_i) &
          Series::DecisionsOfTheCourtOfVeteransAppeals.oclcs).count.positive?
        @series << 'DecisionsOfTheCourtOfVeteransAppeals'
      end
      if (self.oclc_resolved.map(&:to_i) &
          Series::JournalOfTheNationalCancerInstitute.oclcs).count.positive?
        @series << 'JournalOfTheNationalCancerInstitute'
      end
      if (self.oclc_resolved.map(&:to_i) &
          Series::CancerTreatmentReport.oclcs).count.positive?
        @series << 'CancerTreatmentReport'
      end
      if (self.oclc_resolved.map(&:to_i) &
          Series::VitalStatistics.oclcs).count.positive?
        @series << 'VitalStatistics'
      end
      if (self.oclc_resolved.map(&:to_i) &
          Series::PublicPapersOfThePresidents.oclcs).count.positive?
        @series << 'PublicPapersOfThePresidents'
      end

      if !@series.nil? && @series.count.positive?
        @series.uniq!
        extend(Module.const_get('Registry::Series::' + @series.first))
        load_context
      end
      # get whatever we got
      super
      @series
    end

    def parse_ec(ec_string)
      m = nil

      # fix 3 digit years, this is more restrictive than most series specific
      # work.
      ec_string = '1' + ec_string if ec_string.match?(/^9\d\d$/)

      # tokens
      # divider
      div = '[\s:,;\/-]+\s?'

      # volume
      v = '(V\.\s?)?V(OLUME:)?\.?\s?(0+)?(?<volume>\d+)'

      # number
      n = 'N(O|UMBER:)\.?\s?(0+)?(?<number>\d+)'

      # part
      # have to be careful with this due to frequent use of pages in enumchrons
      pt = '\[?P(AR)?T:?\.?\s?(0+)?(?<part>\d+)\]?'

      # year
      y = '(YEAR:)?\[?(?<year>(1[8-9]|20)\d{2})\.?\]?'

      # book
      b = 'B(OO)?K:?\.?\s?(?<book>\d+)'

      # sheet
      sh = 'SHEET:?\.?\s?(?<sheet>\d+)'

      # match all or nothing
      patterns = [
        /^#{v}$/xi,

        # risky business
        /^(0+)?(?<volume>[1-9])$/xi,

        /^#{n}$/xi,

        /^#{pt}$/xi,

        /^#{y}$/xi,

        /^#{b}$/xi,

        /^#{sh}$/xi,

        # compound patterns
        /^#{v}#{div}#{pt}$/xi,

        /^#{y}#{div}#{pt}$/xi,

        /^#{y}#{div}#{v}$/xi,

        /^#{v}[\(\s]\s?#{y}\)?$/xi,

        /^#{v}#{div}#{n}#/xi

      ] # patterns

      patterns.each do |p|
        break unless m.nil?
        m ||= p.match(ec_string)
      end

      # some cleanup
      unless m.nil?
        ec = Hash[m.names.zip(m.captures)]
        ec.delete_if { |_k, value| value.nil? }

        # year unlikely. Probably don't know what we think we know.
        # From the regex, year can't be < 1800
        ec = nil if ec['year'].to_i > (Time.now.year + 5)
      end
      ec
    end

    def explode(ec, _src = nil)
      # we would need to know something about the title to do this
      # accurately, so we're not really doing anything here
      enum_chrons = {}
      return {} if ec.nil?

      ecs = [ec]
      ecs.each do |enum|
        if (canon = canonicalize(enum))
          enum['canon'] = canon
          enum_chrons[enum['canon']] = enum.clone
        end
      end
      enum_chrons
    end

    def canonicalize(ec)
      # default order is:
      t_order = %w[year volume part number book sheet]
      canon = t_order.reject { |t| ec[t].nil? }
                     .collect { |t| t.to_s.capitalize + ':' + ec[t] }
                     .join(', ')
      canon = nil if canon == ''
      canon
    end

    def load_context; end

    def save
      self.last_modified = Time.now.utc
      super
    end

    # FLASUS has some wonky 955s that mongo chokes on,
    # and messes up our enumchrons
    # org_code = string, hopefully flasus
    # src = parsed json
    def fix_flasus(org_code = nil, src = nil)
      org_code ||= self.org_code
      src ||= source
      if org_code == 'flasus'

        # some 955s end up with keys of 'v.1'
        field = src['fields'].find { |f| f['955'] }['955']['subfields']
        v = field.select { |h| h['v'] }[0]
        junk_sf = field.select { |h| h.keys[0] =~ /\./ }[0]
        unless junk_sf.nil?
          junk = junk_sf.keys[0]
          v['v'] = junk.dup
          field.delete_if { |h| h.keys[0] =~ /\./ }
        end

        # some subfield keys are simply '$' which causes problems.
        # faster to do a conversion to a string than back into source
        src_str = src.to_json.gsub(/\{\s?"\$"\s?:/, '{"dollar":')
        src = JSON.parse(src_str)
      end
      src
    end

    # Default accessor for some but not all attributes
    # Sets to [] if not found in extracted.
    def extracted_field(field = __callee__)
      return self[field.to_sym] unless self[field.to_sym].nil?
      @extracted ||= extracted
      self[field.to_sym] = if @extracted[field.to_s].nil?
                             []
                           else
                             @extracted[field.to_s]
                           end
    end
    alias electronic_versions extracted_field
    alias related_electronic_resources extracted_field
    alias electronic_resources extracted_field

    def author_lccns
      return @author_lccns unless @author_lccns.nil?
      @extracted ||= extracted
      self.author_lccns = get_lccns @extracted['author_lccn_lookup']
    end

    def added_entry_lccns
      return @added_entry_lccns unless @added_entry_lccns.nil?
      @extracted ||= extracted
      self.added_entry_lccns = get_lccns @extracted['added_entry_lccn_lookup']
    end

    def report_numbers
      return @report_numbers unless @report_numbers.nil?
      @extracted ||= extracted
      self.report_numbers = @extracted['report_numbers'] || []
    end

    def extracted(m = nil)
      @marc = m unless m.nil?
      @extracted = @@extractor.map_record(marc)
      @extracted
    end

    def get_lccns(names)
      lccns = []
      names ||= []
      names.each do |n|
        lccns << Authority.with(client: 'nauth') do |klass|
          auth = klass.search(n)
          auth&.sameAs
        end
      end
      lccns.delete(nil)
      lccns.uniq
    end

    def self.marc_profiles
      @@marc_profiles unless @@marc_profiles.empty?
      Dir.glob(__dir__ + '/../../config/marc_profiles/*.yml').each do |profile|
        p = YAML.load_file(profile)
        @@marc_profiles[p['org_code']] = p
      end
      @@marc_profiles
    end
    marc_profiles
  end
end
