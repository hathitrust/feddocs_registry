require 'json'
require 'marc'
require 'traject'
require 'traject/indexer/settings'
require 'securerandom'
require 'normalize'

module Registry
  class Collator
    attr_accessor :extractor
    attr_accessor :viaf
   
    # Get our Traject::Indexer and Viaf 
    def initialize(traject_config)
      @extractor = Traject::Indexer.new
      @extractor.load_config_file(traject_config)
    end

    # Extracts fields from SourceRecords using traject config. 
    #
    # sources - Array of SourceRecords. 
    def extract_fields sources
      fields = {}
      fields[:ht_ids_fv] = []
      fields[:ht_ids_lv] = []
      fields[:source_org_codes] = sources.collect{|s| s.org_code}.flatten.uniq
      fields[:sudoc_display] = sources.collect{|s| s.sudocs}.flatten.uniq
      fields[:oclcnum_t] = sources.collect{|s| s.oclc_resolved}.flatten.uniq
      fields[:isbn_t] = sources.collect{|s| s.isbns_normalized}.flatten.uniq
      fields[:issn_t] = sources.collect{|s| s.issn_normalized}.flatten.uniq
      fields[:lccn_t] = sources.collect{|s| s.lccn_normalized}.flatten.uniq
      fields[:author_lccns] = sources.collect{|s| s.author_lccns}.flatten.uniq
      fields[:report_numbers] = sources.collect{|s| s.report_numbers}.flatten.uniq
      fields[:added_entry_lccns] = sources.collect{|s| s.added_entry_lccns}.flatten.uniq
      fields[:electronic_resources] = sources.collect{|s| s.electronic_resources}.flatten.uniq
      fields[:related_electronic_resources] = sources.collect{|s| s.related_electronic_resources}.flatten.uniq
      fields[:electronic_versions] = sources.collect{|s| s.electronic_versions}.flatten.uniq
      sources.each do | rec | 
    
        if rec.ht_availability == 'Full View'
          fields[:ht_ids_fv] << rec[:source]["fields"][0]["001"]
        elsif rec.ht_availability == 'Limited View'
          fields[:ht_ids_lv] << rec[:source]["fields"][0]["001"]
        end      

        base_marc = MARC::Record.new_from_hash(rec.source)
        #extract this record's fields into the cluster's fields
        fields.merge!( @extractor.map_record(base_marc) ) do | key, v1, v2 |
          #key conflict results in flattened/uniqued array
          [v1].flatten | [v2].flatten
        end

      end
    
      return fields
    end
  end #class Collator
end
