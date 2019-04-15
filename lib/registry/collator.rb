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
      @extractor = Traject::Indexer::MarcIndexer.new
      @extractor.load_config_file(traject_config)
    end

    # Extracts fields from SourceRecords using traject config.
    #
    # sources - Array of SourceRecords.
    def extract_fields(sources)
      fields = {}
      fields[:ht_ids_fv] = []
      fields[:ht_ids_lv] = []
      fields[:source_org_codes] = sources.collect(&:org_code).flatten.uniq
      fields[:sudocs] = sources.collect(&:sudocs).flatten.uniq
      fields[:oclc] = sources.collect(&:oclc_resolved).flatten.uniq
      fields[:isbn] = sources.collect(&:isbns_normalized).flatten.uniq
      fields[:issn] = sources.collect(&:issn_normalized).flatten.uniq
      fields[:lccn] = sources.collect(&:lccn_normalized).flatten.uniq
      fields[:author] = sources.collect(&:author).flatten.uniq
      fields[:author_lccns] = sources.collect(&:author_lccns).flatten.uniq
      fields[:report_numbers] = sources.collect(&:report_numbers).flatten.uniq
      fields[:added_entry_lccns] = sources.collect(&:added_entry_lccns).flatten.uniq
      fields[:electronic_resources] = sources.collect(&:electronic_resources).flatten.uniq
      fields[:related_electronic_resources] = sources.collect(&:related_electronic_resources).flatten.uniq
      fields[:electronic_versions] = sources.collect(&:electronic_versions).flatten.uniq
      fields[:publisher] = sources.collect(&:publisher).flatten.uniq
      fields[:pub_date] = sources.collect(&:pub_date).flatten.uniq
      fields[:gpo_item_numbers] = sources.collect(&:gpo_item_numbers).flatten.uniq
      sources.each do |rec|
        if rec.ht_availability == 'Full View'
          fields[:ht_ids_fv] << rec.local_id
        elsif rec.ht_availability == 'Limited View'
          fields[:ht_ids_lv] << rec.local_id
        end

        base_marc = MARC::Record.new_from_hash(rec.source)
        # extract this record's fields into the cluster's fields
        fields.merge!(@extractor.map_record(base_marc)) do |_key, v1, v2|
          # key conflict results in flattened/uniqued array
          [v1].flatten | [v2].flatten
        end
      end

      fields
    end
  end # class Collator
end
