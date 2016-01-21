require 'mongoid'
require 'securerandom'
require 'marc'

class SourceRecord
  include Mongoid::Document
  include Mongoid::Attributes::Dynamic

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
  field :isbn_raw, type: String
  field :isbn_normalized, type: String
  field :sudoc_raw, type: String
  field :sudoc_stem, type: String
  field :sudoc_suffix, type: String
  

  def initialize
    super
    self.source_id ||= SecureRandom.uuid()
  end

  def source=(value)
    super(JSON.parse(value))
  end

  def deprecate( reason )
    self.deprecated_reason = reason
    self.deprecated_timestamp = Time.now.utc
    self.save
  end
      
end


