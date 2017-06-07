#require 'registry/source_record'
require 'dotenv'
require 'pp'

Dotenv.load
Mongoid.load!("config/mongoid.yml")
SourceRecord = Registry::SourceRecord
RegistryRecord = Registry::RegistryRecord

RSpec.describe SourceRecord do
  it "detects series" do
    sr = SourceRecord.where({oclc_resolved:1768512, org_code:{"$ne":"miaahdl"}, enum_chrons:/V. \d/}).first
    
    expect(sr.series).to eq('FederalRegister')
    sr.series = 'FederalRegister'
    #expect(sr.enum_chrons).to include('Volume: 77, Number: 96')
  end

  it "parses the enumchron if it has a series" do
    sr = SourceRecord.where({oclc_resolved:1768474}).first
    new_sr = SourceRecord.new
    new_sr.org_code = sr.org_code
    new_sr.source = sr.source.to_json
    expect(new_sr.series).to eq('StatutesAtLarge')
    expect(new_sr.enum_chrons).to include('Volume:123, Part:1')
    #puts new_sr.ec
  end

  it "performs default parsing if it doesn't have a series" do
    sr = SourceRecord.new
    sr.org_code = "miaahdl"
    sr.source = File.read(File.dirname(__FILE__)+'/data/ht_pd_record.json').chomp
    expect(sr.series).to be_nil 
    expect(sr.enum_chrons).to include('Volume:1')
  end

  it "chokes when there is '$' in MARC subfield names" do
    #Mongo doesn't like $ in field names. Occasionally, these show up when
    #MARC subfields get messed up. (GPO). This should throw an error.
    rec = File.read(File.expand_path(File.dirname(__FILE__))+'/data/dollarsign.json').chomp
    marc = MARC::Record.new_from_hash(JSON.parse(rec))
    sr = SourceRecord.new
    sr.org_code = "dgpo"
    sr.source = rec
    #expect(sr.source['fields'].select {|f| f.keys[0] == '040'}[0]['040']['subfields'].select {|sf| sf.keys[0] == 'dollarsign'}.count).to be > 0 
    expect{sr.save}.to raise_error(BSON::String::IllegalKey)
  end
end


RSpec.describe Registry::SourceRecord do
  before(:each) do
    @raw_source = "{\"leader\":\"00878cam a2200241   4500\",\"fields\":[{\"001\":\"ocm00000038 \"},{\"003\":\"OCoLC\"},{\"005\":\"20080408033517.8\"},{\"008\":\"690605s1965    dcu           000 0 eng  \"},{\"010\":{\"ind1\":\" \",\"ind2\":\" \",\"subfields\":[{\"a\":\"   65062399 \"}]}},{\"035\":{\"ind1\":\" \",\"ind2\":\" \",\"subfields\":[{\"a\":\"(OCoLC)38\"}]}},{\"040\":{\"ind1\":\" \",\"ind2\":\" \",\"subfields\":[{\"a\":\"DLC\"},{\"c\":\"DLC\"},{\"d\":\"IUL\"},{\"d\":\"BTCTA\"}]}},{\"029\":{\"ind1\":\"1\",\"ind2\":\" \",\"subfields\":[{\"a\":\"AU@\"},{\"b\":\"000024867271\"}]}},{\"050\":{\"ind1\":\"0\",\"ind2\":\"0\",\"subfields\":[{\"a\":\"KF26\"},{\"b\":\".R885 1965\"}]}},{\"082\":{\"ind1\":\"0\",\"ind2\":\"0\",\"subfields\":[{\"a\":\"507/.4/0153\"}]}},{\"086\":{\"ind1\":\"0\",\"ind2\":\" \",\"subfields\":[{\"a\":\"Y 4.R 86/2:SM 6/965\"}]}},{\"110\":{\"ind1\":\"1\",\"ind2\":\" \",\"subfields\":[{\"a\":\"United States.\"},{\"b\":\"Congress.\"},{\"b\":\"Senate.\"},{\"b\":\"Committee on Rules and Administration.\"},{\"b\":\"Subcommittee on the Smithsonian Institution.\"}]}},{\"245\":{\"ind1\":\"1\",\"ind2\":\"0\",\"subfields\":[{\"a\":\"Smithsonian Institution (National Museum act of 1965)\"},{\"b\":\"Hearing, Eighty-ninth Congress, first session, on S. 1310 and H.R. 7315 ... June 24, 1965.\"}]}},{\"260\":{\"ind1\":\" \",\"ind2\":\" \",\"subfields\":[{\"a\":\"Washington,\"},{\"b\":\"U.S. Govt. Print. Off.,\"},{\"c\":\"1965.\"}]}},{\"300\":{\"ind1\":\" \",\"ind2\":\" \",\"subfields\":[{\"a\":\"iii, 67 p.\"},{\"c\":\"23 cm.\"}]}},{\"610\":{\"ind1\":\"2\",\"ind2\":\"0\",\"subfields\":[{\"a\":\"Smithsonian Institution.\"}]}},{\"776\":{\"ind1\":\"0\",\"ind2\":\"8\",\"subfields\":[{\"i\":\"Print version:\"},{\"a\":\"United States. Congress. Senate. Committee on the Judiciary.\"},{\"t\":\"Oversight of the U.S. Department of Homeland Security\"},{\"w\":\"(OCoLC)812424058.\"}]}},{\"938\":{\"ind1\":\" \",\"ind2\":\" \",\"subfields\":[{\"a\":\"Baker and Taylor\"},{\"b\":\"BTCP\"},{\"n\":\"65062399\"}]}},{\"945\":{\"ind1\":\" \",\"ind2\":\" \",\"subfields\":[{\"a\":\"IUL\"}]}}]}"
  end

  it "sets an id on initialization" do 
    sr = SourceRecord.new
    expect(sr.source_id).to be_instance_of(String)
    expect(sr.source_id.length).to eq(36)
  end

  it "sets the publication date" do
    sr = SourceRecord.new
    sr.source = @raw_source
    expect(sr.pub_date).to eq([1965])
  end

  it "timestamps on save" do
    sr = SourceRecord.new
    sr.save 
    expect(sr.last_modified).to be_instance_of(DateTime)
  end

  it "defaults to HathiTrust org code" do
    sr = SourceRecord.new
    expect(sr.org_code).to eq("miaahdl")
    sr = SourceRecord.new( :org_code=>"tacos")
    expect(sr.org_code).to eq("tacos")
  end


  it "converts the source string to a hash" do
    sr = SourceRecord.new
    sr.source = @raw_source
    expect(sr.source).to be_instance_of(Hash)
    expect(sr.source["fields"][3]["008"]).to eq("690605s1965    dcu           000 0 eng  ")
  end

  it "extracts normalized author/publisher/corp" do
    sr = SourceRecord.new
    sr.source = @raw_source
    sr.org_code = "iul"
    sr.save
    sr_id = sr.source_id
    copy = SourceRecord.find_by(:source_id => sr_id) 
    expect(copy.author_viaf_ids).to eq([151244789])
    expect(copy.author_normalized).to eq(["UNITED STATES CONGRESS SENATE COMMITTEE ON RULES AND ADMINISTRATION SUBCOMMITTEE ON SMITHSONIAN INSTITUTION"])
    expect(copy.lccn_normalized).to eq(["65062399"])
    expect(copy.sudocs).to eq(["Y 4.R 86/2:SM 6/965"])
    expect(copy.publisher_headings).to include("U.S. Govt. Print. Off.,")
    expect(copy.author_headings).to include("United States. Congress. Senate. Committee on Rules and Administration. Subcommittee on the Smithsonian Institution.")
    expect(copy.author_parts).to include("United States.")

    sr.deprecate('rspec test')
  end

  it "extracts oclc number from 001, 035, 776" do
    sr = SourceRecord.new
    sr.source = @raw_source
    expect(sr.oclc_resolved).to eq([38, 812424058])
  end

  it "can extract local id from MARC" do
    sr = SourceRecord.new
    sr.source = @raw_source
    expect(sr.extract_local_id).to eq("ocm00000038")
  end

  it "extracts formats" do
    sr = SourceRecord.new
    sr.source = @raw_source
    expect(sr.formats).to eq(["Book","Print"])
  end

