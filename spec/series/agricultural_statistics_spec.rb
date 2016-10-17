require 'registry/series/agricultural_statistics'
require 'json'
AgriculturalStatistics = Registry::Series::AgriculturalStatistics

describe "parse_ec" do
  it "parses '2002 1 CD WITH CASE IN BINDER.'" do
    expect(AgriculturalStatistics.parse_ec('2002 1 CD WITH CASE IN BINDER.')).to be_truthy
    expect(AgriculturalStatistics.parse_ec('2002 1 CD WITH CASE IN BINDER.')['year']).to eq('2002')
  end

  it "parses '989-990'" do
    expect(AgriculturalStatistics.parse_ec('989-990')['start_year']).to eq('1989')
    expect(AgriculturalStatistics.parse_ec('989-990')['end_year']).to eq('1990')
  end

  it "hangs onto '1946, 1948' for explode" do
    expect(AgriculturalStatistics.parse_ec('1946, 1948, 1950')['multi_year_comma']).to eq('1946, 1948, 1950')
  end
end

describe "explode" do
  it "creates a single enumchron" do
    expect(AgriculturalStatistics.explode(AgriculturalStatistics.parse_ec('V. 2002')).count).to eq(1)
  end

  it "fills in gaps" do
    expect(AgriculturalStatistics.explode(AgriculturalStatistics.parse_ec('989-90')).count).to eq(2)
    expect(AgriculturalStatistics.explode(AgriculturalStatistics.parse_ec('989-90'))).to have_key('1990')
  end

  it "handles special cases" do
    expect(AgriculturalStatistics.explode(AgriculturalStatistics.parse_ec('1944, 1946, 1948')).count).to eq(3)
    expect(AgriculturalStatistics.explode(AgriculturalStatistics.parse_ec('1944, 1946, 1948'))).to have_key('1946')
    expect(AgriculturalStatistics.explode(AgriculturalStatistics.parse_ec('1995/1996-1997')).count).to eq(2)
    expect(AgriculturalStatistics.explode(AgriculturalStatistics.parse_ec('1995/1996-1997'))).to have_key('1995-1996')
    expect(AgriculturalStatistics.explode(AgriculturalStatistics.parse_ec('1995/1996-1997'))).to have_key('1997')
  end

end

describe "parse_file" do
  it "parses a file of enumchrons" do 
    #match, no_match = AgriculturalStatistics.parse_file
    #expect(match).to be(361) #actual number in test file is 367
  end
end

describe "oclcs" do
  it "has an oclcs field" do
    expect(AgriculturalStatistics.oclcs).to include(1773189)
  end
end
