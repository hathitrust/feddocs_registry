require 'mongoid'
require 'securerandom'
require 'marc'
require 'pp'
require 'dotenv'
require 'registry/collator'
require 'registry/series'
require 'yaml'
require 'digest'
require 'filter'
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
    include Filter
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
    field :isbns_normalized
    field :issn_normalized
    field :lccn_normalized
    field :last_modified, type: DateTime
    field :lc_call_numbers, type: Array
    field :lc_classifications, type: Array
    field :lc_item_numbers, type: Array
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
    @extractions = {}

    # this stuff is extra ugly
    Dotenv.load
    @@extractor = Traject::Indexer::MarcIndexer.new
    source_traject = __dir__ + '/../../config/traject_source_record_config.rb'
    @@extractor.load_config_file(source_traject)

    @@contrib001 = {}
    File.open(__dir__ + \
              '/../../config/contributors_w_001_oclcs.txt').each do |l|
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

    def extractions
      if source
        @extractions ||= @@extractor.map_record marc
      else
        @extractions || {}
      end
    end

    # On assignment of source json string, record is parsed,
    # and identifiers extracted.
    def source=(value)
      @source = JSON.parse(value)
      super(fix_flasus(org_code, @source))
      @marc = MARC::Record.new_from_hash(source)
      self.local_id = extract_local_id
      extractions.keys.map { |field| extracted_field(field) }
      extract_identifiers
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
      self.sudocs ||= []
      self.invalid_sudocs ||= []
      self.non_sudocs ||= []

      extract_oclcs
      extract_sudocs

      self.oclc_resolved = oclc_alleged.map { |o| resolve_oclc(o) }.flatten.uniq
    end

    def ocns
      self.oclc_resolved || []
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

    # Extract marcive_ids from the 035
    def marcive_ids(marc_record = nil)
      @marc = marc_record unless marc_record.nil?
      ids = Traject::MarcExtractor.cached('035a').extract(marc)
      ids.select { |i| /MvI/.match? i }.map { |i| i.gsub(/[^0-9]/, '').to_i }
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

    # The 008 field contains a place of publication code at the 17th position,
    # and a governemnt publication code at the 28th.
    # https://www.loc.gov/marc/bibliographic/bd008.html
    def u_and_f?(m = nil)
      @marc = m unless m.nil?
      /^.{17}u.{10}f/.match? marc['008']&.value
    end

    # Check author_lccns against the list of approved authors
    def approved_author?
      author_lccns.any? { |a| AuthorityList.lccns.include? a }
    end

    # Check added_entry_lccns against the list of approved authors
    def approved_added_entry?
      added_entry_lccns.any? { |a| AuthorityList.lccns.include? a }
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
      self.oclc_alleged << oclcs_from_955o_fields

      # We don't care about different physical forms so
      # 776s are valid too.
      self.oclc_alleged << oclcs_from_776_fields

      self.oclc_alleged = self.oclc_alleged.flatten.uniq
      # if it's bigger than 8 bytes, definitely not valid.
      # (and can't be saved to Mongo anyway)
      self.oclc_alleged.delete_if { |x| x.size > 8 }
      self.oclc_alleged = remove_incorrect_substring_oclcs
    end

    # Get OCLCs from 776 field
    def oclcs_from_776_fields(m = nil)
      @marc = m unless m.nil?
      oclcs = []
      marc.each_by_tag('776') do |f|
        f.find_all { |subfield| subfield.code == 'w' }.each do |sub|
          oclcs << ::Regexp.last_match(1).to_i if OCLCPAT.match(sub.value)
        end
      end
      oclcs
    end

    # Get OCLCs from 955$o
    def oclcs_from_955o_fields(m = nil, oc = nil)
      @org_code = oc unless oc.nil?
      return [] unless org_code == 'inu'

      @marc = m unless m.nil?
      oclcs = []
      marc.each_by_tag('955') do |field|
        field.subfields.each do |sf|
          if (sf.code == 'o') && sf.value =~ /(\d+)/
            oclcs << ::Regexp.last_match(1).to_i
          end
        end
      end
      oclcs
    end

    # Remove errant oclcs
    # Some records have OCLCs that have dropped leading significant digits.
    # They have multiple OCLCs where one is affectively a substring of the
    # correct OCLC.
    def remove_incorrect_substring_oclcs(oclcs = nil)
      oclcs ||= oclc_alleged

      bad_oclcs = []
      oclcs.each do |o1|
        oclcs.each do |o2|
          # substring must be greater than 9999 as smaller OCLCs may match by
          # coincidence
          next if o2 < 10_000

          bad_oclcs << o2 if o1.to_s.match?(/.+#{o2.to_s}$/)
        end
      end
      oclcs - bad_oclcs
    end

    # extract_enum_chron_strings
    # Finds the correct marc field and returns and array of enumchrons
    def extract_enum_chron_strings(m = nil)
      ec_strings = []
      @marc = m unless m.nil?
      tag, subcode = @@marc_profiles[self.org_code]['enum_chrons'].split(/ /)
      marc.each_by_tag(tag) do |field|
        subfield_codes = field.find_all { |subfield| subfield.code == subcode }
        if subfield_codes.any?
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
        if exploded.keys.any?
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
              # puts "canonical:#{canonical}, ec_string: #{ec_string}"
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
            if exploded.keys.any?
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
      self[field.to_sym] = if extractions[field.to_s].nil?
                             []
                           else
                             extractions[field.to_s]
                           end
    end
    alias author_headings extracted_field
    alias author_parts extracted_field
    alias author_lccns extracted_field
    alias added_entry_lccns extracted_field
    alias gpo_item_numbers extracted_field
    alias formats extracted_field
    alias publisher_headings extracted_field
    alias pub_date extracted_field
    alias electronic_resources extracted_field
    alias electronic_versions extracted_field
    alias related_electronic_resources extracted_field
    alias report_numbers extracted_field
    alias lccn_normalized extracted_field
    alias lc_call_numbers extracted_field
    alias lc_classifications extracted_field
    alias lc_item_numbers extracted_field
    alias issn_normalized extracted_field
    alias isbns_normalized extracted_field

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