=begin
  it "won't allow duplicate local_id/org_codes" do
    sr = SourceRecord.new
    sr.org_code = "miaahdl"
    sr.source = open(File.dirname(__FILE__)+'/data/ht_record_3_items.json').read
    sr.save
    update = SourceRecord.new
    update.org_code = "miaahdl"
    
    expect{update.source = open(File.dirname(__FILE__)+'/data/ht_record_different_3_items.json').read}.to raise_error(BSON::String::IllegalKey)
  end
=end

end

RSpec.describe Registry::SourceRecord, '#extracted_field' do
  before(:all) do
    @sr = SourceRecord.new
    @sr.source = open(File.dirname(__FILE__)+"/data/dgpo_has_ecs.json").read
    @sr.save
  end

  it "extracts 856s into electronic_resources" do
    expect(@sr.electronic_versions).to include('http://purl.access.gpo.gov/GPO/LPS40802')
    expect(@sr.electronic_resources).to include('electronic resource no indicator')
    expect(@sr.electronic_resources).to include('electronic resource')
    expect(@sr.related_electronic_resources).to include('related electronic resource')
  end

  it "saves dynamically extracted fields" do
    copy = SourceRecord.find_by(source_id: @sr.source_id)
    expect(copy.electronic_versions).to include('http://purl.access.gpo.gov/GPO/LPS40802')
    expect(copy.electronic_resources).to include('electronic resource no indicator')
    expect(copy.electronic_resources).to include('electronic resource')
    expect(copy.related_electronic_resources).to include('related electronic resource')
  end

  after(:all) do
    @sr.delete
  end
end


RSpec.describe Registry::SourceRecord, "#get_lccns" do

  it "identifies authorities for author headings" do
    sr = SourceRecord.new
    sr.source = open(File.dirname(__FILE__)+"/data/whitelisted_oclc.json").read
    expect(sr.author_lccns).to include('https://lccn.loc.gov/n79086751')
  end

  it "identifies authorities for added entry names" do
    sr = SourceRecord.new
    sr.source = open(File.dirname(__FILE__)+"/data/dgpo_has_ecs.json").read
    expect(sr.added_entry_lccns).to include('https://lccn.loc.gov/n80126064')
  end
end



