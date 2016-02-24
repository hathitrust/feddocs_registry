require 'json'
require 'marc'
require 'traject'
require 'traject/indexer/settings'
require 'securerandom'
require 'viaf'


class Collator
  attr_accessor :extractor
  attr_accessor :viaf
 
  # Get our Traject::Indexer and Viaf 
  def initialize(traject_config)
    @extractor = Traject::Indexer.new
    @extractor.load_config_file(traject_config)
    @viaf = Viaf.new()
  end

  # Extracts and normalizes fields from SourceRecords using traject config. 
  #
  # sources - Array of SourceRecords. 
  def extract_fields sources
    fields = {}
    fields[:ht_ids_fv] = []
    fields[:ht_ids_lv] = []
    fields[:sudoc_display] = sources.collect{|s| s.sudocs}.flatten.uniq
    fields[:oclcnum_t] = sources.collect{|s| s.oclc_resolved}.flatten.uniq
    fields[:isbn_t] = sources.collect{|s| s.isbns_normalized}.flatten.uniq
    fields[:issn_t] = sources.collect{|s| s.issn_normalized}.flatten.uniq
    fields[:lccn_t] = sources.collect{|s| s.lccn_normalized}.flatten.uniq

    sources.each do | rec | 
  
      if rec.ht_availability == 'Full View'
        fields[:ht_ids_fv] << rec[:source][:fields][0]["001"]
      elsif rec.ht_availability == 'Limited View'
        fields[:ht_ids_lv] << rec[:source][:fields][0]["001"]
      end      

      base_marc = MARC::Record.new_from_hash(rec.source)
      #extract this record's fields into the cluster's fields
      fields.merge!( @extractor.map_record(base_marc) ) do | key, v1, v2 |
        #key conflict results in flattened/uniqued array
        [v1].flatten | [v2].flatten
      end

      self.normalize_viaf(rec.source).each do | key, nf_array | 
        if fields.has_key? key
          fields[key] = fields[key] | nf_array
        else
          fields[key] = nf_array
        end
      end 
    end
  
    return fields
  end

  # Normalizes 110/260 fields and tries to find viaf_ids
  def normalize_viaf source
    #what we are building (kind of a dumb structure, but it's going into solr)
    normalized_fields = {'publisher_viaf_ids'=>[], 'publisher_headings'=>[], 'publisher_normalized'=>[],
                         'author_viaf_ids'=>[], 'author_headings'=>[], 'author_normalized'=>[],
                         'author_addl_viaf_ids'=>[], 'author_addl_headings'=>[], 'author_addl_normalized'=>[]}
                    
    marc_fields = {"260"=>"publisher","110"=>"author","710"=>"author_addl"} #we're doing corporate author and publisher
    marc_fields.keys.each do | fnum |
      corp_fields = source["fields"].find {|f| f.has_key? fnum}
      next if !corp_fields
      corp_fields.each do | field_name, corp_field |
        indicator = corp_field["ind1"].chomp    
        subfields = []
        corp_field["subfields"].each_with_index do |s, position|
          if (fnum == "260" and s.keys[0] == "b") or fnum != "260"
            subfields.push s.values[0].chomp
          end
        end
        
        viafs = @viaf.get_viaf( subfields ) #hash: viaf_id => normalized heading 
      
        if viafs.size > 0 
          normalized_fields[marc_fields[fnum]+'_viaf_ids'] << viafs.keys
          #get_viaf gave us the heading too
          normalized_fields[marc_fields[fnum]+'_headings'] << viafs.values
        end
        #get_viaf already did this, but didn't return it. oops?
        #normalize the subfields, then normalize the normalized subfields
        normalized_fields[marc_fields[fnum]+'_normalized'] << normalize_corporate(subfields.map{ |sf| normalize_corporate(sf)}.join(' '), false) 
      end #each matching field, e.g. multiple 710s or 260s.  
      normalized_fields[marc_fields[fnum]+'_viaf_ids'].flatten!
      normalized_fields[marc_fields[fnum]+'_headings'].flatten!
      normalized_fields[marc_fields[fnum]+'_normalized'].flatten!
      
    end #each match for [260,110,710]
    
    return normalized_fields

  end
   
end #class Collator

