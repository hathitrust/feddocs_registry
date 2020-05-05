require 'registry/source_record'
require 'dotenv'
require 'pp'

Dotenv.load
Mongoid.load!(ENV['MONGOID_CONF'])
SourceRecord = Registry::SourceRecord
RegistryRecord = Registry::RegistryRecord

RSpec.describe SourceRecord do
  before(:all) do
    @fr_rec = File.open(File.dirname(__FILE__) + '/series/data/federal_register.json').read
    @ht_pd_rec = File.open(File.dirname(__FILE__) + '/data/ht_pd_record.json').read
  end

  it 'detects series' do
    sr = SourceRecord.new(org_code: 'miu',
                          source: @fr_rec)
    expect(sr.series).to include('Federal Register')
    crc_rec = File.open(File.dirname(__FILE__) + '/series/data/crc_record.json').read
  end

  it 'parses the enumchron if it has a series' do
    sr = SourceRecord.new(org_code: 'miu',
                          source: @fr_rec)
    expect(sr.enum_chrons).to include('Volume:77, Number:97')
  end

  it "performs default parsing if it doesn't have a series" do
    sr = SourceRecord.new(org_code: 'miaahdl',
                          source: @ht_pd_rec)
    expect(sr.series.count).to be(0)
    expect(sr.enum_chrons).to include('Volume:1')
  end

  it "chokes when there is '$' in MARC subfield names" do
    # Mongo doesn't like $ in field names. Occasionally, these show up when
    # MARC subfields get messed up. (GPO). This should throw an error.
    rec = File.open(File.dirname(__FILE__) + '/data/dollarsign.json').read
    sr = SourceRecord.new(org_code: 'dgpo',
                          source: rec)
    expect { sr.save }.to raise_error(BSON::String::IllegalKey)
  end
end

RSpec.describe Registry::SourceRecord do
  before(:each) do
    @raw_source = File.open(File.dirname(__FILE__) +
                            '/data/default_source_rec.json').read
    @sr = SourceRecord.new(org_code: 'miaahdl',
                           source: @raw_source)
  end

  it 'sets an id on initialization' do
    expect(@sr.source_id).to be_instance_of(String)
    expect(@sr.source_id.length).to eq(36)
  end

  it 'sets the publication date' do
    expect(@sr.pub_date).to eq([1965])
  end

  it 'reset the publication date' do
    src = File.open(File.dirname(__FILE__) + '/data/pub_date.json').read
    pub = SourceRecord.new(org_code: 'mnu',
                           source: src)
    expect(pub.pub_date).to eq([1953])
    pub.remove_attribute('pub_date')
    pub.remove_attribute('source')
    pub.remove_instance_variable(:@extractions)
    expect(pub['pub_date']).to be_nil
    expect(pub.pub_date).to eq([])
    # but if it has a source field it will get recreated
    pub['source'] = JSON.parse(src)
    expect(pub.pub_date).to eq([1953])
  end

  it 'does not extract the lc_callnumbers' do
    expect(@sr['lc_call_numbers']).to be_nil
    expect(@sr['lc_classifications']).to be_nil
    expect(@sr['lc_item_numbers']).to be_nil
  end

  it 'sets a marc field' do
    expect(@sr.marc['008'].value).to eq('690605s1965    dcu           000 0 eng  ')
  end

  it 'timestamps on save' do
    expect(@sr.last_modified).to be_nil
    @sr.save
    expect(@sr.last_modified).to be_instance_of(DateTime)
  end

  it 'defaults to HathiTrust org code' do
    sr = SourceRecord.new
    expect(sr.org_code).to eq('miaahdl')
    sr = SourceRecord.new(org_code: 'tacos')
    expect(sr.org_code).to eq('tacos')
  end

  it 'converts the source string to a hash' do
    expect(@sr.source).to be_instance_of(Hash)
    expect(@sr.source['fields'][3]['008']).to eq('690605s1965    dcu           000 0 eng  ')
  end

  it 'extracts normalized author/publisher/corp' do
    @sr.save
    sr_id = @sr.source_id
    copy = SourceRecord.find_by(source_id: sr_id)
    expect(copy.lccn_normalized).to eq(['65062399'])
    expect(copy.sudocs).to eq(['Y 4.R 86/2:SM 6/965'])
    expect(copy.publisher).to include('U.S. Govt. Print. Off.,')
    expect(copy.author).to include('United States. Congress. Senate. Committee on Rules and Administration. Subcommittee on the Smithsonian Institution.')
  end

  it 'extracts publisher' do
    line = File.open(File.open(File.dirname(__FILE__) +
                               '/data/record_with_publisher.json')).read
    src = SourceRecord.new(org_code: 'mdu',
                           source: line)
    expect(src['publisher']).to include('Government Printing Office,')
    expect(src.publisher).to include('Government Printing Office,')
  end

  it 'extracts oclc number from 001, 035, 776' do
    expect(@sr.oclc_resolved).to eq([38, 812_424_058])
    expect(@sr.oclcs_from_776_fields).to eq([812_424_058])
  end

  it 'can extract local id from MARC' do
    expect(@sr.extract_local_id).to eq('ocm00000038')
  end

  it 'extracts formats' do
    expect(@sr['formats']).to eq(%w[Book Print])
    expect(@sr.formats).to eq(%w[Book Print])
  end

  it 'performs reasonably well' do
    line = File.open(File.dirname(__FILE__) +
                '/data/ht_record_different_3_items.json').read
    call_count = 0
    name = :new_from_hash
    TracePoint.trace(:call) do |t|
      call_count += 1 if t.method_id == name
    end
    sr = SourceRecord.new(org_code: 'miaahdl',
                          source: line)
    sr.monograph?
    sr.fed_doc?
    sr.extract_local_id
    expect(call_count).to eq(1)
    !expect { sr.source = line }.to perform_under(2).ms
  end
end

