ancestors
---------
	type: Array of strings
	An array of registry IDs for records that have been superseded by this record,
	e.g. through merging.

deprecated_timestamp
--------------------
	type: DateTime, null if not deprecated
	Date and time record was deprecated

deprecated_reason
-----------------
	type: String, null if not deprecated
	Reason for deprecation

last_modified
-------------
	type: DateTime
	A timestamp for the last time this record was touched. Useful for debugging
	migrations and parsing changes.

registry_id
---------
	type: String
	A UUID assigned at creation that does what a UUID is supposed to. Used in
	Registry Records' ancestors field. Preferrence over MongoDb's default
	_id field is largely an accident of implementation history. 

author_lccns
-----------
	type:Array of strings
	URLs for name authorities for the author.
	MARC 100 and 110
	e.g. https://lccn.loc.gov/n79086751

added_entry_lccns
--------------------
	type: array of strings
 	URLs for name authorities
	MARC 700 and 710


series
------
	type: Array of strings
	An array containing strings identifying the series module name responsible for
	enumeration/chronology processing. This is NOT a series title although it may be
	similar. Some are not series at all, but a collection of similar/related
	documents that can be processed together, e.g. Civil Rights Commission. This
	was originally a single string but has become an (ordered) array of strings, 
  because documents may be members of multiple series. Unlike Source Records, 
  series for Registry Records are the module names expanded with whitespace so 
  as to be a bit friendlier for human display. e.g. CivilRightsCommission vs 
  Civil Rights Commission. 

print_holdings_t
----------------
  type: array of strings
  member ids taken from the print holdings database, queried using OCLCs. 

source_record_ids
-----------------
	type: array of strings
	The list of Source Records used as evidence for this Registry Record. This
	list cannot be changed with the exception of the addition of records. Removal of
	source records requires merging/deprecation. 

	
source_org_codes
----------------
	type: Array of strings
	List of contributors that have provided an associated source record for this
	registry record. MARC organization codes. 

creation_notes
--------------
	type: String
	Why does this registry record exist? Better enum/chron parsing? HT ingest on a
	particular date?
  
enumchron_display
-----------------
 	type: String, default: ""
	The enumeration/chronology for this registry record. Should not be changed;
	the record should be deprecated and replaced with a new record. todo: enforce
	immutability of the enumchron_display in the model.	

suppressed
----------
	type: Boolean, default: false
	Has this record been deprecated? Used in updating Solr. Maybe redundant with
	deprecated_timestamp. todo: look into removing

ht_ids_fv
---------
	type: array of strings
	Zephir ids for clusters that contain this registry record. Something in this
	cluster, not necessarily the volume that gave us this Registry Record, is full view. todo: fix the
	naming of HT ids and Zephir ids. More precisely identify the relationship
	between Registry Record and volumes. 

ht_ids_lv
---------
	type: array of strings
	Zephir ids for clusters that contain this registry record. Something in this
	cluster, not necessarily the volume that gave us this Registry Record, is limited view. todo: fix the
	naming of HT ids and Zephir ids. More precisely identify the relationship
	between Registry Record and volumes. 

ht_availability
---------------
	type: String
	Whether or not this item can be found in HathiTrust. Options are "Full View",
	"Limited View", and "Not In HathiTrust"	
 
electronic_resources
--------------------
  type: array of strings
  Pulled from 856, indicators 4 or 40

electronic_versions
-------------------
  type: array of strings
  Pulled from 856, indicators 41

related_electronic_resources
----------------------------
  type: array of strings
  Pulled from 856, indicators 42  
