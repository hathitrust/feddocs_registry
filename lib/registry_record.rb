require 'mongoid'
require 'securerandom'
require 'pp'

class RegistryRecord
  include Mongoid::Document
  include Mongoid::Attributes::Dynamic
  store_in collection: "registry"
  field :registry_id, type: String
  field :lastModified, type: DateTime
  field :ancestors, type: Array
  field :deprecated_reason, type: String
  field :deprecated_timestamp, type: DateTime
  field :source_record_ids, type: Array
  field :creation_notes, type: String
  field :enumchron_display, type: String

  def initialize( sid_cluster, enum_chron, notes, ancestors=nil )
    super()
    #collate the source records into a coherent whole 
    self.source_record_ids = sid_cluster
    @sources = SourceRecord.where(:source_id.in => sid_cluster)
    self.ancestors = ancestors
    self.creation_notes = notes
    self.registry_id = SecureRandom.uuid()
    self.enumchron_display = enum_chron
  end   
    

  #splits registry record into two or more successor records
  def split( sid_clusters, reason )
    #sid_clusters is hash of arrays to enum chron
    # { ["<sid_1>", "<sid_2>"] => "ec a", ["<sid_3>", "<sid_4>"] => "ec b"}
    new_recs = []
    sid_clusters.each do | cluster, enum_chron |
      new_recs << RegistryRecord.new(cluster, enum_chron, reason, [self.registry_id])
    end
    
    self.deprecate(reason, new_recs.collect{|r| r.registry_id})
    self.save 
    return new_recs
  end

  def deprecate( reason, successors=nil )
    #successors is an optional array of new RegistryRecords that replaced this one
    self.deprecated_reason = reason
    self.deprecated_timestamp = Time.now.utc
    if successors 
      self[:successors] = successors
    end

    self.save
  end

  def RegistryRecord.merge( ids, enum_chron, reason )
    #merge existing reg records
    recs = RegistryRecord.where(:registry_id.in => ids) 
    new_rec = RegistryRecord.new(recs.collect { |r| r.source_record_ids }.flatten.uniq, enum_chron, reason, ids)
    new_rec.save
    recs.each {|r| r.deprecate( reason, [new_rec.registry_id] )}
    return new_rec
  end

  def sources
    unless @sources
      @sources = SourceRecord.where(:source_id.in => self.source_record_ids)
    end
    @sources
  end

  def save
    self.lastModified = Time.now.utc
    super
  end


end