RSpec.describe Registry::SourceRecord, '#resolve_oclc' do
  it 'has a MAX_OCN' do
    expect(SourceRecord::MAX_OCN).to eq(2_000_000_000)
  end

  it 'resolves OCLCs for records with multiple OCLCs' do
    sr = SourceRecord.new
    sr.org_code = 'azu'
    sr.source = File.open(File.dirname(__FILE__) + '/data/oclc_resolution.json').read
    # the second oclc number is bogus but will resolve to 227681. We should hang onto
    # 1198154
    # the third oclc number is obviously invalid and is ignored
    expect(sr.oclc_alleged).to eq([1_198_154, 9_999_999_999, 244_155])
    expect(sr.oclc_resolved).to eq([1_198_154, 227_681])
  end

  it 'removes OCNs that match a GPO number' do
    sr = SourceRecord.new(org_code: 'miaahdl',
                          source: File.open(
                            File.dirname(__FILE__) +
                            '/data/bogus_gpo_ocn.json'
                          ).read)
    expect(sr.oclc_alleged).to eq([76_006_743])
    expect(sr.matches_gpo_ids(sr.oclc_alleged[0])).to be true
    expect(sr.oclc_resolved).to eq([])
  end
end

RSpec.describe Registry::SourceRecord, 'gpo_ids' do
  it 'extracts gpo ids' do
    sr = SourceRecord.new(org_code: 'miaahdl',
                          source: File.open(
                            File.dirname(__FILE__) +
                            '/data/bogus_gpo_ocn.json'
                          ).read)
    expect(sr.gpo_ids).to eq([76_006_743])
  end
end

RSpec.describe Registry::SourceRecord, '#oclcs_from_955o_fields' do
  it 'extracts OCLCS from strange INU records' do
    sr = SourceRecord.new(org_code: 'inu',
                          source: File.open(File.dirname(__FILE__) +
                          '/data/inu_record.json').read)
    expect(sr.oclcs_from_955o_fields).to eq([857_794_111])
  end
end

RSpec.describe Registry::SourceRecord, '#remove_incorrect_substring_oclcs' do
  it 'removes incorrect OCLCS from an array' do
    sr = SourceRecord.new
    expect(
      sr.remove_incorrect_substring_oclcs([1_234_567, 234_567])
    ).to eq([1_234_567])
  end

  it 'OCLCS < 10000 are not deemed incorrect' do
    sr = SourceRecord.new
    expect(
      sr.remove_incorrect_substring_oclcs([1_234_567, 567])
    ).to eq([1_234_567, 567])
    expect(
      sr.remove_incorrect_substring_oclcs([1_234_567, 234_567, 567])
    ).to eq([1_234_567, 567])
  end
end

RSpec.describe Registry::SourceRecord, '#extracted_field' do
  before(:all) do
    @sr = SourceRecord.new
    @sr.source = File.open(File.dirname(__FILE__) + '/data/dgpo_has_ecs.json').read
    @sr.electronic_versions = nil
    @sr.electronic_resources = nil
    @sr.save
  end

  it 'extracts 856s into electronic_resources' do
    expect(@sr.electronic_versions).to include('http://purl.access.gpo.gov/GPO/LPS40802')
    expect(@sr.electronic_versions).to include('http://purl.access.gpo.gov/GPO/LPS40802')
    expect(@sr.electronic_resources).to include('electronic resource no indicator')
    expect(@sr.electronic_resources).to include('electronic resource')
    expect(@sr.related_electronic_resources).to include('related electronic resource')
  end

  it 'saves dynamically extracted fields' do
    @sr.electronic_resources
    @sr.electronic_versions
    @sr.save
    copy = SourceRecord.find_by(source_id: @sr.source_id)
    expect(copy['electronic_resources']).to include('electronic resource no indicator')
    expect(copy['electronic_resources']).to include('electronic resource')
    expect(copy['electronic_versions']).to include('http://purl.access.gpo.gov/GPO/LPS40802')
    expect(copy['related_electronic_resources']).to include('related electronic resource')
  end

  after(:all) do
    @sr.delete
  end
end

RSpec.describe Registry::SourceRecord, '#author_lccns' do
  it 'identifies authorities for author headings' do
    sr = SourceRecord.new
    sr.source = File.open(File.dirname(__FILE__) + '/data/whitelisted_oclc.json').read
    expect(sr['author_lccns']).to include('https://lccn.loc.gov/n79086751')
    expect(sr.author_lccns).to include('https://lccn.loc.gov/n79086751')
  end

  it 'identifies authorities for added entry names' do
    sr = SourceRecord.new
    sr.source = File.open(File.dirname(__FILE__) + '/data/dgpo_has_ecs.json').read
    expect(sr.added_entry_lccns).to include('https://lccn.loc.gov/n80126064')
  end
end

RSpec.describe Registry::SourceRecord, '#report_numbers' do
  it 'pulls report_numbers from the 088' do
    sr = SourceRecord.new(org_code: 'miu')
    sr.source = File.open(File.dirname(__FILE__) + '/data/osti_record.json').read
    expect(sr.report_numbers).to eq(['la-ur-02-5859'])
  end
end

RSpec.describe Registry::SourceRecord, '#extract_local_id' do
  before(:all) do
    # zero filled integer
    @rec = SourceRecord.new
    @rec.org_code = 'miaahdl'
    @rec.source = File.open(File.dirname(__FILE__) + '/data/ht_ic_record.json').read
    # has non-integer in id
    @weird = SourceRecord.new
    @weird.org_code = 'miaahdl'
    @weird.source = File.open(File.dirname(__FILE__) + '/data/ht_weird_id.json').read
  end

  after(:all) do
    @rec.delete
    @weird.delete
  end

  it 'keeps the local id as a string' do
    expect(@rec.local_id).to be_a(String)
    expect(@weird.local_id).to be_a(String)
  end

  it 'removes leading zeroes if it is an integer' do
    expect(@rec.local_id).to eq('34395')
  end

  it "doesn't mess with non-integer ids" do
    expect(@weird.local_id).to eq('000034395weirdness')
  end
end

RSpec.describe Registry::SourceRecord, '#deprecate' do
  before(:each) do
    @rec = SourceRecord.first
  end

  after(:each) do
    @rec.unset(:deprecated_reason)
    @rec.unset(:deprecated_timestamp)
  end

  it 'adds a deprecated field' do
    @rec.deprecate('testing deprecation')
    expect(@rec.deprecated_reason).to eq('testing deprecation')
  end
end

