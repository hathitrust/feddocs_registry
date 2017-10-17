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

end

RSpec.describe RC, "#extract_fields" do
  before(:all) do
    #just grab one
    @regrec = Registry::RegistryRecord.where(:source_record_ids.with_size => 6).first
    @collator = RC.new('config/traject_config.rb')
    @collected_fields = @collator.extract_fields @regrec.sources 
    @alsrc = Registry::SourceRecord.new()
    @alsrc.source = open(File.dirname(__FILE__)+"/data/whitelisted_oclc.json").read
    @alsrc.save
    @alreg = Registry::RegistryRecord.new([@alsrc.source_id], '', 'testing')
    @dgpo_src = Registry::SourceRecord.new
    @dgpo_src.source = open(File.dirname(__FILE__)+"/data/dgpo_has_ecs.json").read
    @dgpo_src.save
    @dgpo_reg = Registry::RegistryRecord.new([@dgpo_src.source_id], '' ,'testing')
  end

  it "collects all the fields from all source records" do
    all_fields = []
    #todo: bad test!
    @regrec.sources.each do | key, value |
      all_fields << key
    end
    expect(all_fields.uniq.count).to be < @collected_fields.keys.count
  end

  it "collects author_lccns" do 
    expect(@alreg.author_lccns.count).to be > 0
    #expect(@alreg.author_lccn_lookup).to be_nil
    expect(@alreg.author_lccns).to eq(['https://lccn.loc.gov/n79086751'])
  end    

  it "collects added entry authorities" do
    expect(@dgpo_reg.added_entry_lccns).to include('https://lccn.loc.gov/n80126064')
  end

  it "collects electronic_resources" do
    expect(@dgpo_reg.electronic_resources).to include('electronic resource')
  end


  after(:all) do
    @alsrc.delete
    @alreg.delete
    @dgpo_src.delete
    @dgpo_reg.delete
  end
end
  

