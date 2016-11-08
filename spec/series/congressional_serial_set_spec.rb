require 'json'

CSS = Registry::Series::CongressionalSerialSet

describe "parse_ec" do


end

describe "explode" do
  it "returns the serial number if given only a serial number" do
    expect(CSS.explode(CSS.parse_ec("12345")).keys[0]).to eq("Serial Number:12345")
  end
end

describe "parse_file" do
  it "parses a file of enumchrons" do 
    match, no_match = CSS.parse_file
    expect(match).to be > 50000
    #expect(match).to eq(62963) #actual number in test file is 62963
  end
end

describe "sudoc_stem" do 
  it "has a sudoc_stem field" do 
    expect(CSS.sudoc_stem).to eq('Y 1.1/2:')
  end
end

describe "oclcs" do
  it "has an oclcs field" do
    #expect(UnitedStatesReports.oclcs).to include(10648533)
  end
end