RSpec.describe Registry::SourceRecord, '#add_to_registry' do
  # in theory none of this works if .delete_enumchron and .add_enumchron
  # don't work.
  # todo: test separately
  before(:all) do
    @old_rec = SourceRecord.new
    @old_rec.org_code = 'miaahdl'
    @old_rec.source = File.open(File.dirname(__FILE__) + '/data/ht_record_3_items.json').read
    @old_rec.save
    @old_ecs = @old_rec.enum_chrons

    @no_ec_rec = SourceRecord.new
    @no_ec_rec.org_code = 'miaahdl'
    @no_ec_rec.source = File.open(File.dirname(__FILE__) + '/data/ht_record_0_items.json').read
    @no_ec_rec.save

    @repl_rec = @old_rec
    @repl_rec.org_code = 'miaahdl'
    @repl_rec.source = File.open(File.dirname(__FILE__) + '/data/ht_record_different_3_items.json').read
    @repl_rec.save

    @new_rec = SourceRecord.new
    @new_rec.org_code = 'miaahdl'
    @new_rec.source = File.open(File.dirname(__FILE__) + '/data/ht_record_3_items.json').read
    @new_rec.local_id = (@old_rec.local_id.to_i + 1).to_s # just make sure we aren't clobbering
    @new_rec.save
  end

  after(:all) do
    RegistryRecord.where(:source_record_ids.in => [@old_rec.source_id,
                                                   @repl_rec.source_id,
                                                   @new_rec.source_id,
                                                   @no_ec_rec.source_id]).each(&:delete)
    @old_rec.delete
    @repl_rec.delete
    @new_rec.delete
    @no_ec_rec.delete
  end

  it 'SRs with no ECs still get added to Registry' do
    results = @no_ec_rec.add_to_registry
    expect(results[:num_new]).to eq(1)
    expect(results[:num_deleted]).to eq(0)
    num_in_reg = RegistryRecord.where(source_record_ids: @no_ec_rec.source_id,
                                      deprecated_timestamp: { "$exists": 0 }).count
    expect(num_in_reg).to be > 0
  end

  it 'deprecates old enum_chrons' do
    old_rec = SourceRecord.new(org_code: 'miaahdl',
                               source: File.open(File.dirname(__FILE__) + '/data/ht_record_3_items.json').read)
    old_rec.save
    old_ecs = old_rec.enum_chrons

    repl_rec = old_rec
    repl_rec.org_code = 'miaahdl'
    repl_rec.source = File.open(File.dirname(__FILE__) + '/data/ht_record_different_3_items.json').read
    repl_rec.save

    deleted_ecs = old_ecs - repl_rec.enum_chrons
    expect(deleted_ecs.count).to be > 0
    repl_rec.update_in_registry
    deleted_ecs.each do |ec|
      expect(RegistryRecord.where(source_record_ids: @old_rec.source_id,
                                  enum_chron: ec,
                                  deprecated_timestamp: { "$exists": 0 }).count).to eq(0)
    end
    RegistryRecord.where(:source_record_ids.in => [old_rec.source_id,
                                                   repl_rec.source_id]).each(&:delete)
    old_rec.delete
    repl_rec.delete
  end

  it 'adds new enum_chrons' do
    new_ecs = @repl_rec.enum_chrons - @old_ecs
    expect(new_ecs.count).to be > 0
    @repl_rec.update_in_registry
    expect(@repl_rec.source_id).to eq(@old_rec.source_id)
    new_ecs.each do |ec|
      expect(RegistryRecord.where(source_record_ids: @old_rec.source_id,
                                  enum_chron: ec,
                                  deprecated_timestamp: { "$exists": 0 }).count).to eq(1)
    end
  end

  it "update_in_registry doesn't do anything if nothing has changed" do
    orig_count = RegistryRecord.where(source_record_ids: @repl_rec.source_id).count
    results = @repl_rec.update_in_registry
    new_count = RegistryRecord.where(source_record_ids: @repl_rec.source_id).count
    expect(orig_count).to eq(new_count)
    expect(results[:num_new]).to eq(0)
    expect(results[:num_deleted]).to eq(0)
  end

  it 'adds new enum_chrons for new records' do
    results = @new_rec.add_to_registry
    @new_rec.enum_chrons.each do |ec|
      expect(RegistryRecord.where(source_record_ids: @new_rec.source_id,
                                  enum_chron: ec,
                                  deprecated_timestamp: { "$exists": 0 }).count).to eq(1)
    end
    expect(results[:num_new]).to eq(3)
  end
end

RSpec.describe Registry::SourceRecord, '#remove_from_registry' do
  before(:all) do
    @src_rec = SourceRecord.new
    @src_rec.org_code = 'miaahdl'
    @src_rec.source = File.open(File.dirname(__FILE__) + '/data/ht_record_3_items.json').read
    @src_rec.save
    @src_rec.add_to_registry 'testing removal'
    @second_src_rec = SourceRecord.new
    @second_src_rec.org_code = 'miaahdl'
    @second_src_rec.source = File.open(File.dirname(__FILE__) + '/data/ht_record_3_items.json').read
    @second_src_rec.local_id = (@second_src_rec.local_id.to_i + 1).to_s
    @second_src_rec.save
    @second_src_rec.add_to_registry 'testing removal'
  end

  after(:all) do
    RegistryRecord.where(source_record_ids: @src_rec.source_id).each(&:delete)
    RegistryRecord.where(source_record_ids: @second_src_rec.source_id).each(&:delete)
    @src_rec.delete
    @second_src_rec.delete
  end

  it 'deprecates registry records it was a member of' do
    expect(RegistryRecord.where(source_record_ids: [@src_rec.source_id,
                                                    @second_src_rec.source_id],
                                deprecated_timestamp: { "$exists": 0 }).count).to eq(3)
    num_removed = @src_rec.remove_from_registry
    expect(num_removed).to eq(3)
    expect(RegistryRecord.where(source_record_ids: [@src_rec.source_id,
                                                    @second_src_rec.source_id],
                                deprecated_timestamp: { "$exists": 0 }).count).to eq(0)
    expect(RegistryRecord.where(source_record_ids: [@src_rec.source_id],
                                deprecated_timestamp: { "$exists": 0 }).count).to eq(0)
    expect(RegistryRecord.where(source_record_ids: [@second_src_rec.source_id],
                                deprecated_timestamp: { "$exists": 0 }).count).to eq(3)
  end
end

