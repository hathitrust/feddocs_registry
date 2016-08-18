require 'mongoid'
require 'securerandom'
require 'marc'
require 'pp'
require 'dotenv'
require 'collator'
require 'yaml'
require 'digest'
require 'federal_register'
require 'statutes_at_large'
require 'agricultural_statistics'

class SourceRecord
  include Mongoid::Document
  include Mongoid::Attributes::Dynamic
  store_in collection: "source_records"

  field :author_headings
  field :author_normalized
  field :author_viaf_ids
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
  field :holdings
  field :in_registry, type: Boolean, default: false
  field :isbns
  field :isbns_normalized
  field :issn_normalized
  field :lccn_normalized
  field :last_modified, type: DateTime
  field :line_number, type: Integer
  field :local_id
  field :oclc_alleged
  field :oclc_resolved
  field :org_code, type: String, default: "miaahdl"
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
  @@collator = Collator.new(__dir__+'/../config/traject_config.rb')
  @@contrib_001 = {}
  open(__dir__+'/../config/contributors_w_001_oclcs.txt').each{ |l| @@contrib_001[l.chomp] = 1 }

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
    super(s)
    @@collator.normalize_viaf(s).each {|k, v| self.send("#{k}=",v) }
    self.extract_identifiers
    self.ec = self.extract_enum_chrons
    self.enum_chrons = self.ec.collect do | k,fields |
      if !fields['canonical'].nil?
        fields['canonical']
      else
        fields['string']
      end
    end
    if self.org_code == 'miaahdl'
      self.extract_holdings
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
  def extract_identifiers
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
  
    marc = MARC::Record.new_from_hash(self.source)
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
  # Assumes if "001" if no field is provided. 
  def extract_local_id field = nil
    field ||= '001'
    id = self.source["fields"].find{|f| f[field]}[field].gsub(/ /, '')
    return id
  end

  # Determine HT availability. 'Full View', 'Limited View', 'not available'
  #
  def ht_availability
    if self.org_code == 'miaahdl'
      if self.source_blob =~ /.r.:.pd./
        return 'Full View'
      else
        return 'Limited View'
      end
    else
      return nil
    end
  end

  # Determine if this is a govdoc based on 008 and 086
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
    f008 =~ /^.{17}u.{10}f/ or self.sudocs.count > 0 or self.extract_sudocs(marc).count > 0
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
        elsif field.indicator1.strip == '' and field['a'] =~ /:/ and field['2'].nil? 
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
    self.sudocs = self.sudocs - self.non_sudocs
    self.sudocs
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
    tag, subcode = @@marc_profiles[org_code]['enum_chrons'].split(/ /)
    marc.each_by_tag(tag) do | field | 
      subfield_codes = field.find_all { |subfield| subfield.code == subcode }
      if subfield_codes.count > 0
        if org_code == "dgpo"
          #take the second one if it's from gpo?
          if subfield_codes.count > 1
            ec_strings << Normalize.enum_chron(subfield_codes[1].value)
          end
        else
          ec_strings << subfield_codes.map {|sf| Normalize.enum_chron(sf.value) }
        end
      end
    end
    ec_strings.flatten
  end

  #######
  # extract_enum_chrons
  #
  # ecs - {<hashed canonical ec string> : {<parsed features>}, }
  #
  def extract_enum_chrons(marc=nil, org_code=nil, ec_strings=nil)
    ecs = {}
    org_code ||= self.org_code
    
    if ec_strings.nil?
      ec_strings = self.extract_enum_chron_strings marc
    end
    ec_strings ||= []

    #parse out all of their features
    ec_strings.uniq.each do | ec_string | 
      
      # Series specific parsing 
      if !self.series.nil? and self.series != ''
        parsed_ec = eval(self.series).parse_ec ec_string
        # able to parse it?
        if !parsed_ec.nil?
          parsed_ec['string'] = ec_string
          exploded = eval(self.series).explode(parsed_ec)
          # just because we parsed it doesn't mean we can do anything with it
          if exploded.keys.count() > 0
            exploded.each do | canonical, features | 
              features['string'] = ec_string
              features['canonical'] = canonical
              #possible to have multiple ec_strings be reduced to a single ec_string
              ecs[Digest::SHA256.hexdigest(canonical)] ||= features 
              ecs[Digest::SHA256.hexdigest(canonical)].merge( features )
            end
          else #parsed not explodeable
            ecs[Digest::SHA256.hexdigest(ec_string)] ||= parsed_ec
            ecs[Digest::SHA256.hexdigest(ec_string)].merge( parsed_ec )
          end
        else  #not parseable
          ecs[Digest::SHA256.hexdigest(ec_string)] = {'string'=>ec_string}
        end
      else #unknown series, do nothing. todo: default enumchron processing?
        #we got nothing, raw string with no features
        ecs[Digest::SHA256.hexdigest(ec_string)] = {'string'=>ec_string}
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
  # todo: refactor with extract_enum_chrons. A lot of duplicate code/work being done
  def extract_holdings marc=nil
    self.holdings = {}
    marc ||= MARC::Record.new_from_hash(self.source)
    marc.each_by_tag('974') do |field|
      z = field['z']
      z ||= ''
      ec_string = Normalize.enum_chron(field['z'])

      #possible to parse/explode one enumchron into many for select series
      ecs = []
      if self.series.nil? or self.series == ''
        ecs << ec_string
      else
        parsed_ec = eval(self.series).parse_ec ec_string
        if !parsed_ec.nil?
          exploded = eval(self.series).explode(parsed_ec)
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
        self.holdings[ec] ||= [] #array of holdings for this enumchron
        self.holdings[ec] << {c:field['c'], 
                              z:field['z'],
                              y:field['y'],
                              r:field['r'],
                              s:field['s'],
                              u:field['u']}
      end
    end #each 974
  end
    

  # series
  #
  # Uses oclc_resolved to identify a series title (and appropriate module)
  def series
    if !@series.nil?
      @series
    end
    case
    when (self.oclc_resolved.map{|o|o.to_i} & FederalRegister.oclcs).count > 0
      @series = 'FederalRegister'
    when (self.oclc_resolved.map{|o|o.to_i} & StatutesAtLarge.oclcs).count > 0
      @series = 'StatutesAtLarge'
    when (self.oclc_resolved.map{|o|o.to_i} & AgriculturalStatistics.oclcs).count > 0
      @series = 'AgriculturalStatistics'
    end
    @series
  end

  def self.parse_ec ec
    nil 
  end

  def self.explode ec
    {} 
  end

  def save
    self.last_modified = Time.now.utc
    super
  end

  def self.marc_profiles
    @@marc_profiles
  end

  def self.get_marc_profiles
    Dir.glob(__dir__+'/../config/marc_profiles/*.yml').each do |profile|
      p = YAML.load_file(profile)
      @@marc_profiles[p["org_code"]] = p 
    end
  end
  self.get_marc_profiles

end


