require 'json'

ER = Registry::Series::EconomicReportOfThePresident
describe "parse_ec" do
end

describe "explode" do
end

describe "parse_file" do
  it "parses a file of enumchrons" do 
    match, no_match = ER.parse_file
    expect(match).to eq(89) #actual number in test file is 89
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
