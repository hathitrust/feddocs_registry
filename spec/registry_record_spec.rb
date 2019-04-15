require 'registry/registry_record'
require 'dotenv'

Dotenv.load
Mongoid.load!(ENV['MONGOID_CONF'])

RR = Registry::RegistryRecord
SourceRecord = Registry::SourceRecord

RSpec.describe RR, '#initialize' do
  before(:all) do
    cluster = [
      'c6c38adb-2533-4997-85f5-328e91c224a8',
      'c514673d-f634-4f74-a8de-68cd4b281ced',
      '55f97400-6497-46ce-9b9f-477dbbf5e78b'
    ]
    ec = 'ec A'
    @new_rec = RR.new(cluster, ec, 'testing')
    @new_rec.save

    @dgpo_src = Registry::SourceRecord.new
    @dgpo_src.source = File.open(File.dirname(__FILE__) +
                                 '/data/dgpo_has_ecs.json').read
    @dgpo_src.save
    @dgpo_reg = Registry::RegistryRecord.new([@dgpo_src.source_id], '',
                                             'testing')

    @pd_sr = SourceRecord.new
    @pd_sr.org_code = 'miaahdl'
    @pd_sr.source = File.open(File.dirname(__FILE__) +
                         '/data/ht_pd_record.json').read
    @pd_sr.save
  end

  after(:all) do
    @dgpo_src.delete
    @dgpo_reg.delete
    @pd_sr.delete
  end

  it 'creates a new registry record' do
    expect(@new_rec).to be_instance_of(RR)
  end

  it 'collates the source records' do
    expect(@new_rec.author).to be_instance_of(Array)
    expect(@new_rec.sudocs).to eq ['Y 4.R 86/2:SM 6-6/2', 'Y 4.R 86/2:SM 6/965']
    expect(@new_rec.oclc).to eq [38]
    expect(@new_rec.lccn).to eq ['65062399']
    expect(@new_rec.isbn).to eq []
    expect(@new_rec.issn).to eq []
  end

  it 'adds org codes' do
    expect(@new_rec.source_org_codes).to include('txwb')
  end

  it 'sets ht_availability to full view' do
    expect(@new_rec.ht_availability).to eq('Not In HathiTrust')
  end

  it 'collects electronic_resources' do
    expect(@dgpo_reg.electronic_resources).to include('electronic resource')
    expect(@dgpo_reg.electronic_resources).to include('electronic resource no indicator')
    expect(@dgpo_reg.related_electronic_resources).to include('related electronic resource')
    expect(@dgpo_reg.electronic_versions).to include('electronic version')
  end

  it 'collects gpo_item_numbers' do
    expect(@dgpo_reg.gpo_item_numbers).to include('123')
  end
end

RSpec.describe RR, '#cluster' do
  before(:all) do
    @source_has_oclc = Registry::SourceRecord.where(source_id: '7386d49d-2c04-44ea-97aa-fb87b241f56f').first
    @source_only_sudoc = Registry::SourceRecord.where(source_id: '31f7bdf5-0d68-4d38-abf2-266be181a07f').first
    @src = Registry::SourceRecord.new(org_code: 'miaahdl',
                                      oclc_resolved: [5, 25])
    @rr = RR.new([1, 2], '', '')
    @rr.oclc = [5]
    @rr.save
  end

  it 'finds a matching cluster for a source record' do
    expect(RR.cluster(@source_has_oclc, '')).to be_instance_of(RR)
    expect(RR.cluster(@source_has_oclc, 'New Enumchron')).to be_nil
    expect(RR.cluster(@source_only_sudoc, 'NO. 11-16')).to be_instance_of(RR)
    expect(RR.cluster(@source_only_sudoc, 'New Enumchron')).to be_nil
  end

  it 'finds a matching cluster for any oclc' do
    expect(RR.cluster(@src, '')).to eq(@rr)
    @rr.oclc << 50
    @rr.save
    expect(RR.cluster(@src, '')).to eq(@rr)
  end

  it 'does not cluster using abbreviated sudocs' do
    srcs = File.readlines(File.dirname(__FILE__) +
                     '/data/abbreviated_sudocs.ndj')
    src = SourceRecord.new(org_code: 'dgpo', source: srcs.first)
    src.save

    rec = RR.new([src.source_id], '', 'testing')
    rec.save
    src2 = SourceRecord.new(org_code: 'dgpo', source: srcs.last)
    src2.save
    expect(RR.cluster(src2, '')).to be_nil
    rec.delete
    src.delete
    src2.delete
  end

  after(:all) do
    @rr.delete
    @src.delete
  end