RSpec.describe Registry::SourceRecord, "#extract_local_id" do
  before(:all) do
    #zero filled integer
    @rec = SourceRecord.new
    @rec.org_code = "miaahdl"
    @rec.source = open(File.dirname(__FILE__)+"/data/ht_ic_record.json").read
    # has non-integer in id
    @weird = SourceRecord.new
    @weird.org_code = "miaahdl"
    @weird.source = open(File.dirname(__FILE__)+"/data/ht_weird_id.json").read
  end

  after(:all) do
    @rec.delete
    @weird.delete
  end

  it "keeps the local id as a string" do
    expect(@rec.local_id).to be_a(String)
    expect(@weird.local_id).to be_a(String)
  end

  it "removes leading zeroes if it is an integer" do
    expect(@rec.local_id).to eq("34395")
  end

  it "doesn't mess with non-integer ids" do
    expect(@weird.local_id).to eq("000034395weirdness")
  end
end


  
RSpec.describe Registry::SourceRecord, "#deprecate" do
  before(:each) do
    @rec = SourceRecord.first
  end

  after(:each) do
    @rec.unset(:deprecated_reason)
    @rec.unset(:deprecated_timestamp)
  end

  it "adds a deprecated field" do
    @rec.deprecate("testing deprecation")
    expect(@rec.deprecated_reason).to eq("testing deprecation")
  end
end

   
RSpec.describe Registry::SourceRecord, "#add_to_registry" do
  # in theory none of this works if .delete_enumchron and .add_enumchron
  # don't work. 
  # todo: test separately
  before(:all) do
    @old_rec = SourceRecord.new
    @old_rec.org_code = "miaahdl"
    @old_rec.source = open(File.dirname(__FILE__)+'/data/ht_record_3_items.json').read
    @old_rec.save
    @old_ecs = @old_rec.enum_chrons

    @no_ec_rec = SourceRecord.new
    @no_ec_rec.org_code = "miaahdl"
    @no_ec_rec.source = open(File.dirname(__FILE__)+'/data/ht_record_0_items.json').read
    @no_ec_rec.save
    
    @repl_rec = @old_rec
    @repl_rec.org_code = "miaahdl"
    @repl_rec.source = open(File.dirname(__FILE__)+'/data/ht_record_different_3_items.json').read
    @repl_rec.save

    @new_rec = SourceRecord.new
    @new_rec.org_code = "miaahdl"
    @new_rec.source = open(File.dirname(__FILE__)+'/data/ht_record_3_items.json').read
    @new_rec.local_id = (@old_rec.local_id.to_i + 1).to_s # just make sure we aren't clobbering
    @new_rec.save
  end

  after(:all) do
    RegistryRecord.where(:source_record_ids.in => [@old_rec.source_id,
                                                   @repl_rec.source_id,
                                                   @new_rec.source_id,
                                                   @no_ec_rec.source_id]).each {|r| r.delete}
    @old_rec.delete
    @repl_rec.delete
    @new_rec.delete
    @no_ec_rec.delete
  end

  it "SRs with no ECs still get added to Register" do
    results = @no_ec_rec.add_to_registry
    expect(results[:num_new]).to eq(1)
    expect(results[:num_deleted]).to eq(0)
    num_in_reg = RegistryRecord.where(source_record_ids:@no_ec_rec.source_id,
                                deprecated_timestamp:{"$exists":0}).count
    expect(num_in_reg).to be > 0

  end

  it "deprecates old enum_chrons" do 
    deleted_ecs = @old_ecs - @repl_rec.enum_chrons
    expect(deleted_ecs.count).to be > 0
    @repl_rec.update_in_registry
    deleted_ecs.each do | ec | 
      expect(RegistryRecord.where(source_record_ids:@old_rec.source_id,
                            enumchron_display:ec,
                            deprecated_timestamp:{"$exists":0}).count).to eq(0)
    end
  end

  it "adds new enum_chrons" do
    new_ecs = @repl_rec.enum_chrons - @old_ecs
    expect(new_ecs.count).to be > 0
    @repl_rec.update_in_registry
    expect(@repl_rec.source_id).to eq(@old_rec.source_id)
    new_ecs.each do | ec |
      expect(RegistryRecord.where(source_record_ids:@old_rec.source_id,
                            enumchron_display:ec,
                            deprecated_timestamp:{"$exists":0}).count).to eq(1)
    end
  end

  it "update_in_registry doesn't do anything if nothing has changed" do 
    orig_count = RegistryRecord.where(source_record_ids:@repl_rec.source_id).count
    results = @repl_rec.update_in_registry
    new_count = RegistryRecord.where(source_record_ids:@repl_rec.source_id).count
    expect(orig_count).to eq(new_count)
    expect(results[:num_new]).to eq(0)
    expect(results[:num_deleted]).to eq(0)
  end

  it "adds new enum_chrons for new records" do
    results = @new_rec.add_to_registry
    @new_rec.enum_chrons.each do |ec|
      expect(RegistryRecord.where(source_record_ids:@new_rec.source_id,
                            enumchron_display:ec,
                            deprecated_timestamp:{"$exists":0}).count).to eq(1)
    end
    expect(results[:num_new]).to eq(3)
  end

end

