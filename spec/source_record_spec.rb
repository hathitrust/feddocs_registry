require 'source_record'
require 'dotenv'
require 'pp'

Dotenv.load
Mongoid.load!("config/mongoid.yml")

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
end


RSpec.describe SourceRecord do
  before(:each) do
    @raw_source = "{\"leader\":\"00878cam a2200241   4500\",\"fields\":[{\"001\":\"ocm00000038 \"},{\"003\":\"OCoLC\"},{\"005\":\"20080408033517.8\"},{\"008\":\"690605s1965    dcu           000 0 eng  \"},{\"010\":{\"ind1\":\" \",\"ind2\":\" \",\"subfields\":[{\"a\":\"   65062399 \"}]}},{\"035\":{\"ind1\":\" \",\"ind2\":\" \",\"subfields\":[{\"a\":\"(OCoLC)38\"}]}},{\"040\":{\"ind1\":\" \",\"ind2\":\" \",\"subfields\":[{\"a\":\"DLC\"},{\"c\":\"DLC\"},{\"d\":\"IUL\"},{\"d\":\"BTCTA\"}]}},{\"029\":{\"ind1\":\"1\",\"ind2\":\" \",\"subfields\":[{\"a\":\"AU@\"},{\"b\":\"000024867271\"}]}},{\"050\":{\"ind1\":\"0\",\"ind2\":\"0\",\"subfields\":[{\"a\":\"KF26\"},{\"b\":\".R885 1965\"}]}},{\"082\":{\"ind1\":\"0\",\"ind2\":\"0\",\"subfields\":[{\"a\":\"507/.4/0153\"}]}},{\"086\":{\"ind1\":\"0\",\"ind2\":\" \",\"subfields\":[{\"a\":\"Y 4.R 86/2:SM 6/965\"}]}},{\"110\":{\"ind1\":\"1\",\"ind2\":\" \",\"subfields\":[{\"a\":\"United States.\"},{\"b\":\"Congress.\"},{\"b\":\"Senate.\"},{\"b\":\"Committee on Rules and Administration.\"},{\"b\":\"Subcommittee on the Smithsonian Institution.\"}]}},{\"245\":{\"ind1\":\"1\",\"ind2\":\"0\",\"subfields\":[{\"a\":\"Smithsonian Institution (National Museum act of 1965)\"},{\"b\":\"Hearing, Eighty-ninth Congress, first session, on S. 1310 and H.R. 7315 ... June 24, 1965.\"}]}},{\"260\":{\"ind1\":\" \",\"ind2\":\" \",\"subfields\":[{\"a\":\"Washington,\"},{\"b\":\"U.S. Govt. Print. Off.,\"},{\"c\":\"1965.\"}]}},{\"300\":{\"ind1\":\" \",\"ind2\":\" \",\"subfields\":[{\"a\":\"iii, 67 p.\"},{\"c\":\"23 cm.\"}]}},{\"610\":{\"ind1\":\"2\",\"ind2\":\"0\",\"subfields\":[{\"a\":\"Smithsonian Institution.\"}]}},{\"776\":{\"ind1\":\"0\",\"ind2\":\"8\",\"subfields\":[{\"i\":\"Print version:\"},{\"a\":\"United States. Congress. Senate. Committee on the Judiciary.\"},{\"t\":\"Oversight of the U.S. Department of Homeland Security\"},{\"w\":\"(OCoLC)812424058.\"}]}},{\"938\":{\"ind1\":\" \",\"ind2\":\" \",\"subfields\":[{\"a\":\"Baker and Taylor\"},{\"b\":\"BTCP\"},{\"n\":\"65062399\"}]}},{\"945\":{\"ind1\":\" \",\"ind2\":\" \",\"subfields\":[{\"a\":\"IUL\"}]}}]}"
  end

  it "sets an id on initialization" do 
    sr = SourceRecord.new
    expect(sr.source_id).to be_instance_of(String)
    expect(sr.source_id.length).to eq(36)
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

end

RSpec.describe SourceRecord, "#deprecate" do
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

RSpec.describe SourceRecord, '#ht_availability' do 
  before(:all) do
    @non_ht_rec = SourceRecord.where(:org_code.ne => "miaahdl").first
    @ht_pd = SourceRecord.where(:org_code => "miaahdl", 
                                :source_blob => /.r.:.pd./).first
    @ht_ic = SourceRecord.where(:org_code => "miaahdl", 
                                :source_blob => /.r.:.ic./).first
  end

  it "detects correct HT availability" do
    expect(@non_ht_rec.ht_availability).to eq(nil)
    expect(@ht_pd.ht_availability).to eq("Full View")
    expect(@ht_ic.ht_availability).to eq("Limited View")
  end
end

RSpec.describe SourceRecord, 'extract_oclcs' do
  before(:all) do
    rec = File.read(File.expand_path(File.dirname(__FILE__))+'/data/bogus_oclc.json').chomp
    @marc = MARC::Record.new_from_hash(JSON.parse(rec))
    @s = SourceRecord.new
  end

  it "ignores out of range OCLCs" do
    expect(@s.extract_oclcs(@marc)).not_to include(155503032044020955233)
  end
end
  
RSpec.describe SourceRecord, '#extract_identifiers' do
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
        PP.pp rec.source_id
        PP.pp rec.sudocs
        PP.pp old_sudocs
      end
      expect(old_issn - rec.issn_normalized ).to eq([])
      expect(old_isbn - rec.isbns_normalized ).to eq([])
    end
  end
end

RSpec.describe SourceRecord, '#marc_profiles' do
  it "loads marc profiles" do
    expect(SourceRecord.marc_profiles['dgpo']).to be_truthy
    expect(SourceRecord.marc_profiles['dgpo']['enum_chrons']).to eq('930 h')
  end
end


RSpec.describe SourceRecord, '#extract_enum_chrons' do
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
    expect(sr_new.enum_chrons).to include("Volume:77, Number:67")
  end
end

RSpec.describe SourceRecord, '#extract_enum_chron_strings' do
  it 'extracts enum chron strings from MARC records' do
    sr = SourceRecord.where({sudocs:"II0 aLC 4.7:T 12/v.1-6"}).first
    expect(sr.extract_enum_chron_strings).to include('V. 6')
  end

  it 'ignores contributors without enum chrons' do
    sr = SourceRecord.where({sudocs:"Y 4.P 84/11:AG 8", org_code:"cic"}).first
    expect(sr.extract_enum_chron_strings).to eq([])
  end

end

