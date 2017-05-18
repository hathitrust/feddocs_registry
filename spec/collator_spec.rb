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
    @alsrc = Registry::SourceRecord.new()
    @alsrc.source = open(File.dirname(__FILE__)+"/data/whitelisted_oclc.json").read
    @alsrc.save
    @alreg = Registry::RegistryRecord.new([@alsrc.source_id], '', 'testing')

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
    expect(@alreg.author_lccns).to eq(['https://lccn.loc.gov/n79086751'])
  end    

  it "collects added entry authorities" do
    sr = Registry::SourceRecord.new
    sr.source = open(File.dirname(__FILE__)+"/data/dgpo_has_ecs.json").read
    sr.save
    reg = Registry::RegistryRecord.new([sr.source_id], '' ,'testing')
    expect(sr.added_entry_lccns).to include('https://lccn.loc.gov/n80126064')
  end

  after(:all) do
    @alsrc.remove
    @alreg.remove
  end
end
  