RSpec.describe Registry::SourceRecord, '#ht_availability' do
  before(:all) do
    @non_ht_rec = SourceRecord.where(:org_code.ne => 'miaahdl').first
    @ht_pd = SourceRecord.new
    @ht_pd.org_code = 'miaahdl'
    @ht_pd.source = File.open(File.dirname(__FILE__) + '/data/ht_pd_record.json').read
    @ht_ic = SourceRecord.new
    @ht_ic.org_code = 'miaahdl'
    @ht_ic.source = File.open(File.dirname(__FILE__) + '/data/ht_ic_record.json').read
  end

  it 'detects correct HT availability' do
    expect(@non_ht_rec.ht_availability).to eq(nil)
    expect(@ht_pd.ht_availability).to eq('Full View')
    expect(@ht_ic.ht_availability).to eq('Limited View')
  end
end

RSpec.describe Registry::SourceRecord, 'extract_oclcs' do
  before(:all) do
    rec = File.open(File.dirname(__FILE__) + '/data/bogus_oclc.json').read
    @marc = MARC::Record.new_from_hash(JSON.parse(rec))
    @s = SourceRecord.new
    rec = File.open(File.dirname(__FILE__) + '/data/weird_oclcs.json').read
    @cou_marc = MARC::Record.new_from_hash(JSON.parse(rec))
  end

  it 'ignores out of range OCLCs' do
    expect(@s.extract_oclcs(@marc)).not_to include(155_503_032_044_020_955_233)
  end

  it 'removes incorrect oclcs' do
    @s.org_code = 'cou'
    expect(@s.extract_oclcs(@cou_marc)).not_to include(1_038_488)
  end
end

RSpec.describe Registry::SourceRecord, 'extract_sudocs' do
  before(:all) do
    bogus = File.open(File.dirname(__FILE__) + '/data/bogus_sudoc.json').read
    @marc_bogus = MARC::Record.new_from_hash(JSON.parse(bogus))
    legit = File.open(File.dirname(__FILE__) + '/data/legit_sudoc.json').read
    @marc_legit = MARC::Record.new_from_hash(JSON.parse(legit))
    non = File.open(File.dirname(__FILE__) + '/data/non_sudoc.json').read
    @marc_non = MARC::Record.new_from_hash(JSON.parse(non))
    fed_state = File.open(File.dirname(__FILE__) + '/data/fed_state_sudoc.json').read
    @marc_fs = MARC::Record.new_from_hash(JSON.parse(fed_state))
    mangled = File.open(File.dirname(__FILE__) + '/data/ht_pd_record.json').read
    @marc_mang = MARC::Record.new_from_hash(JSON.parse(mangled))
    caption = File.open(File.dirname(__FILE__) + '/data/sudoc_caption.json').read
    @sudoc_caption = MARC::Record.new_from_hash(JSON.parse(caption))
  end

  # not much we can do about it
  it 'accepts bogus SuDocs' do
    s = SourceRecord.new
    expect(s.extract_sudocs(@marc_bogus)).to eq(['XCPM 2.2:P 51 C 55/D/990'])
  end

  it 'extracts good ones' do
    s = SourceRecord.new
    expect(s.extract_sudocs(@marc_legit)).to eq(['L 37.22/2:97-B'])
    expect(s.extract_sudocs(@marc_fs)).to eq(['I 19.79:EC 7/OK/2005'])
  end

  it 'ignores Illinois docs' do
    s = SourceRecord.new
    ildoc = File.open(File.dirname(__FILE__) + '/data/il_doc.json').read
    ilmarc = MARC::Record.new_from_hash(JSON.parse(ildoc))
    expect(s.extract_sudocs(ilmarc)).not_to include('IL/DNR 52.9:')
    s.source = ildoc
    expect(s.fed_doc?).to eq(false)
  end

  it 'ignores non-SuDocs, uses non-SuDocs to filter out bogus' do
    s = SourceRecord.new
    s.extract_sudocs(@marc_non)
    # has identified the bogus ones
    expect(s.non_sudocs).to include('XCPM 2.2:P 51 C 55/D/990')
    # uses non-Sudocs to filter out bogus
    expect(s.sudocs).to eq([])
    expect(s.invalid_sudocs).to include('XCPM 2.2:P 51 C 55/D/990')

    s.extract_sudocs(@marc_fs)
    expect(s.non_sudocs).to include('W 1700.9 E 19 2005')
    expect(s.invalid_sudocs).to include('W 1700.9 E 19 2005')
  end

  it 'fixes mangled sudocs' do
    # e.g. "II0 aC 13.44:137"
    s = SourceRecord.new
    sudocs = s.extract_sudocs(@marc_mang)
    expect(s.sudocs).not_to include('II0 aC 13.44:137')
    expect(s.sudocs).to include('C 13.44:137')
  end

  it 'ignores SuDoc captions' do
    s = SourceRecord.new
    sudocs = s.extract_sudocs(@sudoc_caption)
    expect(s.sudocs).not_to include('I 19.81:(nos.-letters)/(ed.yr.)')
  end
end

RSpec.describe Registry::SourceRecord, 'remove_caption_sudocs' do
  before(:all) do
    caption = File.open(File.dirname(__FILE__) + '/data/sudoc_caption.json').read
    @sudoc_caption = MARC::Record.new_from_hash(JSON.parse(caption))
  end

  it 'removes caption sudocs from the sudoc list' do
    s = SourceRecord.new
    s.sudocs = ['I 19.81:(nos.-letters)/(ed.yr.)']
    s.non_sudocs = []
    s.remove_caption_sudocs
    expect(s.sudocs).to eq([])
    expect(s.non_sudocs).to eq(['I 19.81:(nos.-letters)/(ed.yr.)'])
  end
end

RSpec.describe Registry::SourceRecord, 'u_and_f?' do
  before(:all) do
    has_u_and_f = File.open(File.dirname(__FILE__) + '/data/has_u_and_f.json').read
    has_u_not_f = File.open(File.dirname(__FILE__) + '/data/has_u_not_f.json').read
    has_no_008 = File.open(File.dirname(__FILE__) + '/data/missing_008.json').read

    @u_and_f = SourceRecord.new(org_code: 'miu', source: has_u_and_f)
    @u_not_f = SourceRecord.new(org_code: 'miu', source: has_u_not_f)
    @no_008 = SourceRecord.new(org_code: 'miu', source: has_no_008)
  end

  it 'detects u and f' do
    expect(@u_and_f.u_and_f?).to be_truthy
    expect(@u_not_f.u_and_f?).to be_falsey
  end

  it 'returns false if there is no 008' do
    expect(@no_008.u_and_f?).to be_falsey
  end
