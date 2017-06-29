require 'registry/registry_record'
require 'dotenv'

Dotenv.load
Mongoid.load!("config/mongoid.yml")

RR = Registry::RegistryRecord
SourceRecord = Registry::SourceRecord

RSpec.describe RR, "#initialize" do
  before(:all) do
    cluster = [
              "c6c38adb-2533-4997-85f5-328e91c224a8",
              "c514673d-f634-4f74-a8de-68cd4b281ced",
              "55f97400-6497-46ce-9b9f-477dbbf5e78b",    
               ]
    ec = 'ec A'
    @new_rec = RR.new(cluster, ec, 'testing')
    @new_rec.save()

    @dgpo_src = Registry::SourceRecord.new
    @dgpo_src.source = open(File.dirname(__FILE__)+"/data/dgpo_has_ecs.json").read
    @dgpo_src.save
    @dgpo_reg = Registry::RegistryRecord.new([@dgpo_src.source_id], '' ,'testing')

  end

  after(:all) do
    @dgpo_src.delete
    @dgpo_reg.delete
  end

  it "creates a new registry record" do
    expect(@new_rec).to be_instance_of(RR)
  end

  it "collates the source records" do 
    expect(@new_rec.author_display).to be_instance_of(Array)
    expect(@new_rec.sudoc_display).to eq ["Y 4.R 86/2:SM 6-6/2","Y 4.R 86/2:SM 6/965"]
    expect(@new_rec.oclcnum_t).to eq [38]
    expect(@new_rec.lccn_t).to eq ["65062399"]
    expect(@new_rec.isbn_t).to eq []
    expect(@new_rec.issn_t).to eq []
  end

  it "adds org codes" do
    expect(@new_rec.source_org_codes).to include('txwb')
  end

  it "sets ht_availability to full view" do
    expect(@new_rec.ht_availability).to eq("Not In HathiTrust") 
  end

  it "collects electronic_resources" do
    expect(@dgpo_reg.electronic_resources).to include('electronic resource')
  end

end

RSpec.describe RR, "#cluster" do
  before(:all) do 
    @source_has_oclc = Registry::SourceRecord.where(source_id: "7386d49d-2c04-44ea-97aa-fb87b241f56f").first
    @source_only_sudoc = Registry::SourceRecord.where(source_id: "31f7bdf5-0d68-4d38-abf2-266be181a07f").first
  end

  it "finds a matching cluster for a source record" do
    expect(RR::cluster(@source_has_oclc, "")).to be_instance_of(RR)
    expect(RR::cluster(@source_has_oclc, "New Enumchron")).to be_nil
    expect(RR::cluster(@source_only_sudoc, "NO. 11-16")).to be_instance_of(RR)
    expect(RR::cluster(@source_only_sudoc, "New Enumchron")).to be_nil
  end
end

RSpec.describe RR, "add_source" do
  before(:all) do
    cluster = [
              "c6c38adb-2533-4997-85f5-328e91c224a8",
              "c514673d-f634-4f74-a8de-68cd4b281ced",
              "55f97400-6497-46ce-9b9f-477dbbf5e78b",    
               ]
    ec = 'ec A'
    @new_rec = RR.new(cluster, ec, 'testing')
    @new_rec.save()
    @src = Registry::SourceRecord.where(source_id: "7386d49d-2c04-44ea-97aa-fb87b241f56f").first
    @new_rec.add_source @src 
    @ic_sr = SourceRecord.new
    @ic_sr.org_code = "miaahdl"
    ic_line = open(File.dirname(__FILE__)+'/data/ht_ic_record.json').read
    @ic_sr.source = ic_line
    @ic_sr.save
    @pd_sr = SourceRecord.new
    @pd_sr.org_code = "miaahdl"
    pd_line = open(File.dirname(__FILE__)+'/data/ht_pd_record.json').read
    @pd_sr.source = pd_line
    @pd_sr.save
    @orig = RR.new([], '', '')
  end

  it "adds source record to cluster" do
    expect(@new_rec.source_record_ids).to include(@src.source_id) 
    expect(@new_rec.oclcnum_t).to include(39)
  end


  it "adds org code" do
    expect(@new_rec.source_org_codes).to include(@src.org_code)
  end

  it "updates HT availability" do
    expect(@ic_sr.ht_availability).to eq('Limited View')
    @ic_reg = RR.new([@ic_sr.source_id], '', 'testing')
    expect(@ic_reg.ht_availability).to eq('Limited View')
    @ic_reg.add_source(@pd_sr) # should change it to Full View
    expect(@ic_reg.ht_availability).to eq('Full View')
    @pd_reg = RR.where(registry_id:@ic_reg.registry_id).first
    expect(@pd_reg.ht_availability).to eq('Full View')
    @ic_reg.delete
    @pd_reg.delete
  end

  it "recollates if adding existing record" do
    @orig = RR.new([@pd_sr.source_id], '', 'testing')
    @orig.save
    expect(@orig.ht_availability).to eq('Full View')
    # "Full View" over writes "Limited" so if it remains 
    # Full View after changing the source to limited and adding
    # then it's not recollating 
    @pd_sr.source = @ic_sr.source.to_json
    @pd_sr.save
    @orig.add_source(@pd_sr)
    expect(@orig.ht_availability).to eq('Limited View')
  end 

  it "applies the correct series name" do
    # making sure a bug was fixed. It wasn't expanding the name in the add_source method
    @src.source = open(File.dirname(__FILE__)+'/series/data/econreport.json').read
    expect(@src.series).to eq('EconomicReportOfThePresident')
    @orig.add_source(@src)
    expect(@orig['series']).to eq("Economic Report Of The President")
  end

  after(:all) do
    @new_rec.delete
    @pd_sr.delete
    @ic_sr.delete
  end