RSpec.describe Registry::SourceRecord, "#remove_from_registry" do
  before(:all) do
    @src_rec = SourceRecord.new
    @src_rec.org_code = "miaahdl"
    @src_rec.source = open(File.dirname(__FILE__)+'/data/ht_record_3_items.json').read
    @src_rec.save
    @src_rec.add_to_registry "testing removal"
    @second_src_rec = SourceRecord.new
    @second_src_rec.org_code = "miaahdl"
    @second_src_rec.source = open(File.dirname(__FILE__)+'/data/ht_record_3_items.json').read
    @second_src_rec.local_id = (@second_src_rec.local_id.to_i + 1).to_s
    @second_src_rec.save
    @second_src_rec.add_to_registry "testing removal"
  end

  after(:all) do
    RegistryRecord.where(source_record_ids:@src_rec.source_id).each { |r| r.delete }
    RegistryRecord.where(source_record_ids:@second_src_rec.source_id).each { |r| r.delete }
    @src_rec.delete
    @second_src_rec.delete
  end

  it "deprecates registry records it was a member of" do 
    expect(RegistryRecord.where(source_record_ids:[@src_rec.source_id,
                                                   @second_src_rec.source_id],
                                deprecated_timestamp:{"$exists":0}).count).to eq(3)
    num_removed = @src_rec.remove_from_registry
    expect(num_removed).to eq(3)
    expect(RegistryRecord.where(source_record_ids:[@src_rec.source_id,
                                                   @second_src_rec.source_id],
                                deprecated_timestamp:{"$exists":0}).count).to eq(0)
    expect(RegistryRecord.where(source_record_ids:[@src_rec.source_id],
                                deprecated_timestamp:{"$exists":0}).count).to eq(0)
    expect(RegistryRecord.where(source_record_ids:[@second_src_rec.source_id],
                                deprecated_timestamp:{"$exists":0}).count).to eq(3)
  end
    
end

RSpec.describe Registry::SourceRecord, '#ht_availability' do 
  before(:all) do
    @non_ht_rec = SourceRecord.where(:org_code.ne => "miaahdl").first
    @ht_pd = SourceRecord.new
    @ht_pd.org_code = "miaahdl"
    @ht_pd.source = open(File.dirname(__FILE__)+"/data/ht_pd_record.json").read
    @ht_ic = SourceRecord.new
    @ht_ic.org_code = "miaahdl"
    @ht_ic.source = open(File.dirname(__FILE__)+"/data/ht_ic_record.json").read
  end

  it "detects correct HT availability" do
    expect(@non_ht_rec.ht_availability).to eq(nil)
    expect(@ht_pd.ht_availability).to eq("Full View")
    expect(@ht_ic.ht_availability).to eq("Limited View")
  end
end

RSpec.describe Registry::SourceRecord, 'extract_oclcs' do
  before(:all) do
    rec = File.read(File.expand_path(File.dirname(__FILE__))+'/data/bogus_oclc.json').chomp
    @marc = MARC::Record.new_from_hash(JSON.parse(rec))
    @s = SourceRecord.new
  end

  it "ignores out of range OCLCs" do
    expect(@s.extract_oclcs(@marc)).not_to include(155503032044020955233)
  end
end

RSpec.describe Registry::SourceRecord, 'extract_sudocs' do
  before(:all) do
    bogus = File.read(File.expand_path(File.dirname(__FILE__))+'/data/bogus_sudoc.json').chomp
    @marc_bogus = MARC::Record.new_from_hash(JSON.parse(bogus))
    legit = File.read(File.expand_path(File.dirname(__FILE__))+'/data/legit_sudoc.json').chomp
    @marc_legit = MARC::Record.new_from_hash(JSON.parse(legit))
    non = File.read(File.expand_path(File.dirname(__FILE__))+'/data/non_sudoc.json').chomp
    @marc_non = MARC::Record.new_from_hash(JSON.parse(non))
    fed_state = File.read(File.expand_path(File.dirname(__FILE__))+'/data/fed_state_sudoc.json').chomp
    @marc_fs = MARC::Record.new_from_hash(JSON.parse(fed_state))
    mangled = File.read(File.expand_path(File.dirname(__FILE__))+'/data/ht_pd_record.json').chomp
    @marc_mang = MARC::Record.new_from_hash(JSON.parse(mangled))
  end

  #not much we can do about it
  it "accepts bogus SuDocs" do
    s = SourceRecord.new 
    expect(s.extract_sudocs(@marc_bogus)).to eq(["XCPM 2.2:P 51 C 55/D/990"])
  end

  it "extracts good ones" do
    s = SourceRecord.new
    expect(s.extract_sudocs(@marc_legit)).to eq(["L 37.22/2:97-B"])
    expect(s.extract_sudocs(@marc_fs)).to eq(["I 19.79:EC 7/OK/2005"])
  end

  it "ignores Illinois docs" do
    s = SourceRecord.new
    ildoc = open(File.dirname(__FILE__)+"/data/il_doc.json").read
    ilmarc = MARC::Record.new_from_hash(JSON.parse(ildoc))
    expect(s.extract_sudocs(ilmarc)).not_to include('IL/DNR 52.9:')
    s.source = ildoc
    expect(s.is_govdoc).to eq(false)
  end

  it "ignores non-SuDocs, uses non-SuDocs to filter out bogus" do
    s = SourceRecord.new
    s.extract_sudocs(@marc_non)
    #has identified the bogus ones
    expect(s.non_sudocs).to include('XCPM 2.2:P 51 C 55/D/990')
    #uses non-Sudocs to filter out bogus
    expect(s.sudocs).to eq([])
    expect(s.invalid_sudocs).to include('XCPM 2.2:P 51 C 55/D/990')

    s.extract_sudocs(@marc_fs)
    expect(s.non_sudocs).to include('W 1700.9 E 19 2005')
    expect(s.invalid_sudocs).to include('W 1700.9 E 19 2005')
  end

  it "fixes mangled sudocs" do
    #e.g. "II0 aC 13.44:137"
    s = SourceRecord.new
    sudocs = s.extract_sudocs(@marc_mang)
    expect(s.sudocs).not_to include("II0 aC 13.44:137")
    expect(s.sudocs).to include("C 13.44:137")
  end

