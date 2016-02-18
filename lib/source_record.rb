require 'mongoid'
require 'securerandom'
require 'marc'
require 'pp'
require 'dotenv'
require 'collator'

class SourceRecord
  include Mongoid::Document
  include Mongoid::Attributes::Dynamic
  store_in collection: "source_records"

  field :source_id, type: String
  field :file_path, type: String
  field :line_number, type: Integer
  field :source
  field :source_blob, type: String
  field :deprecated_reason, type: String
  field :deprecated_timestamp, type: DateTime
  field :org_code, type: String
  field :local_id, type: String
  field :last_modified, type: DateTime
  field :oclc_alleged
  field :oclc_resolved
  field :lccn_normalized
  field :issn_normalized
  field :isbns
  field :isbns_normalized
  field :sudocs
  field :publisher_viaf_ids
  field :publisher_headings
  field :publisher_normalized
  field :author_viaf_ids
  field :author_headings
  field :author_normalized
  field :author_addl_viaf_ids
  field :author_addl_headings
  field :author_addl_normalized

  #this stuff is extra ugly
  Dotenv.load
  @@collator = Collator.new(__dir__+'/../config/traject_config.rb')
  @@contrib_001 = {}
  open(__dir__+'/../config/contributors_w_001_oclcs.txt').each{ |l| @@contrib_001[l.chomp] = 1 }
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
  # todo: Refactor. Traject might be a better way of addressing this. 
  def extract_identifiers
    self.org_code ||= "" #should be set on ingest. 
    self.oclc_alleged ||= []
    self.oclc_resolved ||= []
    self.lccn_normalized ||= []
    self.issn_normalized ||= []
    self.sudocs ||= []
    self.isbns ||= []
    self.isbns_normalized ||= []
   
    self.source["fields"].each do | f | 

      #########
      # OCLC

      #035a's and 035z's 
      if f["035"]
        as = f["035"]["subfields"].select { | sf | sf.keys[0] == "a" }

        if as.count > 0 and OCLCPAT.match(as[0]["a"]) 
          oclc = $1.to_i
          if oclc
            self.oclc_alleged << oclc
          end
        end
      end

      #OCLC prefix in 001
      if f["001"] and OCLCPAT.match(f["001"])
        self.oclc_alleged << $1.to_i
      end

      #contributors who told us to look in the 001
      if f["001"] and @@contrib_001[self.org_code] and /^(\d+)$/x.match(f["001"])
        self.oclc_alleged << $1.to_i
      end

      #Indiana told us 955$o. Not likely, but...
      if self.org_code == "inu" and f["955"]
        o955 = f["955"]["subfields"].select { | sf | sf.keys[0] == "o" }
        o955.each do | o | 
          if /(\d+)/.match(o["o"])
            self.oclc_alleged << $1.to_i
          end
        end
      end

      #########
      # LCCN

      if f["010"] 
        as = f["010"]["subfields"].select { | sf | sf.keys[0] == "a" }

        if as.count > 0 and as[0]["a"] != ''
          lccn = StdNum::LCCN.normalize(as[0]["a"].downcase)
          self.lccn_normalized << lccn 
        end
      end

      #########
      # ISSN

      if f['022']
        as = f["022"]["subfields"].select { | sf | sf.keys[0] == "a" }

        if as.count > 0 and as[0]["a"] != ''
          issn = StdNum::ISSN.normalize(as[0]["a"])
          self.issn_normalized << issn 
        end
      end

      #########
      # sudoc (086)
      if f["086"]
        as = f["086"]["subfields"].select { | sf | sf.keys[0] == "a" } #NR so 1

        if as.count > 0 and as[0]["a"] != ""
          self.sudocs << as[0]["a"]
        end
      end

      ##########
      # ISBN
      if f["020"] 
        as = f["020"]["subfields"].select { | sf | sf.keys[0] == "a" } #NR so 1

        if as.count > 0 and as[0]["a"] != ""
          self.isbns << as[0]["a"]
          isbn = StdNum::ISBN.normalize(as[0]["a"])
          if isbn and isbn != ''
            self.isbns_normalized << isbn 
          end
        end
      end

    end #each field
  
    self.oclc_alleged.uniq!
    self.oclc_resolved = self.resolve_oclc(self.oclc_alleged).uniq
    self.lccn_normalized.uniq!
    self.issn_normalized.uniq!
    self.sudocs.uniq!
    self.isbns.uniq!
    self.isbns_normalized.uniq!

  end #extract_identifiers

  # Hit the oclc_authoritative collection for OCLC resolution. 
  # Bit of a kludge.
  def resolve_oclc oclcs
    resolved = []
    oclcs.each do | oa |
      @@mc[:oclc_authoritative].find(:duplicates => oa).each do | ores | #1?
        resolved << ores[:oclc].int
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

  def save
    self.last_modified = Time.now.utc
    super
  end
end