end

RSpec.describe RR, 'add_source' do
  before(:all) do
    cluster = [
      'c6c38adb-2533-4997-85f5-328e91c224a8',
      'c514673d-f634-4f74-a8de-68cd4b281ced',
      '55f97400-6497-46ce-9b9f-477dbbf5e78b'
    ]
    ec = 'ec A'
    @new_rec = RR.new(cluster, ec, 'testing')
    @new_rec.save
    @src = Registry::SourceRecord.where(source_id: '7386d49d-2c04-44ea-97aa-fb87b241f56f').first
    @new_rec.add_source @src
    @ic_sr = SourceRecord.new
    @ic_sr.org_code = 'miaahdl'
    ic_line = File.open(File.dirname(__FILE__) + '/data/ht_ic_record.json').read
    @ic_sr.source = ic_line
    @ic_sr.save
    @pd_sr = SourceRecord.new
    @pd_sr.org_code = 'miaahdl'
    pd_line = File.open(File.dirname(__FILE__) + '/data/ht_pd_record.json').read
    @pd_sr.source = pd_line
    @pd_sr.save
    @orig = RR.new([], '', '')
  end

  it 'adds source record to cluster' do
    expect(@new_rec.source_record_ids).to include(@src.source_id)
    expect(@new_rec.oclc).to include(39)
  end

  it 'adds org code' do
    expect(@new_rec.source_org_codes).to include(@src.org_code)
  end

  it 'updates HT availability' do
    expect(@ic_sr.ht_availability).to eq('Limited View')
    @ic_reg = RR.new([@ic_sr.source_id], '', 'testing')
    expect(@ic_reg.ht_availability).to eq('Limited View')
    @ic_reg.add_source(@pd_sr) # should change it to Full View
    expect(@ic_reg.ht_availability).to eq('Full View')
    @pd_reg = RR.where(registry_id: @ic_reg.registry_id).first
    expect(@pd_reg.ht_availability).to eq('Full View')
    @ic_reg.delete
    @pd_reg.delete
  end

  it 'recollates if adding existing record' do
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

  it 'applies the correct series name' do
    # making sure a bug was fixed. It wasn't expanding the name in the add_source method
    @src.source = File.open(File.dirname(__FILE__) +
                            '/series/data/econreport.json').read
    expect(@src.series).to include('Economic Report of the President')
    expect(@src.series).to eq(['Economic Report of the President'])
    @orig.add_source(@src)
    expect(@orig.series).to include('Economic Report of the President')
    expect(@orig['series']).to include('Economic Report of the President')
  end

  after(:all) do
    @new_rec.delete
    @pd_sr.delete
    @ic_sr.delete
  end
end

describe '#series' do
  it 'gets series from its source records' do
    reg = RR.new(['328ef038-92bb-4bfd-ab42-ac7abafe251c'], '', 'testing')
    expect(reg.series).to eq(['Federal Register'])
  end
end

RSpec.describe RR do
  before(:all) do
    mrc = File.open(File.dirname(__FILE__) + '/series/data/econreport.json').read
    @src = SourceRecord.new(org_code: 'miaahdl',
                            source: mrc)
    @src.save
    @reg = RR.new([@src.source_id], '', 'testing')
  end

  it 'collects pub_dates' do
    expect(@src.pub_date).to eq([1966])
    expect(@reg.pub_date).to eq([1966])
  end

  after(:all) do
    @src.delete
  end
end

RSpec.describe RR, '#save' do
  it 'changes last_modified before saving' do
    rec = RR.first
    now = Time.now.utc
    rec.save
    samerec = RR.where(:last_modified.gte => now).first
    expect(rec.registry_id).to eq samerec.registry_id
  end
end

