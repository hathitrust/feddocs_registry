require 'source_record'
require 'json'

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
    expect(EconomicReportOfThePresident.sudoc_stem).to eq('Y 4.EC 7:EC 7/2/')
  end
end

describe "oclcs" do
  it "has an oclcs field" do
    expect(EconomicReportOfThePresident.oclcs).to eq([3160302, 8762269, 8762232])
  end
end
