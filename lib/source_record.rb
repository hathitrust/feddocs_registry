require 'mongoid'
require 'securerandom'
require 'marc'
require 'pp'
require 'dotenv'
require 'collator'
require 'yaml'

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
  field :file_path, type: String
  field :formats, type: Array
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
  field :org_code, type: String
  field :publisher_headings
  field :publisher_normalized
  field :publisher_viaf_ids
  field :source
  field :source_blob, type: String
  field :source_id, type: String
  field :sudocs

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
   
  def initialize
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

  # Extracts SuDocs
  #
  # marc - ruby-marc representation of source
  def extract_sudocs marc=nil
    marc ||= MARC::Record.new_from_hash(self.source)
    self.sudocs = []

    marc.each_by_tag('086') do | field |
      # Supposed to be in 086/ind1=0, but some records are dumb. 
      if field['a'] and (field.indicator1 == '0' or field['a'] =~ /:/)
        self.sudocs << field['a'].chomp
      end
    end
    self.sudocs.uniq!
    return self.sudocs
  end

  def extract_oclcs marc=nil
    marc ||= MARC.Record.new_from_hash(self.source)
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
    return self.oclc_alleged

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

  #######
  # extract_enum_chrons
  #
  def extract_enum_chrons(marc=nil, org_code=nil)
    marc ||= MARC::Record.new_from_hash(self.source)
    org_code ||= self.org_code
    
    enum_chrons = []

    tag, subcode = @@marc_profiles[org_code]['enum_chrons'].split(/ /)
    marc.each_by_tag(tag) do | field |
      subfield_codes = field.find_all { |subfield| subfield.code == subcode }
      if subfield_codes.count > 0
        #take the last one? this is at least true for gpo. maybe not others
        enum_chrons << Normalize.enum_chron(subfield_codes.pop.value)
      end
    end
    return enum_chrons 
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


