_id
---
  ObjectId auto-assigned by MongoDB

added_entry_lccns
-----------------
  Collected from source records which use 700 fields with the Nauth gem. 

ancestors
---------
	type: Array of strings
	An array of registry IDs for records that have been superseded by this record,
	e.g. through merging.

author_addl_headings
--------------------
  type: Array of strings
  Collected from source records. A remnant of the VIAF processing. Could be 
  removed. Present in the Solr schema.

author_addl_normalized
----------------------
  type: Array of strings
  Collected from source records. A remnant of the VIAF processing. Could be 
  removed.

author_addl_t
-------------
  700abcdegqu:710abcdegnu:711acdegjnqu:720a:505r:245c:191abcdegqu

author_addl_viaf_ids
----------------------
  type: Array of strings
  Collected from source records. A remnant of the VIAF processing. Could be 
  removed.

author_display
--------------
  100abcdq:110abcdgnu:111acdegjnqu

author_display_facet
--------------------
  100abcdq:110abcdgnu:111acdegjnqu

author_facet
------------
  100abcdq:110abcdgnu:111acdenqu:700abcdq:710abcdgnu:711acdenqu
  Not needed. 

author_headings
---------------
  A redundancy of author_t. One of these could/should be removed. 
  100abcdgqu:110abcdgnu:111acdegjnqu

author_lccns
-----------
	type:Array of strings
	URLs for name authorities for the author.
	MARC 100 and 110
	e.g. https://lccn.loc.gov/n79086751

author_normalized
-----------------
  Collected from source records. A remnant of the VIAF processing. Could be 
  removed.

author_parts
------------
  Collected from source records and used in SourceRecord's nauth operations. 
  Not needed here and could be removed. 
  100abcdgqu:110abcdgnu:111acdegjnqu", :separator => nil

author_sort
-----------
  Traject method, marc_sortable_author

author_t
--------
  See author_headings.  
  100abcdgqu:110abcdgnu:111acdegjnqu 

author_viaf_ids
---------------
  Remnant of the VIAF processing. Could be removed. 

creation_notes
--------------
	type: String
	Why does this registry record exist? Better enum/chron parsing? HT ingest on a
	particular date?

deprecated_reason
-----------------
	type: String, null if not deprecated
	Reason for deprecation

deprecated_timestamp
--------------------
	type: DateTime, null if not deprecated
	Date and time record was deprecated

electronic_resources
--------------------
  type: array of strings
  Pulled from 856, indicators 4 or 40

electronic_versions
-------------------
  type: array of strings
  Pulled from 856, indicators 41

enumchron_display
-----------------
 	type: String, default: ""
	The enumeration/chronology for this registry record. Should not be changed;
	the record should be deprecated and replaced with a new record. todo: enforce
	immutability of the enumchron_display in the model.	

format
------
  Traject method marc_formats

gpo_item_number
---------------
  type: array of strings
  MARC 074a
  Should be gpo_item_numbers to match SourceRecord. todo:

ht_availability
---------------
  type: String, "Full View", "Limited View", "Not In HathiTrust"
  Based on miaahdl source record's 974 field. Subfield r == 'pd' maps to 'Full View'

ht_ids_fv
---------
  type: Array of strings
  Zephir ids taken from Full View miaahdl records. Could probably use a field for HathiTrust item ids as well, so we have more precise identification of what is full view vs limited view.

ht_ids_lv
---------
  type: Array of strings
  Zephir ids taken from Limited View miaahdl records. Could probably use a field for HathiTrust item ids as well, so we have more precise identification of what is full view vs limited view.

isbn_t
------
  type: Array of strings
  Collected from source records' isbn_normalized field.

issn_t
------
  type: Array of strings
  Collected from source records' issn_normalized field.

last_modified
-------------
  type: Date
  Set on save

lc_callnum_display
------------------
  type: String
  050ab

lccn_t
------
  type: Array of strings
  Collected from source records' lccn_normalized field.

material_type_display
---------------------
  type: String
  MARC field 300

oclcnum_t
---------
  type: Array of Integers
  Collected from source records' oclc_resolved field.

print_holdings_t
----------------
  type: Array of Strings
  Collected from the print holdings database using OCLC

pub_date
--------
  type: Array of Strings
  Collected from source_records' pub_date field which leverages traject's marc_publication_date
 
published_display
-----------------
  type: Array of Strings
  From the registry traject, extract_marc("260a:264|1*|abc", :trim_punctuation => true)

