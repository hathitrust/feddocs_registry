require 'source_record'
require 'dotenv'

Dotenv.load
Mongoid.load!("config/mongoid.yml")

RSpec.describe SourceRecord do
  it "sets an id on initialization" do 
    sr = SourceRecord.new
    expect(sr.source_id).to be_instance_of(String)
    expect(sr.source_id.length).to eq(36)
  end

  it "converts the source string to a hash" do
    sr = SourceRecord.new
    sr.source = "{\"leader\":\"00554nam a2200193 a 4500\",\"fields\":[{\"008\":\"980327         dcu          f000 0 eng d\"},{\"035\":{\"ind1\":\" \",\"ind2\":\" \",\"subfields\":[{\"a\":\"tmp97208858\"}]}},{\"049\":{\"ind1\":\" \",\"ind2\":\" \",\"subfields\":[{\"a\":\"SCIR\"}]}},{\"074\":{\"ind1\":\" \",\"ind2\":\" \",\"subfields\":[{\"a\":\"0254-A\"}]}},{\"086\":{\"ind1\":\"0\",\"ind2\":\" \",\"subfields\":[{\"a\":\"C 21.14/2:F 76/996/REV.1\"}]}},{\"086\":{\"ind1\":\"0\",\"ind2\":\" \",\"subfields\":[{\"a\":\"C 21.14/2:F 76/996/REV.1\"}]}},{\"245\":{\"ind1\":\" \",\"ind2\":\" \",\"subfields\":[{\"a\":\"Manual Of Patent Examining Form Paragraphs, Revision 1 Of The Third Edition, December 1997\"}]}},{\"955\":{\"ind1\":\" \",\"ind2\":\" \",\"subfields\":[{\"a\":\".b38427254\"}]}},{\"998\":{\"ind1\":\" \",\"ind2\":\" \",\"subfields\":[{\"a\":\".b38427254\"},{\"b\":\"slref\"},{\"c\":\"m\"}]}},{\"902\":{\"ind1\":\" \",\"ind2\":\" \",\"subfields\":[{\"a\":\"040927\"}]}},{\"999\":{\"ind1\":\" \",\"ind2\":\" \",\"subfields\":[{\"b\":\"1\"},{\"c\":\"980327\"},{\"d\":\"m\"},{\"e\":\"a\"},{\"f\":\"m\"},{\"g\":\"0\"}]}},{\"994\":{\"ind1\":\" \",\"ind2\":\" \",\"subfields\":[{\"a\":\"slref\"}]}},{\"910\":{\"ind1\":\" \",\"ind2\":\" \",\"subfields\":[{\"a\":\"USDOCS\"}]}},{\"949\":{\"ind1\":\" \",\"ind2\":\"1\",\"subfields\":[{\"l\":\"slref\"},{\"c\":\"1\"},{\"i\":\"39001037089193\"},{\"t\":\"0\"}]}}],\"file_name\":\"/htdata/govdocs/MARC/raw_xml/arizona20140207-15.xml\"}"
    expect(sr.source).to be_instance_of(Hash)
    expect(sr.source["fields"][0]["008"]).to eq("980327         dcu          f000 0 eng d")
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


