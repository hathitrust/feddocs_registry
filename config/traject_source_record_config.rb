require 'pp'
require 'library_stdnums'
require_relative '../lib/registry/normalize'
require 'nauth/authority'

Authority = Nauth::Authority

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

to_field 'author', extract_marc('100abcdgqu:110abcdgnu:111acdegjnqu')

to_field 'author_lccns', extract_marc('100abcd:110abntd') do |_rec, acc|
  acc.map! { |auth| Authority.search(auth)&.sameAs }
  acc.flatten!
  acc.delete(nil)
  acc.uniq!
end

to_field 'added_entry_lccns', extract_marc('700abcd:710abntd') do |_rec, acc|
  acc.map! { |auth| Authority.search(auth)&.sameAs }
  acc.flatten!
  acc.delete(nil)
  acc.uniq!
end

# formats
to_field 'formats', marc_formats

# gpo_item_numbers
to_field 'gpo_item_numbers', extract_marc('074a')

# publisher
to_field 'publisher', extract_marc('260b')

# pubdate
to_field 'pub_date', marc_publication_date

# electronic_resources
to_field 'electronic_resources', extract_marc('856|4 |u:856|40|u')
to_field 'electronic_versions', extract_marc('856|41|u')
to_field 'related_electronic_resources', extract_marc('856|42|u')

# report numbers, esp. for OSTI
to_field 'report_numbers', extract_marc('088a')

# Library of Congress Control Numbers
to_field 'lccn_normalized', extract_marc('010a') do |_rec, acc|
  acc.map! { |lccn| StdNum::LCCN.normalize(lccn.sub(/^@@/, '')) }
  acc.flatten!
  acc.delete(nil)
  acc.uniq!
end

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