end

RSpec.describe Registry::SourceRecord, 'is_govdoc' do
  before(:all) do
    #this file has both a Fed SuDoc and a state okdoc
    @fed_state = File.read(File.expand_path(File.dirname(__FILE__))+'/data/fed_state_sudoc.json').chomp
    @marc = MARC::Record.new_from_hash(JSON.parse(@fed_state))
    @innd = File.read(File.expand_path(File.dirname(__FILE__))+'/data/innd_record.json').chomp
    @innd_marc = MARC::Record.new_from_hash(JSON.parse(@innd))

  end

  it "detects govdociness" do
    s = SourceRecord.new
    s.source = @fed_state
    expect(s.extract_sudocs(@marc).count).to be(1)
    expect(s.is_govdoc(@marc)).to be_truthy

    s = SourceRecord.new
    s.source = @innd
    expect(s.is_govdoc).to be_truthy
    expect(s.is_govdoc(@innd_marc)).to be_truthy
  end

  it "leverages OCLC blacklist" do
    bad_oclc = File.read(File.expand_path(File.dirname(__FILE__))+'/data/blacklisted_oclc.json').chomp
    s = SourceRecord.new
    s.source = bad_oclc
    expect(s.is_govdoc).to be false
  end

  it "uses OCLC whitelist" do
    good_oclc = File.read(File.expand_path(File.dirname(__FILE__))+'/data/whitelisted_oclc.json').chomp
    s = SourceRecord.new
    s.source = good_oclc
    expect(s.is_govdoc).to be true
  end

  it "uses the 074" do
    source = open(File.dirname(__FILE__)+'/data/074_govdoc.json').read
    s = SourceRecord.new
    s.source = source
    expect(s.gpo_item_numbers).to eq(['123'])
    expect(s.is_govdoc).to be true
  end

  it "doesn't choke if there is no 074" do
    source = open(File.dirname(__FILE__)+'/data/no_074_nongovdoc.json').read
    s = SourceRecord.new
    s.source = source
    expect(s.gpo_item_numbers).to eq([])
    expect(s.is_govdoc).to be false
  end

end

  
RSpec.describe Registry::SourceRecord, '#extract_identifiers' do
  before(:all) do
    SourceRecord.where(:source.exists => false).delete
  end
      
  it "doesn't change identifiers" do
    count = 0
    SourceRecord.all.each do |rec|
      count += 1
      if count > 200 #arbitrary
        break
      end
      old_oclc_alleged = rec.oclc_alleged
      old_lccn = rec.lccn_normalized
      old_sudocs = rec.sudocs
      old_issn = rec.issn_normalized
      old_isbn = rec.isbns_normalized
      rec.extract_identifiers
      expect(old_oclc_alleged - rec.oclc_alleged).to eq([])
      expect(old_lccn - rec.lccn_normalized ).to eq([])
      #expect(old_sudocs - rec.sudocs ).to eq([])
      if old_sudocs != rec.sudocs
        #PP.pp rec.source_id
        #PP.pp rec.sudocs
        #PP.pp old_sudocs
      end
      expect(old_issn - rec.issn_normalized ).to eq([])
      expect(old_isbn - rec.isbns_normalized ).to eq([])
    end
  end
end

RSpec.describe Registry::SourceRecord, '#marc_profiles' do
  it "loads marc profiles" do
    expect(SourceRecord.marc_profiles['dgpo']).to be_truthy
    expect(SourceRecord.marc_profiles['dgpo']['enum_chrons']).to eq('930 h')
  end
end