RSpec.describe RR, '#merge' do
  before(:all) do
    @old_ids = [
      'ada3c4a3-57dc-4f7e-9d54-bd61c0d52eaf',
      '8a2e3921-fa17-4bba-8db5-80e34a3667c9',
      'a363f4ef-4a5a-4574-b979-7fcf170c4004'
    ]
    @res = RR.merge(@old_ids, 'new enumchron', 'testing the merge')
  end

  after(:all) do
    @res.deprecate('undoing an rspec test')
    @old_recs = RR.where(:registry_id.in => @old_ids)
    @old_recs.each do |r|
      # not a good idea elsewhere
      r.unset(:deprecated_reason)
      r.unset(:deprecated_timestamp)
      r.unset(:successors)
      r.save
    end
  end

  it 'returns a new rec with links to deprecated' do
    expect(@res).to be_instance_of(RR)
    expect(@res.ancestors).to eq(@old_ids)
    expect(@res.creation_notes).to eq('testing the merge')
  end

  it 'deletes the old recs' do
    @old_recs = RR.where(:registry_id.in => @old_ids)
    @old_recs.each do |r|
      expect(r.deprecated_reason).to eq('testing the merge')
      expect(r.successors).to eq([@res.registry_id])
    end
  end
end

RSpec.describe RR, '#deprecate' do
  before(:each) do
    @rec = RR.where(:source_record_ids.with_size => 6).first
  end

  after(:each) do
    @rec.unset(:deprecated_reason)
    @rec.unset(:deprecated_timestamp)
    @rec.unset(:successors)
    @rec.save
  end

  it 'adds a deprecated field' do
    @rec.deprecate('testing deletion', ['first successor id', 'second successor id'])
    expect(@rec.deprecated_reason).to eq('testing deletion')
    expect(@rec.successors).to eq(['first successor id', 'second successor id'])
  end
end

RSpec.describe RR, 'monograph?' do
  it 'returns true if one or more source records is a monograph bib' do
    rec = RR.where(oclc: 447_925).first
    expect(rec.monograph?).to be true
  end

  it 'returns false if none of the source records are a monograph bib' do
    rec = RR.where(oclc: 243_871_545).first
    expect(rec.monograph?).to be false
  end
end

RSpec.describe RR, '#split' do
  @new_recs = []
  before(:all) do
    # find me a record with at least six source_record_ids
    @rec = RR.where(:source_record_ids.with_size => 6).first
    expect(@rec.source_record_ids.size).to eq(6)
    @clusters = {
      @rec.source_record_ids[0..1] => 'ec A',
      @rec.source_record_ids[2..3] => 'ec B',
      @rec.source_record_ids[4..5] => 'ec C'
    }
    @new_recs = @rec.split(@clusters, 'testing split')
  end

  after(:all) do
    @rec.unset(:deprecated_timestamp)
    @rec.unset(:deprecated_reason)
    @new_recs.each do |r|
      r.deprecate('undoing an rspec test')
    end
  end

  it 'adds a deprecated field' do
    expect(@rec.deprecated_reason).to eq('testing split')
  end

  it 'creates three new records' do
    expect(@new_recs.count).to eq(3)
  end

  it 'links deprecated to successors' do
    expect(@new_recs.collect(&:registry_id)).to eq(@rec.successors)
  end

  it 'links new records to ancestor' do
    @new_recs.each do |r|
      expect(r.ancestors).to eq([@rec.registry_id])
    end
  end

  it 'updates with the correct enumchron' do
    expect(@new_recs.last.enum_chron).to eq('ec C')
  end
end

RSpec.describe RR, '#report_numbers' do
  before(:all) do
    @src = SourceRecord.new(org_code: 'miu')
    @src.source = File.open(File.dirname(__FILE__) +
                            '/data/osti_record.json').read
    @src.save
    @rec = RR.new([@src.source_id], '', '')
  end

  it 'collects report_numbers from source recs' do
    expect(@src.report_numbers).to eq(['la-ur-02-5859'])
    expect(@rec.report_numbers).to eq(['la-ur-02-5859'])
  end

  after(:all) do
    @rec.delete
    @src.delete
  end
end

RSpec.describe RR, '#print_holdings' do
  before(:all) do
    @rec = RR.where(:source_record_ids.with_size => 6).first
    @rec.oclc = [10_210_704]
  end

  it 'retrieves member ids from the print holdings database' do
    expect(@rec.print_holdings([10_210_704]).count).to eq(14)
    expect(@rec.print_holdings([10_210_704])).to include('northwestern')
  end

  #   it "processes a hundred print holdings a second" do
  #     start = Time.now
  #     count = 0
  #     RR.where(oclc:{"$exists":1}).no_timeout.each do |r|
  #       count += 1
  #       if count > 5000
  #         break
  #       end
  #       ph = r.print_holdings
  #     end
  #     endtime = Time.now
  #     expect( endtime - start ).to eq(5)
  #   end
end
