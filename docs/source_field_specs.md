author_headings
---------------
	type: array of strings
	MARC 110

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

cataloging_agency
-----------------
	Not currently used. Use it or lose it. todo

deprecated_timestamp
--------------------
	type: DateTime, null if not deprecated
	Date and time record was deprecated

deprecated_reason
-----------------
	type: String, null if not deprecated
	Reason for deprecation

electronic_resources
--------------------
  type: Array of strings(URLs)
  Electronic resources extracted from the 856|4[\*0]|

electronic_versions
-------------------
  type: Array of strings(URLs)
  Electronic versions extracted from 856|41|

related_electronic_resources
-------------------
  type: Array of strings(URLs)
  Related electronic resources extracted from 856|42|

enum_chrons
-----------
  type: array of strings. array containing a single string of 0 length if no
	item level information found. 
  Enumeration/chronology strings used for Registry comparisons. The canonical
	representation is used if possible. Otherwise, a normalized string is used.
	These are collected from the 'ec' document after parsing/exploding. 
	
ec
--
	type: document
	Our interpretation of the item level information after series specific or
	default processing has been performed. Includes canonical forms, string
	representations and features extracted. 

file_path
---------
	type: string
	The location of the source MARC	in the file system. This is not actively
	maintained and may no longer serve a purpose. Original contributed source files
	have not been consulted since 2016Q1. 

formats
-------
	type: array of strings
	Formats extracted from the MARC using Traject::Macros::MarcFormatClassifier.

gpo_item_numbers
----------------
	type: array of strings
	MARC 074a

holdings
--------
	type: document
	Designed for HT records that have individual holding info in 974. The 974s are
	transformed into a coherent holdings field grouped by normalized/parsed
	enum_chrons.
	e.g. holdings = {<ec_string> :[<each holding>]
	
ht_item_ids
-----------
	type: array of strings
	For HT records only. The list of 974u found in this record's holdings.

in_registry
-----------
	type: Boolean, default: false
	Can this record be found in an active Registry Record. Questionable if this
	state is tracked appropriately. 

isbns
-----
	type: array of strings
	List of raw ISBNs found in MARC 020a. Use case for this field is unclear.
	isbns_normalized should be sufficient for our purposes. todo

isbns_normalized
----------------
	type: array of strings
	List of ISBNs run through StdNum::ISBN.normalize

issn_normalized
---------------
	type: array of strings
	List of ISSNs (MARC 022a) run through StdNum::ISSN.normalize.

lccn_normalized
---------------
	type: array of strings
	List of LCCNs (MARC 010a) run through StdNum::LCCN.normalize.

last_modified
-------------
	type: DateTime
	A timestamp for the last time this record was touched. Useful for debugging
	migrations and parsing changes.

line_number
-----------
	type: Integer
	The line number in the .ndj source file. Like the file_path field, at the time
	of the original ingest this was useful. The utility of this field going forward
	is limited. 

local_id
--------
	type: String 
	An attempt to extract the system id from the source record. This has proven to
	be more difficult than it should be. This is especially important for HathiTrust
	and GPO records as (re)ingest depends upon them. 

oclc_alleged
------------
	type: array of integers
	Numbers taken from MARC 001 if it has a matching prefix and MARC 035a. Numbers
	are also taken from MARC 776w, as we do not distinguish between different
	physical formats. There is some special handling for Indiana records because
	they told us to look in 955o. 

oclc_resolved
-------------
	type: array of integers
	Numbers retrieved from the resolution table using the list in oclc_alleged.
	
org_code
--------
	type: String, default: "miaahdl"
	The MARC organization code for the source of this record. This is necessary
	because contributors have different MARC profiles for extraction of OCLC
	numbers, system identifiers, and holdings. This field was added after the
	initial ingest of contributor records. At the time, HathiTrust records were the
	only records being updated and inserted. It may be advisable to remove the
	default and throw an error now that multiple sources are being used for updates.
	todo

pub_date
--------
	type: String ( because this MARC and MARC doesn't do actual dates )
	Extracted using Traject's marc_publication_date which uses the 008. 

publisher_headings
------------------
  type: array of strings 
  MARC 260

series
------
	type: array of strings
	An array of strings identifying the series module name responsible for
	enumeration/chronology processing. This is NOT a series title although it may be
	similar. Some are not series at all, but a collection of similar/related
	documents that can be processed together, e.g. Civil Rights Commission. This
	has become an (ordered) array of strings, because documents may be members of
	multiple series. The first series in the array is used for enumchron parsing. 

source
------
	type: JSON document
	The entire MARC record as a JSON document. Sometimes useful for querying, but
	often inefficient and difficult to use because MARC. It may be more appropriate
	to simply retain the source_blob and parse on demand. Test performance issues
	for both solutions. todo

source_blob
-----------
	type: String 
	The entire MARC record as a string. Useful for grepping through, where
	identifying a subfield within the source JSON document becomes unwieldy.
	Grepping the entire source_records collection is obviously time consuming, but
	often the best way to answer exploratory questions. 

source_id
---------
	type: String
	A UUID assigned at creation that does what a UUID is supposed to. Used in
	Registry Records' source_record_ids field. Preferrence over MongoDb's default
	_id field is largely an accident of implementation history. Early attempts with
	the registry involved storing records in a pair tree derived from UUIDs. 

sudocs
------
	type: array of strings
	SuDocs taken from the 086, involving a somewhat convoluted process.

invalid_sudocs
--------------
	type: array of strings
	Values found in invalid 086s. This set may overlap both the sudocs and
	non_sudocs fields. There are too many invalid 086s to simply ignore. Many are
	valid SuDocs. Decision on whether to use them boils down to whether or not it
	looks like one. Perhaps rename to invalid_086?
 
non_sudocs 								             
----------
	type: array of strings
	Values found in 086s that can be identified as non-SuDocs from the MARC. 

_id
---
	type: ObjectID
	Internal identifier generated by MongoDB at time of insertion. Can be used to
	derive a creation a timestamp. 

report_numbers
--------------
  type: array of strings
  Values found in 088a. 
