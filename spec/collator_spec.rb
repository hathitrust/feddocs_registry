require 'registry/collator'
require 'dotenv'
require 'mongoid'
require 'pp'
require 'spec_helper'

Dotenv.load
Mongoid.load!("config/mongoid.yml")

RC = Registry::Collator

RSpec.describe RC, "#initialize" do
  before(:all) do 
    @collator = RC.new('config/traject_config.rb')
  end

  it "loads an extractor" do 
    expect(@collator.extractor).not_to be_nil
  end

  it "has a viafer" do 
    expect(@collator.viaf).not_to be_nil
  end

end

RSpec.describe RC, "#extract_fields" do
  before(:all) do
    #just grab one
    @regrec = Registry::RegistryRecord.where(:source_record_ids.with_size => 6).first
    @collator = RC.new('config/traject_config.rb')
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
  

