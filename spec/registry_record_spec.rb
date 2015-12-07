require 'registry_record'
require 'dotenv'

Dotenv.load
Mongoid.load!("config/mongoid.yml")

RSpec.describe RegistryRecord, "#initialize" do
  it "creates a new registry record" do
    cluster = [
                "d1110c28-fa35-411c-9af9-e573a351378e",
                "c728b935-6606-460a-bd8d-3a03385eab45",
                "4e64308f-a07b-453e-b647-29ebffae5a6d"
               ]
    ec = 'ec A'
    new_rec = RegistryRecord.new(cluster, ec, 'testing')
    expect(new_rec).to be_instance_of(RegistryRecord)
  end
end

RSpec.describe RegistryRecord, "#save" do
  it "changes lastModified before saving" do
    rec = RegistryRecord.first
    now = Time.now.utc
    rec.save
    samerec = RegistryRecord.where(:lastModified.gte => now).first
    expect(rec.registry_id).to eq samerec.registry_id
  end
end

RSpec.describe RegistryRecord, "#merge" do
  before(:all) do 
    @old_ids = [
                "d1110c28-fa35-411c-9af9-e573a351378e",
                "c728b935-6606-460a-bd8d-3a03385eab45",
                "4e64308f-a07b-453e-b647-29ebffae5a6d"
               ]
    @res = RegistryRecord::merge( @old_ids, "new enumchron", "testing the merge" )
  end
  
  after(:all) do
    @res.deprecate("undoing an rspec test")
    @old_recs = RegistryRecord.where(:registry_id.in => @old_ids)
    @old_recs.each do | r |
      #not a good idea elsewhere
      r.unset(:deprecated_reason)
      r.unset(:deprecated_timestamp)
      r.unset(:successors)
    end
  end

  it "returns a new rec with links to deprecated" do
    expect(@res).to be_instance_of(RegistryRecord)
    expect(@res.ancestors).to eq(@old_ids)
    expect(@res.creation_notes).to eq("testing the merge")
  end

  it "deletes the old recs" do
    @old_recs = RegistryRecord.where(:registry_id.in => @old_ids)
    @old_recs.each do | r |
      expect(r.deprecated_reason).to eq("testing the merge")
      expect(r.successors).to eq([@res.registry_id])
    end
  end

end

RSpec.describe RegistryRecord, "#deprecate" do
  before(:each) do
    @rec = RegistryRecord.where("registry_id" => "d1110c28-fa35-411c-9af9-e573a351378e").first
  end

  after(:each) do
    @rec.unset(:deprecated_reason)
    @rec.unset(:deprecated_timestamp)
    @rec.unset(:successors)
  end

  it "adds a deprecated field" do
    @rec.deprecate("testing deletion", ["first successor id", "second successor id"])
    expect(@rec.deprecated_reason).to eq("testing deletion")
    expect(@rec.successors).to eq(["first successor id", "second successor id"])
  end
end

RSpec.describe RegistryRecord, "#split" do
  @new_recs = []
  before(:all) do
    @rec = RegistryRecord.where(:registry_id => "d1110c28-fa35-411c-9af9-e573a351378e").first
    @clusters = {
      ["66966803-1b16-4488-85da-cb469f76ae87", "71f23409-4901-4511-bb7f-bf5b44baf623"] => 'ec A',
      ["acd0d02a-403e-4fbe-843c-92025c0ddee3", "2543d1b3-9547-45c9-a408-30c34cbe3761"] => 'ec B',
      ["12d78f03-6ffc-43a2-9c76-129626497625", "dc4bca31-81c7-446d-bcd2-1ee290bbc597"] => 'ec C'
    }
    @new_recs = @rec.split(@clusters, "testing split")
  end

  after(:all) do
    @rec.unset(:deprecated_timestamp)
    @rec.unset(:deprecated_reason)
    @new_recs.each do | r |
      r.deprecate("undoing an rspec test")
    end
  end

  it "adds a deprecated field" do
    expect(@rec.deprecated_reason).to eq("testing split")
  end

  it "creates three new records" do
    expect(@new_recs.count).to eq(3)
  end

  it "links deprecated to successors" do
    expect(@new_recs.collect{|r| r.registry_id}).to eq(@rec.successors)
  end

  it "links new records to ancestor" do
    @new_recs.each do |r|
      expect(r.ancestors).to eq([@rec.registry_id])
    end
  end

  it "updates with the correct enumchron" do
    expect(@new_recs.last.enumchron_display).to eq("ec C")
  end
end



