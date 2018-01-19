# frozen_string_literal: true

require 'registry/registry_record'
require 'registry/source_record'
require 'dotenv'
SourceRecord = Registry::SourceRecord
RegistryRecord = Registry::RegistryRecord
# takes a text file with an oclc on each line,
# and spits out the raw enumchron strings.

Dotenv.load!

oclcs = open(ARGV.shift).read.split("\n").map(&:to_i)

Mongoid.load!(ENV['MONGOID_CONF'], :production)
SourceRecord.where(oclc_resolved: { "$in": oclcs },
                   deprecated_timestamp: { "$exists": 0 }).each do |src|
  src.extract_enum_chron_strings.each do |ec|
    puts ec
  end
end