end

RSpec.describe Registry::SourceRecord, 'fed_doc?' do
  before(:all) do
    # this file has both a Fed SuDoc and a state okdoc
    @fed_state = File.open(File.dirname(__FILE__) +
                      '/data/fed_state_sudoc.json').read
    @marc = MARC::Record.new_from_hash(JSON.parse(@fed_state))
    @innd = File.open(File.dirname(__FILE__) + '/data/innd_record.json').read
    @innd_marc = MARC::Record.new_from_hash(JSON.parse(@innd))
    has_u_and_f = File.open(File.dirname(__FILE__) + '/data/has_u_and_f.json').read
    @u_and_f = SourceRecord.new(org_code: 'miu', source: has_u_and_f)
  end

  it 'detects govdociness' do
    s = SourceRecord.new
    s.source = @fed_state
    expect(s.extract_sudocs(@marc).count).to be(1)
    expect(s.fed_doc?(@marc)).to be_truthy

    s = SourceRecord.new
    s.source = @innd
    expect(s.fed_doc?).to be_truthy
    expect(s.fed_doc?(@innd_marc)).to be_truthy
  end

  it 'uses u_and_f?' do
    expect(@u_and_f.fed_doc?).to be_truthy
  end

  it 'leverages OCLC blacklist' do
    bad_oclc = File.read(__dir__ + '/data/blacklisted_oclc.json').chomp
    s = SourceRecord.new
    s.source = bad_oclc
    expect(s.fed_doc?).to be false
  end

  it 'uses OCLC whitelist' do
    good_oclc = File.read(__dir__ + '/data/whitelisted_oclc.json').chomp
    s = SourceRecord.new
    s.source = good_oclc
    expect(s.fed_doc?).to be true
  end

  it 'uses the 074' do
    source = File.open(File.dirname(__FILE__) + '/data/074_govdoc.json').read
    s = SourceRecord.new
    s.source = source
    expect(s.gpo_item_numbers).to eq(['123'])
    expect(s.fed_doc?).to be true
    s.unset(:gpo_item_numbers)
    expect(s.gpo_item_numbers).to eq(['123'])
    s.save
    s_copy = SourceRecord.where(source_id: s.source_id).first
    s.delete
  end

  it "doesn't choke if there is no 074" do
    source = File.open(File.dirname(__FILE__) + '/data/no_074_nongovdoc.json').read
    s = SourceRecord.new
    s.source = source
    expect(s.gpo_item_numbers).to eq([])
    expect(s.fed_doc?).to be false
  end

  it 'uses the authority list' do
    ao = File.open(File.dirname(__FILE__) + '/data/auth_only.json').read
    auth_only = SourceRecord.new
    auth_only.org_code = 'miaahdl'
    auth_only.source = ao
    expect(auth_only.fed_doc?).to be_truthy
  end

  it 'uses approved added entry' do
    s = SourceRecord.new(
      org_code: 'miaahdl',
      source: File.open(File.dirname(__FILE__) + '/data/added_entry_gd.json').read
    )
    expect(s.fed_doc?).to be_truthy
  end

  it 'uses publisher headings' do
    s = SourceRecord.new(
      org_code: 'miaahdl',
      source: File.open(File.dirname(__FILE__) + '/data/oak_ridge_rec.json').read
    )
    expect(s.fed_doc?).to be(true)
  end

  it 'returns true/false not 0 or nil' do
    gd = SourceRecord.new
    gd.org_code = 'miaahdl'
    gd.source = File.open(File.dirname(__FILE__) + '/data/ht_pd_record.json').read
    expect(gd.fed_doc?).to be(true)
    expect(gd.fed_doc?).to_not be(0)
  end
end

RSpec.describe Registry::SourceRecord, '#extract_identifiers' do
  before(:all) do
    SourceRecord.where(:source.exists => false).delete
  end

  it "doesn't change identifiers" do
    count = 0
    SourceRecord.all.each do |rec|
      count += 1
      break if count > 20 # arbitrary

      old_oclc_alleged = rec.oclc_alleged
      old_lccn = rec.lccn_normalized
      old_issn = rec.issn_normalized
      old_isbn = rec.isbns_normalized
      rec.extract_identifiers
      expect(old_oclc_alleged - rec.oclc_alleged).to eq([])
      expect(old_lccn - rec.lccn_normalized).to eq([])
      expect(old_issn - rec.issn_normalized).to eq([])
      expect(old_isbn - rec.isbns_normalized).to eq([])
    end
  end
end

RSpec.describe Registry::SourceRecord, '#isbns' do
  before(:all) do
    @src = SourceRecord.new(
      org_code: 'miaahdl',
      source: File.open(File.dirname(__FILE__) + '/data/src_with_isbn.json').read
    )
  end

  it 'extracts the isbns' do
    expect(@src.isbns_normalized).to eq(['9780801811449'])
  end

  it 'uniqs isbns when reextracting' do
    @src.source = File.open(
      File.dirname(__FILE__) + '/data/src_with_isbn.json'
    ).read
    expect(@src.isbns_normalized).to eq(['9780801811449'])
  end
end

RSpec.describe Registry::SourceRecord, '#marc_profiles' do
  it 'loads marc profiles' do
    expect(SourceRecord.marc_profiles['dgpo']).to be_truthy
    expect(SourceRecord.marc_profiles['dgpo']['enum_chrons']).to eq('930 h')
  end
end

