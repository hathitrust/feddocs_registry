require 'mongoid'
require 'securerandom'
require 'marc'

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

  @@collator = Collator.new(__dir__+'/../config/traject_config.rb')

  def initialize
    super
    self.source_id ||= SecureRandom.uuid()
  end

  def source=(value)
    s = JSON.parse(value)
    super(s)
    @@collator.normalize_viaf(s).each {|k, v| self.send("#{k}=",v) }
  end

  def deprecate( reason )
    self.deprecated_reason = reason
    self.deprecated_timestamp = Time.now.utc
    self.save
  end
      
end


