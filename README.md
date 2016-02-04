# Mongoid (orm) classes for Registry records and Source records. 



## SourceRecord

Contains methods for extracting identifiers and resolving oclcs. Primarily the source MARC string and extracted features (e.g. identifiers, enumeration/chronology). 



## RegistryRecord

Defines a Registry record as a cluster of SourceRecord ids and an enumeration/chronology. Defines process for splitting, merging, and deprecating a Registry record. 


## Collator

Used by SourceRecords and RegistryRecords to extract, normalize, and collect VIAF ids (.normalize_viaf). 

Using a traject config, extracts and compiles fields from multiple sources into a single data structure. Establishes HT availability. 


## Examples

Note "dotenv_example" and "config/mongoid_sample.yml." 

https://github.com/HTGovdocs/transformation_logging

https://github.com/HTGovdocs/solr_indexing



