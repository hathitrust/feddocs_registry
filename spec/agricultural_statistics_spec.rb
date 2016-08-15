require 'agricultural_statistics'
require 'json'

describe "parse_ec" do

end

describe "explode" do

end

describe "parse_file" do
  it "parses a file of enumchrons" do 
    match, no_match = AgriculturalStatistics.parse_file
    expect(match).to be(367)
  end
end

describe "oclcs" do
  it "has an oclcs field" do
    expect(AgriculturalStatistics.oclcs).to include(1773189)
  end
end