RSpec.describe Registry::SourceRecord, '#extract_enum_chrons' do
  it "extracts enum chrons from GPO records" do
    line = '{"leader":"01656cam  2200373 i 4500","fields":[{"001":"000001290"},{"003":"CaOONL"},{"005":"20041121202944.0"},{"008":"760308s1975    dcu          f000 0 eng d"},{"010":{"ind1":" ","ind2":" ","subfields":[{"a":"75603638"}]}},{"020":{"ind1":" ","ind2":" ","subfields":[{"b":"pbk. :"},{"c":"$0.95"}]}},{"035":{"ind1":"9","ind2":" ","subfields":[{"a":"gp^76001290"}]}},{"035":{"ind1":" ","ind2":" ","subfields":[{"a":"(OCoLC)2036279"}]}},{"040":{"ind1":" ","ind2":" ","subfields":[{"a":"GPO"},{"c":"GPO"}]}},{"086":{"ind1":" ","ind2":" ","subfields":[{"a":"Y 4.Sci 2:94-1/M/v.1"}]}},{"099":{"ind1":" ","ind2":" ","subfields":[{"a":"Y 4.Sci 2:94-1/M/v.1"}]}},{"110":{"ind1":"1","ind2":" ","subfields":[{"a":"United States."},{"b":"Congress."},{"b":"House."},{"b":"Committee on Science and Technology."},{"b":"Subcommittee on Space Science and Applications."}]}},{"245":{"ind1":"1","ind2":"0","subfields":[{"a":"Future space programs 1975 :"},{"b":"report of the Subcommittee on Space Science and Applications prepared for the Committee on Science and Technology, U.S. House of Representatives, Ninety-fourth Congress, first session, September 1975."}]}},{"260":{"ind1":" ","ind2":" ","subfields":[{"a":"Washington :"},{"b":"U.S Govt. Print. Off.,"},{"c":"1975."}]}},{"300":{"ind1":" ","ind2":" ","subfields":[{"a":"v. ;"},{"c":"24 cm."}]}},{"490":{"ind1":"1","ind2":" ","subfields":[{"a":"Serial no. 94-M"}]}},{"500":{"ind1":" ","ind2":" ","subfields":[{"a":"Item 1025-A"}]}},{"500":{"ind1":" ","ind2":" ","subfields":[{"a":"S/N 052-070-02890-4"}]}},{"505":{"ind1":"0","ind2":" ","subfields":[{"a":"v. 1."}]}},{"590":{"ind1":" ","ind2":" ","subfields":[{"a":"[18 cds/"}]}},{"650":{"ind1":" ","ind2":"0","subfields":[{"a":"Space flight."}]}},{"710":{"ind1":"1","ind2":" ","subfields":[{"a":"United States."},{"b":"National Aeronautics and Space Administration."}]}},{"810":{"ind1":"1","ind2":" ","subfields":[{"a":"United States."},{"b":"Congress."},{"b":"House."},{"b":"Committee on Science and Technology."},{"t":"[Committee publication] serial, 94th Congress ;"},{"v":"no. 94-M."}]}},{"956":{"ind1":" ","ind2":" ","subfields":[{"a":"CONV"},{"b":"20"},{"c":"20050210"},{"l":"GPO01"},{"h":"1741"}]}},{"956":{"ind1":" ","ind2":" ","subfields":[{"c":"20060112"},{"l":"GPO01"},{"h":"1700"}]}},{"956":{"ind1":" ","ind2":" ","subfields":[{"c":"20060224"},{"l":"GPO01"},{"h":"1343"}]}},{"956":{"ind1":" ","ind2":" ","subfields":[{"c":"20150504"},{"l":"GPO01"},{"h":"2007"}]}},{"930":{"ind1":"-","ind2":"1","subfields":[{"l":"GPO01"},{"L":"GPO01"},{"m":"BOOK"},{"1":"NABIB"},{"A":"National Bibliography"},{"h":"Y 4.SCI 2:94-1/M/"},{"5":"1290-10"},{"8":"20101112"},{"f":"01"},{"F":"For Distribution"},{"h":"V.1"}]}},{"930":{"ind1":"-","ind2":"1","subfields":[{"l":"GPO01"},{"L":"GPO01"},{"m":"BOOK"},{"1":"NABIB"},{"A":"National Bibliography"},{"h":"Y 4.SCI 2:94-1/M/"},{"5":"1290-20"},{"8":"20101112"},{"f":"02"},{"F":"Not Distributed"},{"h":"V.2"}]}}]}'

    src = SourceRecord.new
    src.org_code = 'dgpo'
    src.source = line
    expect(src.extract_enum_chrons.collect {|k,ec| ec['string']}).to eq(["V. 1", "V. 2"])
  end
  
  it "extracts enum chrons from non-GPO records" do
    sr = SourceRecord.where({oclc_resolved:1768512, org_code:{"$ne":"miaahdl"}, enum_chrons:/V. \d/}).first
    line = sr.source.to_json
    sr_new = SourceRecord.new( :org_code=>"miu" )
    sr_new.series = 'FederalRegister'
    sr_new.source = line
    expect(sr_new.series).to eq('FederalRegister')
    expect(sr_new.enum_chrons).to include("Volume:77, Number:67")
    expect(sr_new.org_code).to eq("miu")
  end

  it 'properly extracts enumchrons for series' do
    sr = SourceRecord.new
    sr.org_code = "miaahdl"
    sr.source = open(File.dirname(__FILE__)+'/series/data/econreport.json').read
    expect(sr.series).to eq('EconomicReportOfThePresident')
    expect(sr.enum_chrons).to include('Year:1966, Part:3')
  end

  it 'doesnt clobber enumchron features' do
    sr = SourceRecord.new
    sr.org_code = "miaahdl"
    sr.source = open(File.dirname(__FILE__)+'/series/data/statabstract_multiple_ecs.json').read
    expect(sr.enum_chrons).to include('Edition:1, Year:1878')
  end

  it 'returns [""] for records without enum_chrons, with series' do
    sr = SourceRecord.new
    sr.org_code = "miaahdl"
    sr.source = open(File.dirname(__FILE__)+'/series/data/econreport_no_enums.json').read
    expect(sr.enum_chrons.count).to eq(1)
    expect(sr.enum_chrons[0]).to eq("")
  end

  it 'returns [""] for records without enum_chrons, without series' do
    sr = SourceRecord.new
    sr.org_code = "miaahdl"
    sr.source = open(File.dirname(__FILE__)+'/data/no_enums_no_series_src.json').read
    expect(sr.enum_chrons.count).to eq(1)
    expect(sr.enum_chrons[0]).to eq("")
  end

