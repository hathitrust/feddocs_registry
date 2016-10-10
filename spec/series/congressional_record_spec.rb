require 'json'

CongressionalRecord = Registry::Series::CongressionalRecord

describe "parse_ec" do


end

describe "explode" do
end

describe "parse_file" do
  it "parses a file of enumchrons" do 
    #match, no_match = StatisticalAbstract.parse_file
    #expect(match).to eq(1566) #actual number in test file is 1566
  end
end

describe "sudoc_stem" do 
  it "has a sudoc_stem field" do 
    expect(CongressionalRecord.sudoc_stem).to eq('X 1.1:')
  end
end

describe "oclcs" do
  it "has an oclcs field" do
    #expect(UnitedStatesReports.oclcs).to include(10648533)
  end
end