RSpec.describe Registry::SourceRecord, '#extract_enum_chrons' do
  it 'extracts enum chrons from GPO records' do
    line = File.open(File.dirname(__FILE__) + '/data/default_gpo_record.json').read
    src = SourceRecord.new
    src.org_code = 'dgpo'
    src.source = line
    expect(
      src.extract_enum_chrons.collect { |_k, ec| ec['string'] }
    ).to eq(['V. 1', 'V. 2'])
  end

  it 'extracts enum chrons from non-GPO records' do
    sr = SourceRecord.where(oclc_resolved: 1_768_512,
                            org_code: { "$ne": 'miaahdl' },
                            enum_chrons: /V. \d/).first
    line = sr.source.to_json
    sr_new = SourceRecord.new(org_code: 'miu')
    sr_new.series = ['Federal Register']
    sr_new.source = line
    expect(sr_new.series).to include('Federal Register')
    expect(sr_new.enum_chrons).to include('Volume:77, Number:67')
    expect(sr_new.org_code).to eq('miu')
  end

  it 'properly extracts enumchrons for series' do
    sr = SourceRecord.new
    sr.org_code = 'miaahdl'
    sr.source = File.open(File.dirname(__FILE__) +
                     '/series/data/econreport.json').read
    expect(sr.series).to eq(['Economic Report of the President'])
    expect(sr.enum_chrons).to include('Year:1966, Part:3')
  end

  it 'doesnt clobber enumchron features' do
    sr = SourceRecord.new
    sr.org_code = 'miaahdl'
    sr.source = File.open(File.dirname(__FILE__) +
                     '/series/data/statabstract_multiple_ecs.json').read
    expect(sr.enum_chrons).to include('Edition:1, Year:1878')
  end

  it 'returns [""] for records without enum_chrons, with series' do
    sr = SourceRecord.new
    sr.org_code = 'miaahdl'
    sr.source = File.open(File.dirname(__FILE__) +
                     '/series/data/econreport_no_enums.json').read
    expect(sr.enum_chrons.count).to eq(1)
    expect(sr.enum_chrons[0]).to eq('')
  end

  it 'returns [""] for records without enum_chrons, without series' do
    sr = SourceRecord.new
    sr.org_code = 'miaahdl'
    sr.source = File.open(File.dirname(__FILE__) +
                     '/data/no_enums_no_series_src.json').read
    expect(sr.enum_chrons.count).to eq(1)
    expect(sr.enum_chrons[0]).to eq('')
  end

  it 'creates strings if miaahdl 974 is missing subfield z' do
    src = SourceRecord.new
    src.source = File.open(File.dirname(__FILE__) + '/data/multi_holding.json').read
    expect(src.extract_enum_chron_strings.count).to eq(2)
    expect(src.ec.count).to eq(2)
  end

  it 'has the same number of htitemids as holdings' do
    src = SourceRecord.new
    src.source = File.open(File.dirname(__FILE__) + '/data/multi_holding_same_canon.json').read
    expect(src.ht_item_ids.count).to eq(src.holdings.count)
    expect(src.ht_item_ids.first).to eq('uc1.l0079982559')
  end

  #   it "hasn't changed since last extraction" do
  #     SourceRecord.where(deprecated_timestamp:{"$exists":0}).no_timeout.each do |src|
  #       if src.enum_chrons.include? 'INDEX:V. 58-59 YR. 1993-1994'
  #         src.source = src.source.to_json
  #         src.save
  #       end
  #       old_enum_chrons = src.enum_chrons
  #       src.source = src.source.to_json
  #       expect(old_enum_chrons).to eq(src.enum_chrons)
  #     end
  #   end
end

RSpec.describe Registry::SourceRecord, '#extract_enum_chron_strings' do
  it 'extracts enum chron strings from MARC records' do
    sr = SourceRecord.where(sudocs: 'II0 aLC 4.7:T 12/v.1-6').first
    expect(sr.extract_enum_chron_strings).to include('V. 6')
  end

  it 'ignores contributors without enum chrons' do
    sr = SourceRecord.where(sudocs: 'Y 4.P 84/11:AG 8', org_code: 'cic').first
    expect(sr.extract_enum_chron_strings).to eq([])
  end

  it 'properly extracts enumchron strings for series' do
    sr = SourceRecord.new
    sr.org_code = 'miaahdl'
    sr.source = File.open(File.dirname(__FILE__) +
                     '/series/data/econreport.json').read
    expect(sr.extract_enum_chron_strings).to include('PT. 1-4')
  end

  it 'handles DGPO records appropriately' do
    sr = SourceRecord.new
    sr.org_code = 'dgpo'
    sr.source = File.open(File.dirname(__FILE__) + '/data/dgpo_has_ecs.json').read
    expect(sr.extract_enum_chron_strings).to include('V. 31:NO. 3(2004:JULY)')
  end

  it 'filters out some bogus enum chrons' do
    sr = SourceRecord.new
    sr.org_code = 'vifgm'
    sr.source = File.open(File.dirname(__FILE__) +
                     '/data/vifgm_1959_december.json').read
    expect(sr.extract_enum_chron_strings).to eq([])
  end

  it 'filters out enum chrons that are actually sudocs' do
    sr = SourceRecord.new
    sr.org_code = 'flasus'
    sr.source = File.open(File.dirname(__FILE__) + '/data/sudoc_enumchron.json').read
    expect(sr.extract_enum_chron_strings).to eq([])
  end

  it 'creates strings if miaahdl 974 is missing subfield z' do
    src = SourceRecord.new
    src.source = File.open(File.dirname(__FILE__) + '/data/multi_holding.json').read
    expect(src.extract_enum_chron_strings.count).to eq(2)
  end
end

RSpec.describe Registry::SourceRecord, '#holdings' do
  before(:all) do
    @src = SourceRecord.where(source_id: 'ec1b9145-7e88-4774-a35d-4e9639ec8a7b').first
  end

  it 'transforms 974s into a holdings field' do
    dig = Digest::SHA256.hexdigest('mdp.39015034759749')
    expect(@src.holdings.keys).to include(dig)
    expect(@src.ht_item_ids).to include('mdp.39015034759749')
  end

  it 'has holdings that match enum chrons' do
    @src.ec = @src.extract_enum_chrons
    strings_in_holdings = @src.holdings.collect { |_k, h| h[:enum_chrons] }.flatten.sort.uniq
    expect(@src.enum_chrons.sort.uniq).to eq(strings_in_holdings.flatten.sort.uniq)
  end

  it 'removes deleted items from ht_item_ids' do
    src_with_deleted_item = SourceRecord.new(org_code: 'miaahdl')
    src_with_deleted_item.source = File.open(
      File.dirname(__FILE__) + '/data/htdl_rec_with_removed_item.json'
    ).read
    expect(src_with_deleted_item.ht_item_ids).not_to include('mdp.39015001559569')
  end

  it 'creates a holdings for items without enumchrons' do
    src = SourceRecord.new
    src.source = File.open(File.dirname(__FILE__) + '/data/miaahdl_no_enum_chron.json').read
    expect(src.holdings.keys).to include(Digest::SHA256.hexdigest('uiug.30112060127294'))
  end

  it 'creates holdings for every item even if missing a subfield z' do
    src = SourceRecord.new
    src.source = File.open(File.dirname(__FILE__) + '/data/multi_holding.json').read
    expect(src.holdings.keys.count).to eq(2)
  end