=begin
  it "hasn't changed since last extraction" do
    SourceRecord.where(deprecated_timestamp:{"$exists":0}).no_timeout.each do |src|
      if src.enum_chrons.include? 'INDEX:V. 58-59 YR. 1993-1994'
        src.source = src.source.to_json
        src.save
      end
      old_enum_chrons = src.enum_chrons
      src.source = src.source.to_json
      expect(old_enum_chrons).to eq(src.enum_chrons)
    end
  end
=end
end

RSpec.describe Registry::SourceRecord, '#extract_enum_chron_strings' do
  it 'extracts enum chron strings from MARC records' do
    sr = SourceRecord.where({sudocs:"II0 aLC 4.7:T 12/v.1-6"}).first
    expect(sr.extract_enum_chron_strings).to include('V. 6')
  end

  it 'ignores contributors without enum chrons' do
    sr = SourceRecord.where({sudocs:"Y 4.P 84/11:AG 8", org_code:"cic"}).first
    expect(sr.extract_enum_chron_strings).to eq([])
  end

  it 'properly extracts enumchron strings for series' do
    sr = SourceRecord.new
    sr.org_code = "miaahdl"
    sr.source = open(File.dirname(__FILE__)+'/series/data/econreport.json').read
    expect(sr.extract_enum_chron_strings).to include('PT. 1-4')
  end

  it 'handles DGPO records appropriately' do
    sr = SourceRecord.new
    sr.org_code = "dgpo"
    sr.source = open(File.dirname(__FILE__)+'/data/dgpo_has_ecs.json').read
    expect(sr.extract_enum_chron_strings).to include('V. 31:NO. 3(2004:JULY)')
  end

  it "filters out some bogus enum chrons" do
    sr = SourceRecord.new
    sr.org_code = "vifgm"
    sr.source = open(File.dirname(__FILE__)+'/data/vifgm_1959_december.json').read
    expect(sr.extract_enum_chron_strings).to eq([])
  end
end


RSpec.describe Registry::SourceRecord, '#extract_holdings' do
  before(:all) do
    @src = SourceRecord.where(org_code:"miaahdl").first
    @src.extract_holdings
  end
  
  it 'transforms 974s into a holdings field' do
    v4_dig = Digest::SHA256.hexdigest('V. 4')
    v5_dig = Digest::SHA256.hexdigest('V. 5')
    expect(@src.holdings.keys).to include(v4_dig)
    expect(@src.holdings[v5_dig].count).to be(1)
    expect(@src.holdings[v5_dig][0][:u]).to eq('mdp.39015034759749')
    expect(@src.ht_item_ids).to include('mdp.39015034759749')
  end
end

RSpec.describe Registry::SourceRecord, '#is_monograph' do
 
  it 'identifies a monograph' do
    src = SourceRecord.new
    src.source = open(File.dirname(__FILE__)+'/data/no_enums_no_series_src.json').read
    expect(src.is_monograph?).to be_truthy
  end

  it 'identifies a non-monograph' do
    src = SourceRecord.new
    src.source = open(File.dirname(__FILE__)+'/series/data/statabstract_multiple_ecs.json').read
    expect(src.is_monograph?).to be_falsey
  end
end

describe Registry::SourceRecord, 'source' do
  before(:each) do
    @src = SourceRecord.new
    @src.source = open(File.dirname(__FILE__)+'/series/data/usreport.json').read
  end

  it 'properly extracts US Reports' do
    expect(@src.enum_chrons.count).to be > 20
  end

  it 'saves the series information' do
    expect(@src.series).to eq('UnitedStatesReports')
    @src.save
    diffsrc = SourceRecord.where(source_id:@src.source_id).first
    expect(diffsrc.attributes[:series]).to eq('UnitedStatesReports')
  end

  after(:each) do
    @src.delete
  end
end