end

RSpec.describe RR, "#save" do
  it "changes last_modified before saving" do
    rec = RR.first
    now = Time.now.utc
    rec.save
    samerec = RR.where(:last_modified.gte => now).first
    expect(rec.registry_id).to eq samerec.registry_id
  end
end

RSpec.describe RR, "#merge" do
  before(:all) do 
    @old_ids = [
                "ada3c4a3-57dc-4f7e-9d54-bd61c0d52eaf",
                "8a2e3921-fa17-4bba-8db5-80e34a3667c9",
                "a363f4ef-4a5a-4574-b979-7fcf170c4004"
               ]
    @res = RR::merge( @old_ids, "new enumchron", "testing the merge" )
  end
  
  after(:all) do
    @res.deprecate("undoing an rspec test")
    @old_recs = RR.where(:registry_id.in => @old_ids)
    @old_recs.each do | r |
      #not a good idea elsewhere
      r.unset(:deprecated_reason)
      r.unset(:deprecated_timestamp)
      r.unset(:successors)
      r.save
    end
  end

  it "returns a new rec with links to deprecated" do
    expect(@res).to be_instance_of(RR)
    expect(@res.ancestors).to eq(@old_ids)
    expect(@res.creation_notes).to eq("testing the merge")
  end

  it "deletes the old recs" do
    @old_recs = RR.where(:registry_id.in => @old_ids)
    @old_recs.each do | r |
      expect(r.deprecated_reason).to eq("testing the merge")
      expect(r.successors).to eq([@res.registry_id])
    end
  end

end

RSpec.describe RR, "#deprecate" do
  before(:each) do
    @rec = RR.where(:source_record_ids.with_size => 6).first
  end

  after(:each) do
    @rec.unset(:deprecated_reason)
    @rec.unset(:deprecated_timestamp)
    @rec.unset(:successors)
    @rec.save
  end

  it "adds a deprecated field" do
    @rec.deprecate("testing deletion", ["first successor id", "second successor id"])
    expect(@rec.deprecated_reason).to eq("testing deletion")
    expect(@rec.successors).to eq(["first successor id", "second successor id"])
  end
end

RSpec.describe RR, "is_monograph?" do
  it "returns true if one or more source records is a monograph bib" do
    rec = RR.where(oclcnum_t:447925).first
    expect(rec.is_monograph?).to be true
  end

  it "returns false if none of the source records are a monograph bib" do
    rec = RR.where(oclcnum_t:243871545).first
    expect(rec.is_monograph?).to be false
  end
end

RSpec.describe RR, "#split" do
  @new_recs = []
  before(:all) do
    #find me a record with at least six source_record_ids
    @rec = RR.where(:source_record_ids.with_size => 6).first
    expect(@rec.source_record_ids.size).to eq(6)
    @clusters = {
      @rec.source_record_ids[0..1] => 'ec A',
      @rec.source_record_ids[2..3] => 'ec B',
      @rec.source_record_ids[4..5] => 'ec C'
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

RSpec.describe RR, "#print_holdings" do
  before(:all) do
    @rec = RR.where(:source_record_ids.with_size => 6).first
    @rec.oclcnum_t = [10210704]
  end

  it "retrieves member ids from the print holdings database" do
    expect(@rec.print_holdings([10210704]).count).to eq(15)
    expect(@rec.print_holdings([10210704])).to include("umich")
  end

=begin
  it "processes a hundred print holdings a second" do 
    start = Time.now
    count = 0
    RR.where(oclcnum_t:{"$exists":1}).no_timeout.each do |r| 
      count += 1
      if count > 5000
        break
      end
      ph = r.print_holdings
    end
    endtime = Time.now
    expect( endtime - start ).to eq(5)
  end 
=end

end
