# Mongoid (orm) classes for Registry records and Source records. 



## SourceRecord

Contains methods for extracting identifiers and resolving oclcs. Primarily the source MARC string and extracted features (e.g. identifiers, enumeration/chronology). 



## RegistryRecord

Defines a Registry record as a cluster of SourceRecord ids and an enumeration/chronology. Defines process for splitting, merging, and deprecating a Registry record. 


## Collator

Used by SourceRecords and RegistryRecords to extract, normalize, and collect VIAF ids (.normalize_viaf). 

Using a traject config, extracts and compiles fields from multiple sources into a single data structure. Establishes HT availability. 

## Registry
  --> RegistryRecord
  --> SourceRecord
  --> Series
      --> AgriculturalStatistics
      --> CongressionalSerialSet
      --> FederalRegister
      --> UnitedStatesReports 
      --> CivilRightsCommission
      --> ForeignRelations
      --> StatisticalAbstract
      --> CongressionalRecord
      --> EconomicReportOfThePresident
      --> MonthlyLaborReview
      --> StatutesAtLarge

## More Documentation (not public)
https://tools.lib.umich.edu/confluence/display/HAT/Federal+Documents+Registry


## Examples

Note "dotenv_example" and "config/mongoid_sample.yml." 

https://github.com/HTGovdocs/registry_migrations

https://github.com/HTGovdocs/solr_indexing



