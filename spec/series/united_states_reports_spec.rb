require 'json'

USR = Registry::Series::UnitedStatesReports

describe "parse_ec" do


end

describe "explode" do
end

describe "parse_file" do
  it "parses a file of enumchrons" do 
    match, no_match = USR.parse_file
    #expect(match).to eq(1566) #actual number in test file is 1566
  end
end

describe "sudoc_stem" do
  it "has an sudoc_stem field" do
    expect(USR.sudoc_stem).to eq('JU 6.8')
  end
end

describe "oclcs" do
  it "has an oclcs field" do
    expect(USR.oclcs).to include(10648533)
  end
end