RSpec.describe Registry::SourceRecord, '#parse_ec' do
  before(:all) do
    @src = SourceRecord.new
  end

  xit "can parse them all" do 
    matches = 0
    misses = 0
    input = File.dirname(__FILE__)+'/data/mono_enum_chrons.tsv'
    open(input, 'r').each do |line|
      ec_count, ec_string = line.chomp.split(/\t/)

      ec = @src.parse_ec(ec_string)
      if ec.nil? or ec.length == 0
        misses += ec_count.to_i
        puts "no match: "+line
      else
        if !ec['description'].nil?
          #puts SourceRecord.normalize_description(ec['description'])
        end
        res = @src.explode(ec)
        res.each do | canon, features |
          #puts canon
        end
        matches += ec_count.to_i
      end
    end
    puts "Default Mono Parsing Record match: #{matches}"
    puts "Default Mono Parsing Record no match: #{misses}"
    expect(matches).to eq(matches+misses)
  end

  #Volume
  it "can parse volumes" do
    expect(@src.parse_ec('V. 1')['volume']).to eq('1')
    expect(@src.parse_ec('V.1')['volume']).to eq('1')
    expect(@src.parse_ec('V1')['volume']).to eq('1')
    expect(@src.parse_ec('V 1')['volume']).to eq('1')
    expect(@src.parse_ec('V. 001')['volume']).to eq('1')
    # this is too ambitious for us right now
    expect(@src.parse_ec('1')['volume']).to eq('1')
    expect(@src.parse_ec('001')['volume']).to eq('1')
    expect(@src.parse_ec('Volume:1')['volume']).to eq('1')
    expect(@src.parse_ec('0')).to be_nil
  end

  it "can't parse things that only look like volumes" do
    expect(@src.parse_ec('NOV. 1')).to be_nil
  end

  #Number
  it "can parse numbers" do
    expect(@src.parse_ec('NO. 1')['number']).to eq('1')
    expect(@src.parse_ec('NO.1')['number']).to eq('1')
    expect(@src.parse_ec('NO1')['number']).to eq('1')
    expect(@src.parse_ec('NO 1')['number']).to eq('1')
    expect(@src.parse_ec('NO. 001')['number']).to eq('1')
    expect(@src.parse_ec('NO001')['number']).to eq('1')
    expect(@src.parse_ec('Number:1')['number']).to eq('1')
  end

  it "can't parse things that only look like numbers" do
    expect(@src.parse_ec('NOTANO1')).to be_nil
  end

  #Part
  it "can parse parts" do
    expect(@src.parse_ec('PT. 1')['part']).to eq('1')
    expect(@src.parse_ec('PT.1')['part']).to eq('1')
    expect(@src.parse_ec('PT1')['part']).to eq('1')
    expect(@src.parse_ec('PT 1')['part']).to eq('1')
    expect(@src.parse_ec('PT. 001')['part']).to eq('1')
    expect(@src.parse_ec('PT001')['part']).to eq('1')
    expect(@src.parse_ec('Part:1')['part']).to eq('1')
  end

  it "can't parse things that only look like part" do
    expect(@src.parse_ec('NOTAPT')).to be_nil
  end

  #Year
  it "can parse years" do
    expect(@src.parse_ec('983')['year']).to eq('1983')
    expect(@src.parse_ec('1983')['year']).to eq('1983')
    expect(@src.parse_ec('Year:1983')['year']).to eq('1983')
  end

  it "can't parse things that only look like a year" do
    expect(@src.parse_ec('NOTAYEAR: 1983')).to be_nil
    expect(@src.parse_ec('0704')).to be_nil
    expect(@src.parse_ec('2573')).to be_nil
    expect(@src.parse_ec('1600')).to be_nil
    expect(@src.parse_ec('2573')).to be_nil
  end

  #Book
  it "can parse books" do
    expect(@src.parse_ec('BK. 4')['book']).to eq('4')
    expect(@src.parse_ec('BOOK 4')['book']).to eq('4')
    expect(@src.parse_ec('Book:4')['book']).to eq('4')
  end

  #Sheet
  it "can parse sheets" do
    expect(@src.parse_ec('SHEET. 4')['sheet']).to eq('4')
    expect(@src.parse_ec('SHEET 4')['sheet']).to eq('4')
    expect(@src.parse_ec('Sheet:4')['sheet']).to eq('4')
  end

  #Year:, Part: 
  it "can parse Year:<y>, Part:<p>" do
    expect(@src.parse_ec('Year:2001, Part:2')['part']).to eq('2')
  end

  #Volume/Year
  it "can parse Volume/Year: 'V. 3(1974)'" do
    expect(@src.parse_ec('V. 3(1974)')['year']).to eq('1974')
    expect(@src.parse_ec('Year:1974, Volume:3')['year']).to eq('1974')
  end

  #Volume/Number
  it "can parse Volume/Number: 'V. 3, NO. 2'" do
    expect(@src.parse_ec('V. 3, NO. 2')['number']).to eq('2')
  end

  after(:all) do
    @src.delete
  end
end

RSpec.describe Registry::SourceRecord, '#explode' do
  it "does nothing" do 
    parsed = SourceRecord.new.parse_ec('1978')
    #PP.pp parsed
    #PP.pp SourceRecord.new.explode(parsed)
    #PP.pp SourceRecord.new.canonicalize(parsed)
    expect(SourceRecord.new.explode(parsed).count).to eq(1)
  end
end

RSpec.describe Registry::SourceRecord, '#canonicalize' do
  it "returns nil if ec can't be parsed" do
    expect(SourceRecord.new.canonicalize({})).to be_nil
  end

  # Year:<year>, Volume:<volume>, Part:<part>, Number:<number>
  it "turns a parsed ec into a canonical string" do
    ec = {'number'=>'2',
          'volume'=>'3',
          'year'=>'1956'}    
    expect(SourceRecord.new.canonicalize(ec)).to eq('Year:1956, Volume:3, Number:2')
  end
end

RSpec.describe Registry::SourceRecord, '#fix_flasus' do
  it "fixes the 955 for flasus" do 
    source = open(File.dirname(__FILE__)+'/data/flasus_rec.json').read
    expect(source).to match(/"955"\s?:.*"v\.1"\s?:\s?""/)
    src = SourceRecord.new
    fixed = src.fix_flasus("flasus", JSON.parse(source))
    expect(fixed.to_json).to match(/"955"\s?:.*"v"\s?:\s?"v\.1"/)

    # should be called in source= 
    src.org_code = "flasus"
    src.source = source
    expect(src.enum_chrons).to include("Volume:1")
  end 

  it "fixes all fields for flasus" do
    source = open(File.dirname(__FILE__)+'/data/flasus_garbage.json').read
    src = SourceRecord.new
    fixed = src.fix_flasus("flasus", JSON.parse(source))
    expect(fixed.to_json).to match(/"dollar":/)
  end
end