end

RSpec.describe Registry::SourceRecord, '#monograph' do
  it 'identifies a monograph' do
    src = SourceRecord.new
    src.source = File.open(File.dirname(__FILE__) + '/data/no_enums_no_series_src.json').read
    expect(src.monograph?).to be_truthy
  end

  it 'identifies a non-monograph' do
    src = SourceRecord.new
    src.source = File.open(File.dirname(__FILE__) + '/series/data/statabstract_multiple_ecs.json').read
    expect(src.monograph?).to be_falsey
  end
end

describe Registry::SourceRecord, 'source' do
  before(:each) do
    @src = SourceRecord.new
    @src.source = File.open(File.dirname(__FILE__) + '/series/data/usreport.json').read
  end

  it 'properly extracts US Reports' do
    expect(@src.enum_chrons.count).to be > 20
  end

  it 'saves the series information' do
    expect(@src.series).to include('United States Reports')
    @src.save
    diffsrc = SourceRecord.where(source_id: @src.source_id).first
    expect(diffsrc.attributes[:series]).to include('United States Reports')
    expect(diffsrc['series']).to include('United States Reports')
  end

  after(:each) do
    @src.delete
  end
end

RSpec.describe Registry::SourceRecord, '#parse_ec' do
  before(:all) do
    @src = SourceRecord.new
  end

  xit 'can parse them all' do
    matches = 0
    misses = 0
    input = File.dirname(__FILE__) + '/series/data/ec_strings_2018-07-19.txt'
    File.open(input, 'r').each do |line|
      ec_string = line.chomp

      ec = @src.parse_ec(ec_string)
      if ec.nil? || ec.empty?
        misses += 1
        puts line.chomp
        # puts 'no match: '+line
      else
        matches += 1
      end
    end
    puts "Default Mono Parsing Record match: #{matches}"
    puts "Default Mono Parsing Record no match: #{misses}"
    expect(matches).to eq(matches + misses)
  end

  # Volume
  it 'can parse volumes' do
    expect(@src.parse_ec('V. 1')['volume']).to eq('1')
    expect(@src.parse_ec('V.1')['volume']).to eq('1')
    expect(@src.parse_ec('V1')['volume']).to eq('1')
    expect(@src.parse_ec('V 1')['volume']).to eq('1')
    expect(@src.parse_ec('V. 001')['volume']).to eq('1')
    # this is too ambitious for us right now
    expect(@src.parse_ec('1')['volume']).to eq('1')
    expect(@src.parse_ec('001')['volume']).to eq('1')
    expect(@src.parse_ec('Volume:1')['volume']).to eq('1')
    expect(@src.parse_ec('0')).to be_nil
  end

  it "can't parse things that only look like volumes" do
    expect(@src.parse_ec('NOV. 1')).to be_nil
  end

  # Number
  it 'can parse numbers' do
    expect(@src.parse_ec('NO. 1')['number']).to eq('1')
    expect(@src.parse_ec('NO.1')['number']).to eq('1')
    expect(@src.parse_ec('NO1')['number']).to eq('1')
    expect(@src.parse_ec('NO 1')['number']).to eq('1')
    expect(@src.parse_ec('NO. 001')['number']).to eq('1')
    expect(@src.parse_ec('NO001')['number']).to eq('1')
    expect(@src.parse_ec('Number:1')['number']).to eq('1')
  end

  it "can't parse things that only look like numbers" do
    expect(@src.parse_ec('NOTANO1')).to be_nil
  end

  # Part
  it 'can parse parts' do
    expect(@src.parse_ec('PT. 1')['part']).to eq('1')
    expect(@src.parse_ec('PT.1')['part']).to eq('1')
    expect(@src.parse_ec('PT1')['part']).to eq('1')
    expect(@src.parse_ec('PT 1')['part']).to eq('1')
    expect(@src.parse_ec('PT. 001')['part']).to eq('1')
    expect(@src.parse_ec('PT001')['part']).to eq('1')
    expect(@src.parse_ec('Part:1')['part']).to eq('1')
  end

  it "can't parse things that only look like part" do
    expect(@src.parse_ec('NOTAPT')).to be_nil
  end

  # Year
  it 'can parse years' do
    expect(@src.parse_ec('983')['year']).to eq('1983')
    expect(@src.parse_ec('1983')['year']).to eq('1983')
    expect(@src.parse_ec('Year:1983')['year']).to eq('1983')
  end

  it "can't parse things that only look like a year" do
    expect(@src.parse_ec('NOTAYEAR: 1983')).to be_nil
    expect(@src.parse_ec('0704')).to be_nil
    expect(@src.parse_ec('2573')).to be_nil
    expect(@src.parse_ec('1600')).to be_nil
    expect(@src.parse_ec('2573')).to be_nil
  end

  # Book
  it 'can parse books' do
    expect(@src.parse_ec('BK. 4')['book']).to eq('4')
    expect(@src.parse_ec('BOOK 4')['book']).to eq('4')
    expect(@src.parse_ec('Book:4')['book']).to eq('4')
  end

  # Sheet
  it 'can parse sheets' do
    expect(@src.parse_ec('SHEET. 4')['sheet']).to eq('4')
    expect(@src.parse_ec('SHEET 4')['sheet']).to eq('4')
    expect(@src.parse_ec('Sheet:4')['sheet']).to eq('4')
  end

  # Month
  it 'can parse months' do
    expect(@src.parse_ec('OCT.')['month']).to eq('October')
  end

  # Year:, Part:
  it 'can parse Year:<y>, Part:<p>' do
    expect(@src.parse_ec('Year:2001, Part:2')['part']).to eq('2')
  end

  # Volume/Year
  it "can parse Volume/Year: 'V. 3(1974)'" do
    expect(@src.parse_ec('V. 3(1974)')['year']).to eq('1974')
    expect(@src.parse_ec('Year:1974, Volume:3')['year']).to eq('1974')
  end

  # Volume/Number
  it "can parse Volume/Number: 'V. 3, NO. 2'" do
    expect(@src.parse_ec('V. 3, NO. 2')['number']).to eq('2')
  end

  after(:all) do
    @src.delete
  end
