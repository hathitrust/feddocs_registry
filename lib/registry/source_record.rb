require 'mongoid'
require 'securerandom'
require 'marc'
require 'pp'
require 'dotenv'
require 'registry/collator'
require 'registry/series'
require 'yaml'
require 'digest'
require 'oclc_filter/blacklist'
require 'oclc_filter/whitelist'
require 'nauth/authority'
Authority = Nauth::Authority

Dir[File.dirname(__FILE__) + "/series/*.rb"].each {|file| require file}

module Registry
  class SourceRecord
    include Mongoid::Document
    include Mongoid::Attributes::Dynamic
    include Registry::Series
    store_in collection: "source_records"

    field :author_parts
    field :author_headings
    field :author_normalized
    field :author_viaf_ids
    field :author_lccn, type:String, default:''
    field :author_addl_viaf_ids
    field :author_addl_headings
    field :author_addl_normalized
    field :cataloging_agency
    field :deprecated_reason, type: String
    field :deprecated_timestamp, type: DateTime
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
    field :org_code, type: String, default: "miaahdl"
    field :pub_date
    field :publisher_headings
    field :publisher_normalized
    field :publisher_viaf_ids
    field :series, type: String
    field :source
    field :source_blob, type: String
    field :source_id, type: String
    field :sudocs
    field :invalid_sudocs # bad MARC, not necessarily bad SuDoc
    field :non_sudocs

    #this stuff is extra ugly
    Dotenv.load
    @@collator = Collator.new(__dir__+'/../../config/traject_config.rb')
    @@extractor = Traject::Indexer.new
    @@extractor.load_config_file(__dir__+'/../../config/traject_config.rb')

    @@contrib_001 = {}
    open(__dir__+'/../../config/contributors_w_001_oclcs.txt').each{ |l| @@contrib_001[l.chomp] = 1 }

    @@marc_profiles = {}

    @@mc = Mongo::Client.new([ENV['mongo_host']+':'+ENV['mongo_port']], :database => 'htgd' )

    #OCLCPAT taken from traject, except middle o made optional
    OCLCPAT = 
      /
          \A\s*
          (?:(?:\(OCo?LC\)) |
      (?:\(OCo?LC\))?(?:(?:ocm)|(?:ocn)|(?:on))
      )(\d+)
      /x
     
    def initialize *args
      super
      self.source_id ||= SecureRandom.uuid()
    end

    # On assignment of source json string, record is parsed, author/publisher 
    # fields are normalized/VIAFed, and identifiers extracted. 
    def source=(value)
      s = JSON.parse(value)
      super(fix_flasus(org_code, s))
      self.local_id = self.extract_local_id
      self.source_blob = value
      @@collator.normalize_viaf(s).each {|k, v| self.send("#{k}=",v) }
      marc = MARC::Record.new_from_hash(self.source)
      extracted = @@extractor.map_record(marc)
      self.pub_date = extracted['pub_date']
      self.gpo_item_numbers = extracted['gpo_item_number'] || []
      self.publisher_headings = extracted['publisher_heading'] || []
      self.author_headings = extracted['author_t'] || []
      self.author_parts = extracted['author_parts'] || []
      self.extract_identifiers marc
      if extracted['author_lccn_lookup'].nil?
        self.author_lccn = ''
      else
        auth = self.get_author_lccn extracted['author_lccn_lookup'][0].chomp('.')
        self.author_lccn = auth
      end
      self.series = self.series #important to do this before extracting enumchrons
      self.ec = self.extract_enum_chrons marc
      self.enum_chrons = self.ec.collect do | k,fields |
        if !fields['canonical'].nil?
          fields['canonical']
        else
          fields['string']
        end
      end
      if self.enum_chrons.count == 0 
        self.enum_chrons << ""
      end
      if self.org_code == 'miaahdl'
        self.extract_holdings marc
      end
    end

    # A source record may be deprecated if it is out of scope. 
    #
    # Typically a RegistryRecord should be identified as out of scope, then
    # associated SourceRecords are dealt with. 
    def deprecate( reason )
      self.deprecated_reason = reason
      self.deprecated_timestamp = Time.now.utc
      self.save
    end

    # Extracts and normalizes identifiers from self.source
    def extract_identifiers marc=nil
      self.org_code ||= "" #should be set on ingest. 
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
    
      marc ||= MARC::Record.new_from_hash(self.source)
      self.extract_oclcs marc 
      self.extract_sudocs marc
      self.extract_lccns marc
      self.extract_issns marc
      self.extract_isbns marc
      self.formats = Traject::Macros::MarcFormatClassifier.new(marc).formats
    
      self.oclc_resolved = self.resolve_oclc(self.oclc_alleged).uniq
    end #extract_identifiers

    # Hit the oclc_authoritative collection for OCLC resolution. 
    # oclc_authoritative is a copy of /l1/govdocs/data/x2.all
    # Bit of a kludge.
    def resolve_oclc oclcs
      resolved = []
      oclcs.each do | oa |
        @@mc[:oclc_authoritative].find(:duplicates => oa).each do | ores | #1?
          resolved << ores[:oclc].to_i
        end
      end

      if resolved.count == 0
        resolved = oclcs
      end
      return resolved 
    end

    # Extract the contributing institutions id for this record. 
    # Enables update/replacement of source records. 
    #
    # Assumes "001" if no field is provided. 
    def extract_local_id field = nil
      field ||= '001'
      begin
        id = self.source["fields"].find{|f| f[field]}[field].gsub(/ /, '')
        # this will eliminate leading zeros but only for actual integer ids 
        if id =~ /^[0-9]+$/
          id.gsub!(/^0+/, '')
        end
      rescue
        #the field doesn't exist
        id = ''
      end
      return id
    end

    # Determine HT availability. 'Full View', 'Limited View', 'not available'
    #
    def ht_availability
      if self.org_code == 'miaahdl'
        if self.source_blob =~ /"r" ?: ?"pd"/
          return 'Full View'
        else
          return 'Limited View'
        end
      else
        return nil
      end
    end

    # Determine if this is a govdoc based on 008 and 086 and 074
    # and OCLC blacklist
    # marc - ruby-marc repesentation of source
    def is_govdoc marc=nil
      marc ||= MARC::Record.new_from_hash(self.source)
     
      #if fields.nil? #rare but happens let rescue handle it
      field_008 = marc['008'] 
      if field_008.nil?
        f008 = ''
      else
        f008 = field_008.value
      end
      self.extract_identifiers( marc )
      #check the blacklist
      self.oclc_resolved.each do |o|
        if Whitelist.oclcs.include? o
          return true
        elsif Blacklist.oclcs.include? o
          return false
        end
      end
      f008 =~ /^.{17}u.{10}f/ or self.sudocs.count > 0 or self.extract_sudocs(marc).count > 0 or self.gpo_item_numbers.count > 0
    end

    # Extracts SuDocs
    #
    # marc - ruby-marc representation of source
    def extract_sudocs marc=nil
      marc ||= MARC::Record.new_from_hash(self.source)
      self.sudocs = []
      self.invalid_sudocs = [] #curiosity
      self.non_sudocs = [] 

      marc.each_by_tag('086') do | field |
        # Supposed to be in 086/ind1=0, but some records are dumb. 
        if field['a'] 
          # $2 says its not a sudoc
          # except sometimes $2 is describing subfield z and 
          # subfield a is in fact a SuDoc... seriously
          if !field['2'].nil? and field['2'] !~ /^sudoc/i and field['z'].nil?
            self.non_sudocs << field['a'].chomp
            # if ind1 == 0 then it is also bad MARC
            if field.indicator1 == '0' 
              self.invalid_sudocs << field['a'].chomp
            end

          # ind1 says it is
          elsif field.indicator1 == '0' #and no subfield $2 or $2 is sudoc
            self.sudocs << field['a'].chomp

          #sudoc in $2 and it looks like one
          elsif field['a'] =~ /:/ and field['2'] =~ /^sudoc/i
            self.sudocs << field['a'].chomp
            
          #it looks like one and it isn't telling us it isn't
          #bad MARC but too many to ignore
          elsif field.indicator1.strip == '' and field['a'] =~ /:/ and field['a'] !~ /^IL/ and field['2'].nil? 
            self.sudocs << field['a'].chomp
            self.invalid_sudocs << field['a'].chomp

          #bad MARC and probably not a sudoc
          elsif field.indicator1.strip == '' and field['2'].nil?
            self.invalid_sudocs << field['a'].chomp
          end
        end
      end
      self.non_sudocs.uniq!
      self.invalid_sudocs.uniq!
      self.sudocs.uniq!
      self.sudocs = (self.sudocs - self.non_sudocs).map {|s| fix_sudoc s }
      self.sudocs
    end

    # takes a SuDoc string and tries to repair it if mangled
    def fix_sudoc sstring
      sstring.sub(/^II0 +a/, '')
    end

    def extract_oclcs marc=nil
      marc ||= MARC::Record.new_from_hash(self.source)
      self.oclc_alleged = []
      #035a and 035z
      marc.each_by_tag('035') do | field |
        if field['a'] and OCLCPAT.match(field['a'])
          oclc = $1.to_i
          if oclc
            self.oclc_alleged << oclc
          end
        end
      end

      #OCLC prefix in 001
      #or contributor told us to look there
      marc.each_by_tag('001') do | field |
        if OCLCPAT.match(field.value) or
          (@@contrib_001[self.org_code] and field.value =~ /^(\d+)$/x)
          self.oclc_alleged << $1.to_i
        end
      end
      
      #Indiana told us 955$o. Not likely, but...
      if self.org_code == "inu"
        marc.each_by_tag('955') do | field |
          field.subfields.each do | sf | 
            if sf.code == 'o' and sf.value =~ /(\d+)/
              self.oclc_alleged << $1.to_i
            end
          end
        end
      end

      #We don't care about different physical forms so
      #776s are valid too.
      marc.each_by_tag('776') do | field |
        subfield_ws = field.find_all {|subfield| subfield.code == 'w'}
        subfield_ws.each do | sub | 
          if OCLCPAT.match(sub.value)
            self.oclc_alleged << $1.to_i
          end
        end
      end

      self.oclc_alleged = self.oclc_alleged.flatten.uniq
      #if it's bigger than 8 bytes, definitely not valid. 
      # (and can't be saved to Mongo anyway)
      self.oclc_alleged.delete_if {|x| x.size > 8 }
    end

    #######
    # LCCN
    def extract_lccns marc=nil
      marc ||= MARC::Record.new_from_hash(self.source)
      self.lccn_normalized = []

      marc.each_by_tag('010') do | field |
        if field['a'] and field['a'] != ''
          self.lccn_normalized << StdNum::LCCN.normalize(field['a'].downcase) 
        end
      end
      self.lccn_normalized.uniq!
      return self.lccn_normalized
    end

    ########
    # ISSN
    def extract_issns marc=nil
      marc ||= MARC::Record.new_from_hash(self.source)
      self.issn_normalized = []
      
      marc.each_by_tag('022') do | field |
        if field['a'] and field['a'] != ''
          self.issn_normalized << StdNum::ISSN.normalize(field['a'])
        end
      end

      #We don't care about different physical forms so
      #776s are valid too.
      marc.each_by_tag('776') do | field |
        subfield_xs = field.find_all {|subfield| subfield.code == 'x'}
        subfield_xs.each do | sub | 
          self.issn_normalized << StdNum::ISSN.normalize(sub.value)
        end
      end

      self.issn_normalized.uniq!
      return self.issn_normalized
    end 

    #######
    # ISBN
    def extract_isbns marc=nil
      marc ||= MARC::Record.new_from_hash(self.source)
      self.isbns_normalized = []

      marc.each_by_tag('020') do | field |
        if field['a'] and field['a'] != ''
          self.isbns << field['a']
          isbn = StdNum::ISBN.normalize(field['a'])
          if isbn and isbn != ''
            self.isbns_normalized << isbn
          end
        end
      end
      
      #We don't care about different physical forms so
      #776s are valid too.
      marc.each_by_tag('776') do | field |
        subfield_zs = field.find_all {|subfield| subfield.code == 'z'}
        subfield_zs.each do | sub | 
          self.isbns_normalized << StdNum::ISBN.normalize(sub.value)
        end
      end

      self.isbns_normalized.uniq!
      return self.isbns_normalized
    end

    #extract_enum_chron_strings
    #Finds the correct marc field and returns and array of enumchrons
    def extract_enum_chron_strings marc=nil
      ec_strings = []
      marc ||= MARC::Record.new_from_hash(self.source)
      tag, subcode = @@marc_profiles[self.org_code]['enum_chrons'].split(/ /)
      marc.each_by_tag(tag) do | field | 
        subfield_codes = field.find_all { |subfield| subfield.code == subcode }
        if subfield_codes.count > 0
          if self.org_code == "dgpo"
            #take the second one if it's from gpo?
            if subfield_codes.count > 1
              ec_strings << Normalize.enum_chron(subfield_codes[1].value)
            end
          else
            ec_strings << subfield_codes.map {|sf| Normalize.enum_chron(sf.value) }
          end
        end
      end
      # a fix for some of George Mason's garbage
      if self.org_code == "vifgm"
        ec_strings.flatten!
        ec_strings.delete('PP. 1-702')
        ec_strings.delete('1959 DECEMBER')
      end
      ec_strings.flatten
    end

    #######
    # extract_enum_chrons
    #
    # ecs - {<hashed canonical ec string> : {<parsed features>}, }
    #
    def extract_enum_chrons(marc=nil, org_code=nil, ec_strings=nil)
      #make sure we've set series
      self.series
      ecs = {}
      org_code ||= self.org_code
      
      if ec_strings.nil?
        ec_strings = self.extract_enum_chron_strings marc
      end
      if ec_strings == []
        ec_strings = ['']
      end

      #parse out all of their features
      ec_strings.uniq.each do | ec_string | 
          
        # Series specific parsing 
        parsed_ec = self.parse_ec ec_string

        if parsed_ec.nil?
          parsed_ec = {}
        end

        parsed_ec['string'] = ec_string
        exploded = self.explode(parsed_ec, self)

        # anything we can do with it? 
        # .explode might be able to use ec_string == '' if there is a relevant
        # pub_date/sudoc in the MARC
        if exploded.keys.count() > 0
          exploded.each do | canonical, features | 
            #series may return exploded items all referencing the same feature set.
            #since we are changing it we need multiple copies
            features = features.clone
            features['string'] = ec_string
            features['canonical'] = canonical
            #possible to have multiple ec_strings be reduced to a single ec_string
            if canonical.nil?
              PP.pp exploded
              puts "canonical:#{canonical}, ec_string: #{ec_string}"
            end
            ecs[Digest::SHA256.hexdigest(canonical)] ||= features 
            ecs[Digest::SHA256.hexdigest(canonical)].merge( features )
          end
        elsif parsed_ec.keys.count == 1 and parsed_ec['string'] == ''
          #our enumchron was '' and explode couldn't find anything elsewhere in the 
          #MARC, so don't bother with it.
          next
        else #we couldn't explode it. 
          ecs[Digest::SHA256.hexdigest(ec_string)] ||= parsed_ec
          ecs[Digest::SHA256.hexdigest(ec_string)].merge( parsed_ec )
        end
      end
      ecs 
    end

    # extract_holdings 
    #
    # Currently designed for HT records that have individual holding info in 974.
    # Transform those into a coherent holdings field grouped by normalized/parsed
    # enum_chrons.
    # holdings = {<ec_string> :[<each holding>]
    # ht_item_ids = [<holding id>]
    # todo: refactor with extract_enum_chrons. A lot of duplicate code/work being done
    def extract_holdings marc=nil
      self.holdings = {}
      self.ht_item_ids = [] 
      marc ||= MARC::Record.new_from_hash(self.source)
      marc.each_by_tag('974') do |field|
        self.ht_item_ids << field['u']
        z = field['z']
        z ||= ''
        ec_string = Normalize.enum_chron(z)

        #possible to parse/explode one enumchron into many for select series
        ecs = []
        if self.series.nil? or self.series == ''
          ecs << ec_string
        else
          parsed_ec = self.parse_ec ec_string
          if !parsed_ec.nil?
            exploded = self.explode(parsed_ec, self)
            if exploded.keys.count() > 0
              exploded.each do | canonical, features |
                ecs << canonical
              end
            else #parseable not explodeable
              ecs << ec_string
            end
          else #not parseable
            ecs << ec_string
          end
        end

        ecs.each do |ec|
          # add to holdings field
          # we can't use a raw string because Mongo doesn't like '.' in fields
          ec_digest = Digest::SHA256.hexdigest(ec)
          self.holdings[ec_digest] ||= [] #array of holdings for this enumchron
          self.holdings[ec_digest] << { ec:ec,
                                        c:field['c'], 
                                        z:field['z'],
                                        y:field['y'],
                                        r:field['r'],
                                        s:field['s'],
                                        u:field['u']}
        end
      end #each 974
      self.ht_item_ids.uniq!
    end
      

    # is_monograph?
    # Occasionally useful wrapper over checking the leader in the source. 
    # Note: Just because it is a monograph, does NOT mean it is missing
    # enumchrons. 
    def is_monograph?
      self.source['leader'] =~ /^.{7}m/
    end

    # Remove from registry. 
    # For whatever reason this is a bad record. Remove any reference to it
    # in the Registry. For solo clusters that means deprecating. For clusters
    # in which there are other sources, deprecate and replace with the new 
    # smaller cluster. All handled with delete_enumchron
    def remove_from_registry reason_str=""
      self.in_registry = false
      num_removed = self.enum_chrons.count # in theory
      self.enum_chrons.each do | ec |
        self.delete_enumchron ec, reason_str
      end
      num_removed  
    end

    # Add or update a record's holdings/enumchrons in the registry. 
    # 
    # Checks for existing enumchrons in registry. Compares to current list
    # for this source record. Handles removal from registry of missing ECs,
    # and creation of new ECs.
    def add_to_registry reason_str=""
      ecs_in_reg = RegistryRecord.where(source_record_ids:self.source_id,
                                    deprecated_timestamp:{"$exists":0}).no_timeout.pluck(:enumchron_display)
      new_ecs = self.enum_chrons - ecs_in_reg
      new_ecs.each {|ec| self.add_enumchron(ec, reason_str) }
      #make sure it's "in_registry"
      self.in_registry = true
      self.save # ehhhhhh, maybe not here

      deleted_ecs = ecs_in_reg - self.enum_chrons
      deleted_ecs.each {|ec| self.delete_enumchron(ec, reason_str) }

      return {num_new:new_ecs.count, num_deleted:deleted_ecs.count}
    end
    alias_method :update_in_registry, :add_to_registry

    # For whatever reason an enumchron has disappeared from Source Record.
    # Remove from RegistryRecord's associated with this Source Record.
    def delete_enumchron ec, reason_str=""
      #in theory should only be one
      RegistryRecord.where(source_record_ids:self.source_id,
                           enumchron_display:ec,
                           deprecated_timestamp:{"$exists":0}).no_timeout.each do |reg|
        # just trash it if this is the only source
        if reg.source_record_ids.uniq.count == 1
         reg.deprecate( reason_str )
        # replace old cluster with new
        else
          cluster = reg.source_record_ids - [self.source_id]
          repl_regrec = RegistryRecord.new(cluster, 
                                           ec, 
                                          "#{reason_str} Replaces #{reg.registry_id}.")
          repl_regrec.save
          reg.deprecate(reason_str, [repl_regrec.registry_id])
        end
      end 
    end

    # This record has an enumchron that needs to be added to the registry.
    # Mostly reliant upon RR::cluster
    #
    def add_enumchron ec, reason_str=""
      if regrec = RegistryRecord::cluster( self, ec )
        regrec.add_source(self) # this is expensive if the src is already in the record
      else
        regrec = RegistryRecord.new([self.source_id], ec, reason_str)
      end
      if regrec.source_record_ids.count == 0
        raise "No source record ids! source_id: #{self.source_id}"
      end
      regrec.save
    end
     
    # Uses oclc_resolved to identify a series title (and appropriate module)
    def series
      #try to set it 
      case
      when (self.oclc_resolved.map{|o|o.to_i} & Series::FederalRegister.oclcs).count > 0
        @series = 'FederalRegister'
      when (self.oclc_resolved.map{|o|o.to_i} & Series::StatutesAtLarge.oclcs).count > 0
        @series = 'StatutesAtLarge'
      when (self.oclc_resolved.map{|o|o.to_i} & Series::AgriculturalStatistics.oclcs).count > 0
        @series = 'AgriculturalStatistics'
      when (self.oclc_resolved.map{|o|o.to_i} & Series::MonthlyLaborReview.oclcs).count > 0
        @series = 'MonthlyLaborReview'
      when (self.oclc_resolved.map{|o|o.to_i} & Series::MineralsYearbook.oclcs).count > 0
        @series = 'MineralsYearbook'
      when (self.oclc_resolved.map{|o|o.to_i} & Series::StatisticalAbstract.oclcs).count > 0
        @series = 'StatisticalAbstract'
      when ((self.oclc_resolved.map{|o|o.to_i} & Series::UnitedStatesReports.oclcs).count > 0 or
        self.sudocs.grep(/^#{Regexp.escape(Series::UnitedStatesReports.sudoc_stem)}/).count > 0)
        @series = 'UnitedStatesReports'
      when self.sudocs.grep(/^#{Regexp.escape(Series::CivilRightsCommission.sudoc_stem)}/).count > 0
        @series = 'CivilRightsCommission'
      when (self.oclc_resolved.map{|o|o.to_i} & Series::CongressionalRecord.oclcs).count > 0
        @series = 'CongressionalRecord'
      when self.sudocs.grep(/^#{Regexp.escape(Series::ForeignRelations.sudoc_stem)}/).count > 0
        @series = 'ForeignRelations'
      when ((self.oclc_resolved.map{|o|o.to_i} & Series::CongressionalSerialSet.oclcs).count > 0 or 
        self.sudocs.grep(/^#{Regexp.escape(Series::CongressionalSerialSet.sudoc_stem)}/).count > 0)
        @series = 'CongressionalSerialSet'
      when (self.sudocs.grep(/^#{Regexp.escape(Series::EconomicReportOfThePresident.sudoc_stem)}/).count > 0 or
        (self.oclc_resolved.map{|o|o.to_i} & Series::EconomicReportOfThePresident.oclcs).count > 0)
        @series = 'EconomicReportOfThePresident'
      when (self.oclc_resolved.map{|o|o.to_i} & Series::ReportsOfInvestigations.oclcs).count > 0
        @series = 'ReportsOfInvestigations'
      when (self.oclc_resolved.map{|o|o.to_i} & Series::DecisionsOfTheCourtOfVeteransAppeals.oclcs).count > 0
        @series = 'DecisionsOfTheCourtOfVeteransAppeals'
      end
      if @series 
        self.extend(Module.const_get("Registry::Series::"+@series))
        load_context
      end
      #get whatever we got
      super 
      @series
    end

    def parse_ec ec_string
      m = nil 

      # fix 3 digit years, this is more restrictive than most series specific 
      # work. 
      if ec_string =~ /^9\d\d$/
        ec_string = '1'+ec_string
      end

      #tokens
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
        %r{^#{v}$}xi,

        #risky business
        %r{^(0+)?(?<volume>[1-9])$}xi, 

        %r{^#{n}$}xi,

        %r{^#{pt}$}xi,

        %r{^#{y}$}xi,

        %r{^#{b}$}xi,

        %r{^#{sh}$}xi,

        #compound patterns
        %r{^#{v}#{div}#{pt}$}xi,

        %r{^#{y}#{div}#{pt}$}xi,

        %r{^#{y}#{div}#{v}$}xi,

        %r{^#{v}[\(\s]\s?#{y}\)?$}xi,

        %r{^#{v}#{div}#{n}#}xi

      ] # patterns

      patterns.each do |p|
        if !m.nil?
          break
        end
        m ||= p.match(ec_string)
      end

          
      # some cleanup
      if !m.nil?
        ec = Hash[ m.names.zip( m.captures ) ]
        ec.delete_if {|k, v| v.nil? }
        
        # year unlikely. Probably don't know what we think we know.
        # From the regex, year can't be < 1800
        if ec['year'].to_i > (Time.now.year + 5)
          ec = nil
        end
      end
      ec
    end

    def explode ec, src=nil
      # we would need to know something about the title to do this 
      # accurately, so we're not really doing anything here
      enum_chrons = {} 
      if ec.nil? 
        return {}
      end

      ecs = [ec]
      ecs.each do | ec |
        if canon = self.canonicalize(ec)
          ec['canon'] = canon
          enum_chrons[ec['canon']] = ec.clone
        end
      end
      enum_chrons
    end

    def canonicalize ec
      # default order is:
      t_order = ['year', 'volume', 'part', 'number', 'book', 'sheet']
      canon = t_order.reject {|t| ec[t].nil?}.collect {|t| t.to_s.capitalize+":"+ec[t]}.join(", ") 
      if canon == ''
        canon = nil
      end
      canon
    end

    def load_context 
    end

    def save
      self.last_modified = Time.now.utc
      super
    end

    # FLASUS has some wonky 955s that mongo chokes on, and messes up our enumchrons
    # org_code = string, hopefully flasus
    # src = parsed json 
    def fix_flasus org_code=nil, src=nil
      org_code ||= self.org_code
      src ||= self.source
      if org_code == 'flasus'

        # some 955s end up with keys of 'v.1'
        f = src['fields'].find {|f| f['955'] }['955']['subfields']
        v = f.select { |h| h['v'] }[0]
        junk_sf = f.select { |h| h.keys[0] =~ /\./ }[0]
        if !junk_sf.nil?
          junk = junk_sf.keys[0]
          v['v'] = junk.dup
          f.delete_if { |h| h.keys[0] =~ /\./ }
        end

        # some subfield keys are simply '$' which causes problems.
        # faster to do a conversion to a string than back into source
        src_str = src.to_json.gsub(/\{\s?"\$"\s?:/, '{"dollar":')
        src = JSON.parse(src_str)
      end
      src
    end

    def get_author_lccn name
      if name.nil? or name == ""
        return ""
      end
      Mongoid.override_database("nauth")
      auth = Authority.find_by(name:name)
      if !auth.nil?
        return auth.sameAs
      else
        return ''
      end
      Mongoid.override_database(nil)
    end

    def self.marc_profiles
      @@marc_profiles
    end

    def self.get_marc_profiles
      Dir.glob(__dir__+'/../../config/marc_profiles/*.yml').each do |profile|
        p = YAML.load_file(profile)
        @@marc_profiles[p["org_code"]] = p 
      end
    end
    self.get_marc_profiles

  end
end