publisher_headings
------------------
  type: Array of Strings
  Collected from source_records' publisher_headings field, which comes from 260b

publisher_t
-----------
  type: Array of Strings
  From the registry traject, MARC 260abef:261abef:262ab:264ab

publisher_viaf_ids
------------------
  type: Array of Strings
  A remnant of the VIAF processing. Could be removed. Present in the Solr configs. 

registry_id
-----------
  type: UID
  Generated at creation. 

related_electronic_resources
----------------------------
  type: Array of Strings
  Collected from source_records. Originally from MARC 856|42|u. 

report_numbers
--------------
  type: Array of Strings
  Collected from source_Records. Orginally from MARC 088a.

series
------
  type: Array of Strings
  An array containing strings identifying the series module name responsible for
	enumeration/chronology processing. This is NOT a series title although it may be
	similar. Some are not series at all, but a collection of similar/related
	documents that can be processed together, e.g. Civil Rights Commission. This
	was originally a single string but has become an (ordered) array of strings, 
  because documents may be members of multiple series. Unlike Source Records, 
  series for Registry Records are the module names expanded with whitespace so 
  as to be a bit friendlier for human display. e.g. CivilRightsCommission vs 
  Civil Rights Commission. 


source_org_codes
----------------
	type: Array of strings
	List of contributors that have provided an associated source record for this
	registry record. MARC organization codes. 

source_record_ids
-----------------
	type: array of strings
	The list of Source Records used as evidence for this Registry Record. This
	list cannot be changed with the exception of the addition of records. Removal of
	source records requires merging/deprecation. 

subject_t
---------
  type: Array of Strings
  Collected using the registry traject.
  MARC 600:610:611:630:650:651avxyz:653aa:654abcvyz:655abcvxyz:690abcdxyz:691abxyz:692abxyz:693abxyz:656akvxyz:657avxyz:652axyz:658abcd

subject_topic_facet
-------------------
  type: Array of Strings
  Collected using the registry traject. A duplicate of subjec_t. Could likely be removed or simplified. todo
  MARC 600:610:611:630:650:651avxyz:653aa:654abcvyz:655abcvxyz:690abcdxyz:691abxyz:692abxyz:693abxyz:656akvxyz:657avxyz:652axyz:658abcd

subtitle_display
----------------
  type: Array of Strings
  Collected using the registry traject. MARC 245b, punctuation trimmed.

subtitle_t
----------
  type: Array of Strings
  Collected using the registry traject. MARC 245b, punctuation NOT trimmed.

successors
----------
  type: Array of Strings (UIDs)
  If a record is created from another record through merging or splitting, its registry_id is added to the deprecated records' successors field. 
  
sudoc_display
-------------
  type: Array of Strings
  Collected from source records. Source records have special handling of the 086. 

suppressed
----------
  type: Boolean
  Should it appear in the registry interface. Set to true when the record is deprecated.

text
----
  type: Array of Strings
  For the registry interface. Uses the registry traject, 'extract_all_marc_values'. 
  Probably should not be in the Registry, but only extracted for Solr. todo
 
title
-----
  type: Array of Strings
  Collected using the registry traject. MARC 245a

title1_t
--------
  type: Array of Strings
  Collected using the registry traject. MARC 245abk

title3_t
--------
  type: Array of Strings
  Collected using the registry traject. MARC 505r if subfield code == "t"

title_added_entry_t
-------------------
  type: Array of Strings
  Collected using the registry traject. 
  MARC 700gklmnoprst:710fgklmnopqrst:711fgklnpst:730abdefgklmnopqrst:740anp:505t:780abcrst:785abcrst:773abrst

title_addl_t
------------
  type: Array of Strings
  Collected using the registry traject. 
  MARC 245nps:130:240abcdefgklmnopqrs:210ab:222ab:242abcehnp:243abcdefgklmnopqrs:246abcdefgnp:247abcdefgnp

title_display
-------------
  type: Array of Strings
  Collected using the registry traject (245a, punctuation trimmed). 
  Normalized with Normalize.normalize_title which doesn't do much.

title_series_t
--------------
  type: Array of Strings
  Collected using the registry traject. 
  MARC 440a:490av:800abcdt:400abcd:810abcdt:410abcd:811acdeft:411acdef:830adfgklmnoprstv:760ast:762ast

title_sort
----------
  Collected using the registry traject.
  Uses marc_sortable_title. Probably should not be in the Registry, but only extracted for Solr. todo

