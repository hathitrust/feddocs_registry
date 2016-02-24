require 'source_record'
require 'dotenv'

Dotenv.load
Mongoid.load!("config/mongoid.yml")

RSpec.describe SourceRecord do
  before(:each) do
    @raw_source = "{\"leader\":\"00878cam a2200241   4500\",\"fields\":[{\"001\":\"ocm00000038 \"},{\"003\":\"OCoLC\"},{\"005\":\"20080408033517.8\"},{\"008\":\"690605s1965    dcu           000 0 eng  \"},{\"010\":{\"ind1\":\" \",\"ind2\":\" \",\"subfields\":[{\"a\":\"   65062399 \"}]}},{\"035\":{\"ind1\":\" \",\"ind2\":\" \",\"subfields\":[{\"a\":\"(OCoLC)38\"}]}},{\"040\":{\"ind1\":\" \",\"ind2\":\" \",\"subfields\":[{\"a\":\"DLC\"},{\"c\":\"DLC\"},{\"d\":\"IUL\"},{\"d\":\"BTCTA\"}]}},{\"029\":{\"ind1\":\"1\",\"ind2\":\" \",\"subfields\":[{\"a\":\"AU@\"},{\"b\":\"000024867271\"}]}},{\"050\":{\"ind1\":\"0\",\"ind2\":\"0\",\"subfields\":[{\"a\":\"KF26\"},{\"b\":\".R885 1965\"}]}},{\"082\":{\"ind1\":\"0\",\"ind2\":\"0\",\"subfields\":[{\"a\":\"507/.4/0153\"}]}},{\"086\":{\"ind1\":\"0\",\"ind2\":\" \",\"subfields\":[{\"a\":\"Y 4.R 86/2:SM 6/965\"}]}},{\"110\":{\"ind1\":\"1\",\"ind2\":\" \",\"subfields\":[{\"a\":\"United States.\"},{\"b\":\"Congress.\"},{\"b\":\"Senate.\"},{\"b\":\"Committee on Rules and Administration.\"},{\"b\":\"Subcommittee on the Smithsonian Institution.\"}]}},{\"245\":{\"ind1\":\"1\",\"ind2\":\"0\",\"subfields\":[{\"a\":\"Smithsonian Institution (National Museum act of 1965)\"},{\"b\":\"Hearing, Eighty-ninth Congress, first session, on S. 1310 and H.R. 7315 ... June 24, 1965.\"}]}},{\"260\":{\"ind1\":\" \",\"ind2\":\" \",\"subfields\":[{\"a\":\"Washington,\"},{\"b\":\"U.S. Govt. Print. Off.,\"},{\"c\":\"1965.\"}]}},{\"300\":{\"ind1\":\" \",\"ind2\":\" \",\"subfields\":[{\"a\":\"iii, 67 p.\"},{\"c\":\"23 cm.\"}]}},{\"610\":{\"ind1\":\"2\",\"ind2\":\"0\",\"subfields\":[{\"a\":\"Smithsonian Institution.\"}]}},{\"938\":{\"ind1\":\" \",\"ind2\":\" \",\"subfields\":[{\"a\":\"Baker and Taylor\"},{\"b\":\"BTCP\"},{\"n\":\"65062399\"}]}},{\"945\":{\"ind1\":\" \",\"ind2\":\" \",\"subfields\":[{\"a\":\"IUL\"}]}}]}"
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
    expect(copy.oclc_resolved).to eq([38])
    expect(copy.sudocs).to eq(["Y 4.R 86/2:SM 6/965"])

    sr.deprecate('rspec test')
  end

  it "can extract local id from MARC" do
    sr = SourceRecord.new
    sr.source = @raw_source
    expect(sr.extract_local_id).to eq("ocm00000038")
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