end

RSpec.describe Registry::SourceRecord, '#explode' do
  it 'does nothing' do
    parsed = SourceRecord.new.parse_ec('1978')
    expect(SourceRecord.new.explode(parsed).count).to eq(1)
  end
end

RSpec.describe Registry::SourceRecord, '#canonicalize' do
  it "returns nil if ec can't be parsed" do
    expect(SourceRecord.new.canonicalize({})).to be_nil
  end

  # Year:<year>, Volume:<volume>, Part:<part>, Number:<number>
  it 'turns a parsed ec into a canonical string' do
    ec = { 'number' => '2',
           'volume' => '3',
           'year' => '1956' }
    expect(SourceRecord.new.canonicalize(ec)).to eq('Year:1956, Volume:3, Number:2')
  end
end

RSpec.describe Registry::SourceRecord, '#fix_flasus' do
  it 'fixes the 955 for flasus' do
    source = File.open(File.dirname(__FILE__) + '/data/flasus_rec.json').read
    expect(source).to match(/"955"\s?:.*"v\.1"\s?:\s?""/)
    src = SourceRecord.new
    fixed = src.fix_flasus('flasus', JSON.parse(source))
    expect(fixed.to_json).to match(/"955"\s?:.*"v"\s?:\s?"v\.1"/)

    # should be called in source=
    src.org_code = 'flasus'
    src.source = source
    expect(src.enum_chrons).to include('Volume:1')
  end

  it 'fixes all fields for flasus' do
    source = File.open(File.dirname(__FILE__) + '/data/flasus_garbage.json').read
    src = SourceRecord.new
    fixed = src.fix_flasus('flasus', JSON.parse(source))
    expect(fixed.to_json).to match(/"dollar":/)
  end
end

RSpec.describe Registry::SourceRecord, '#lccn_normalized' do
  it 'handles bad prefixes in lccns' do
    sr = SourceRecord.new(org_code: 'miaahdl',
                          source: File.open(File.dirname(__FILE__) + '/data/bad_identifiers.json').read)
    expect(sr.lccn_normalized).to eq(['2004394700'])
  end
end

RSpec.describe Registry::SourceRecord, '#issn_normalized' do
  it 'returns [] if garbage issns' do
    sr = SourceRecord.new(org_code: 'miaahdl',
                          source: File.open(File.dirname(__FILE__) + '/data/bad_identifiers.json').read)
    expect(sr.issn_normalized).to eq([])
  end
end

RSpec.describe Registry::SourceRecord, '#approved_author?' do
  before(:all) do
    @src = SourceRecord.new
    @src.org_code = 'miaahdl'
    @src.source = File.open(File.dirname(__FILE__) + '/data/author_gd.json').read
  end

  it 'tells us it has an approved author' do
    expect(@src.approved_author?).to be_truthy
  end
end

RSpec.describe Registry::SourceRecord, '#approved_added_entry?' do
  before(:all) do
    @src = SourceRecord.new
    @src.org_code = 'miaahdl'
    @src.source = File.open(File.dirname(__FILE__) + '/data/added_entry_gd.json').read
  end

  it 'tells us it has an approved added entry author' do
    expect(@src.approved_added_entry?).to be_truthy
  end
end

# We can detect all of the series
RSpec.describe Registry::SourceRecord, '#series' do
  before(:each) do
    @src = SourceRecord.new
  end

  it 'detects Cancer Treatment Reports' do
    @src.org_code = 'miaahdl'
    @src.source = File.open(File.dirname(__FILE__) + '/series/data/ctr.json').read
    expect(@src.series).to eq(['Cancer Treatment Report'])
  end

  it 'detects Vital Statistics' do
    @src.source = File.open(File.dirname(__FILE__) +
                       '/series/data/vital_statistics.json').read
    expect(@src.series).to eq(['Vital Statistics'])
  end

  it 'detects PublicPapers' do
    @src.source = File.open(File.dirname(__FILE__) +
                       '/series/data/public_papers.json').read
    expect(@src.series).to eq(['Public Papers of the Presidents'])
  end

  it 'detects DAGLs' do
    @src.source = File.open(File.dirname(__FILE__) +
                       '/series/data/dept_agr_leaflet.json').read
    expect(@src.series).to eq(['Department of Agriculture Leaflet'])
  end

  it 'detects PHRs' do
    @src.source = File.open(File.dirname(__FILE__) +
                       '/series/data/public_health_report.json').read
    expect(@src.series).to eq(['Public Health Reports'])
  end

  it 'detects CMs' do
    expect(ECMangle.available_ec_manglers.count).to eq(39)
    @src.source = File.open(File.dirname(__FILE__) +
                       '/series/data/census_manufactures.json').read
    expect(@src.series).to eq(['Census of Manufactures'])
  end

  it 'detects US Exports' do
    @src.source = File.open(File.dirname(__FILE__) +
                       '/series/data/us_exports.json').read
    expect(@src.series).to eq(['U.S. Exports'])
  end

  it 'detects SEC News Digest' do
    @src.source = File.open(File.dirname(__FILE__) +
                            '/series/data/sec_news_digest.json').read
    expect(@src.series).to eq(['SEC News Digest'])
  end

  after(:each) do
    @src.delete
  end
end

RSpec.describe Registry::SourceRecord, '#marc' do
  it 'creates a MARC attribute from source' do
    source = File.open(File.dirname(__FILE__) + '/series/data/ctr.json').read
    s = SourceRecord.new(org_code: 'miaahdl', source: source)
    expect(s.marc['008']).to_not be_nil
  end

  it 'creates a MARC attribute from a saved source' do
    source = File.open(File.dirname(__FILE__) + '/series/data/ctr.json').read
    s = SourceRecord.new(org_code: 'miaahdl', source: source)
    s.save
    existing_src = SourceRecord.where(source_id: s.source_id).first
    expect(existing_src.marc['008']).to_not be_nil
    s.delete
  end
end

RSpec.describe Registry::SourceRecord, '#marcive_ids' do
  it 'extracts marcive ids from source' do
    source = File.open(File.dirname(__FILE__) + '/data/marcive.json').read
    s = SourceRecord.new(org_code: 'miaahdl', source: source)
    expect(s.marcive_ids).to eq([92_119_030])
  end
end
