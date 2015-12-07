require 'collator'
require 'dotenv'
require 'mongoid'
require 'pp'

Dotenv.load
Mongoid.load!("config/mongoid.yml")

RSpec.describe Collator, "#initialize" do
  before(:all) do 
    @collator = Collator.new('config/traject_config.rb')
  end

  it "loads an extractor" do 
    expect(@collator.extractor).not_to be_nil
  end

  it "has a viafer" do 
    expect(@collator.viaf).not_to be_nil
  end

end

RSpec.describe Collator, "#extract_fields" do
  before(:all) do
    @regrec = RegistryRecord.where(:registry_id => "16070960-9e18-48b0-9cbb-582353507087").first
    @collator = Collator.new('config/traject_config.rb')
    @collected_fields = @collator.extract_fields @regrec.sources 
  end

  it "collects all the fields from all source records" do
    all_fields = []
    @regrec.sources.each do | key, value |
      all_fields << key
    end
    expect(all_fields.uniq.count).to be < @collected_fields.keys.count
  end

  it "sets ht_availability to full view" do
    expect(@collected_fields[:ht_availability]).to eq("Full View") 
  end
      
end
  

