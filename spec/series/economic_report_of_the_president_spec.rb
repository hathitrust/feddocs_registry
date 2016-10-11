require 'json'

ER = Registry::Series::EconomicReportOfThePresident
describe "parse_ec" do
  it "parses a simple year" do
    expect(ER.parse_ec('1964')['year']).to eq('1964')
  end

  it "parses a year with part" do
    expect(ER.parse_ec('1964 PT. 4')['year']).to eq('1964')
    expect(ER.parse_ec('1964 PT. 4')['part']).to eq('4')
  end
  
  it "parses a year with multiple parts" do
    expect(ER.parse_ec('1964 PT. 1-3')['end_part']).to eq('3')
  end

  it "parses multi-years" do
    expect(ER.parse_ec('1961-1962')['end_year']).to eq('1962')
  end
end

describe "explode" do
  it "handles a simple year" do 
    expect(ER.explode(ER.parse_ec('1960'), {})).to have_key('Year: 1960')
  end

  it "explodes parts" do
    expect(ER.explode(ER.parse_ec('1966 PT. 1-4'), {})).to have_key('Year: 1966, Part: 3')
  end

  it "explodes years" do
    expect(ER.explode(ER.parse_ec('1949-1952'), {})).to have_key('Year: 1951')
  end

  it "uses pub_date/sudocs to create a better enum_chron" do
    # this records enum_Chron is 'PT. 2' but has a pub_Date of 1975
    sr = SourceRecord.new
    sr.org_code = "miaahdl"
    sr.source = open(File.dirname(__FILE__)+'/data/econreport_src_pub_date.json').read
    expect(sr.enum_chrons).to include('Year: 1975, Part: 2')
  end
end

describe "parse_file" do
  it "parses a file of enumchrons" do 
    match, no_match = ER.parse_file
    expect(match).to eq(74) #actual number in test file is 89
  end
end

describe "load_context" do
  it "has a hash of years => parts" do
    expect(ER.parts['1975']).to include('3')
  end
end
  

describe "sudoc_stem" do 
  it "has a sudoc_stem field" do 
    expect(ER.sudoc_stem).to eq('Y 4.EC 7:EC 7/2/')
  end
end

describe "oclcs" do
  it "has an oclcs field" do
    expect(ER.oclcs).to eq([3160302, 8762269, 8762232])
  end
end
