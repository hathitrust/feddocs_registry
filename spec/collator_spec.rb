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
    #just grab one
    @regrec = RegistryRecord.where(:source_record_ids.with_size => 6).first
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

      
end
  

