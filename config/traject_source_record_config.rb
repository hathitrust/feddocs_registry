require 'pp'
require 'library_stdnums'
require_relative '../lib/registry/normalize'

# A traject configuration for the SourceRecord class.
# Used to pull out just the fields we want without having to manually
# traverse the MARC record.

# To have access to various built-in logic
# for pulling things out of MARC21, like `marc_languages`
require 'traject/macros/marc21_semantics'
extend  Traject::Macros::Marc21Semantics

# To have access to the traject marc format/carrier classifier
require 'traject/macros/marc_format_classifier'
extend Traject::Macros::MarcFormats

# In this case for simplicity we provide all our settings, including
# solr connection details, in this one file. But you could choose
# to separate them into antoher config file; divide things between
# files however you like, you can call traject with as many
# config files as you like, `traject -c one.rb -c two.rb -c etc.rb`
settings do
  provide 'reader_class_name', 'Traject::NDJReader'
  provide 'marc_source.type', 'json'
end

# author

to_field 'author_headings', extract_marc('100abcdgqu:110abcdgnu:111acdegjnqu')
to_field 'author_parts', extract_marc('100abcdgqu:110abcdgnu:111acdegjnqu', separator: nil)
to_field 'author_lccn_lookup', extract_marc('100abcd:110abntd')
to_field 'added_entry_lccn_lookup', extract_marc('700abcd:710abntd')

# publisher
to_field 'publisher_headings', extract_marc('260b')

# pubdate
to_field 'pub_date', marc_publication_date

# electronic_resources
to_field 'electronic_resources', extract_marc('856|4 |u:856|40|u')
to_field 'electronic_versions', extract_marc('856|41|u')
to_field 'related_electronic_resources', extract_marc('856|42|u')

# report numbers, esp. for OSTI
to_field 'report_numbers', extract_marc('088a')

# LC call numbers
to_field 'lc_call_numbers', extract_marc('050ab', separator: '')
to_field 'lc_classifications', extract_marc('050a')
to_field 'lc_item_numbers', extract_marc('050b')

# issns
to_field 'issn_normalized', extract_marc('022a:776x') do |_rec, acc|
  acc.map! { |issn| StdNum::ISSN.normalize(issn) }
  acc.flatten!
  acc.uniq!
end

# isbns
to_field 'isbns_normalized', extract_marc('020a:776z') do |_rec, acc|
  acc.map! { |isbn| StdNum::ISBN.normalize(isbn) }
  acc.flatten!
  acc.uniq!
end
