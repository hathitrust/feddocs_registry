require 'foreign_relations'
require 'json'

describe "parse_ec" do
  it "parses V. 4 1939" do
    expect(ForeignRelations.parse_ec('V. 4 1939')['volume']).to eq('4')
  end

  it "parses '1969-76:V. 14'" do
    expect(ForeignRelations.parse_ec('1969-76:V. 14')['volume']).to eq('14')
  end

  it "parses '948/V. 1:PT. 1'" do
    expect(ForeignRelations.parse_ec('948/V. 1:PT. 1')['year']).to eq('1948')
  end


end

describe "explode" do
end

describe "parse_file" do
  it "parses a file of enumchrons" do 
    match, no_match = ForeignRelations.parse_file
    expect(match).to eq(5050) #actual number in test file is 5050
  end
end

describe "sudoc_stem" do 
  it "has a sudoc_stem field" do 
    expect(ForeignRelations.sudoc_stem).to eq('S 1.1:')
  end
end

describe "oclcs" do
  it "has an oclcs field" do
    #expect(UnitedStatesReports.oclcs).to include(10648533)
  end
end
