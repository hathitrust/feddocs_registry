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
  field :deprecated_reason, type: String
  field :deprecated_timestamp, type: DateTime

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


