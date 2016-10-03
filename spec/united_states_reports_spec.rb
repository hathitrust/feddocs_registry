require 'united_states_reports'
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

describe "oclcs" do
  it "has an oclcs field" do
    expect(UnitedStatesReports.oclcs).to include(10648533)
  end
end
