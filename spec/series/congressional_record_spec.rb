require 'json'

CR = Registry::Series::CongressionalRecord

describe "parse_ec" do
  it "can parse them all" do 
    matches = 0
    misses = 0
    input = File.dirname(__FILE__)+'/data/congressional_record_enumchrons.txt'
    open(input, 'r').each do |line|
      line.chomp!
      ec = CR.parse_ec(line)
      if ec.nil? or ec.length == 0
        misses += 1
        puts "no match: "+line
      else 
        matches += 1
      end
    end

    puts "Congressional Record match: #{matches}"
    puts "Congressional Record no match: #{misses}"
    expect(matches).to eq(matches+misses)
  end
  
  it "parses it's canonical version" do
    expect(CR.parse_ec('Volume:105, Part:20')['volume']).to eq('105')
  end
  
  it "parses 'V. 105 PT. 35'" do
    expect(CR.parse_ec('V. 105 PT. 35')['volume']).to eq('105')
  end

  it "parses 'V. 98,PT. 5 1952'" do
    expect(CR.parse_ec('V. 98,PT. 5 1952')['part']).to eq('5')
  end

  it "parses 'V. 97:15 (1951)'" do
    expect(CR.parse_ec('V. 97:15 (1951)')['part']).to eq('15')
  end

  it "parses 'V. 155:PT. 26(2009)'" do
    expect(CR.parse_ec('V. 155:PT. 26(2009)')['volume']).to eq('155')
    expect(CR.parse_ec('V. 155:PT. 26(2009)')['year']).to eq('2009')
  end

  it "parses 'V. 152:PT. 16(2006:SEPT. 29)'" do
    expect(CR.parse_ec('V. 155:PT. 16(2006:SEPT. 29)')['year']).to eq('2006')
  end

  it "parses 'V. 129:PT. 2 1983:FEB. 2-22'" do
    expect(CR.parse_ec('V. 129:PT. 2 1983:FEB. 2-22')['year']).to eq('1983')
  end
  it "parses 'V. 152:PT. 16(2006:SEPT. 29)'" do
    expect(CR.parse_ec('V. 155:PT. 16(2006:SEPT. 29)')['year']).to eq('2006')
  end

  it "parses '64/1:53/PT. 1'" do
    expect(CR.parse_ec('64/1:53/PT. 1')['volume']).to eq('53')
  end

  it "parses '102/1-137/PT. 26'" do
    expect(CR.parse_ec('102/1-137/PT. 26')['volume']).to eq('137')
  end

  it "parses '101/1:129/PT. 15'" do
    expect(CR.parse_ec('101/1:129/PT. 15')['volume']).to eq('129')
  end

  it "can NOT parse '108/PT. 17'" do
    expect(CR.parse_ec('108/PT. 17')).to be_nil
  end

end

describe "explode" do
end

describe "parse_file" do
  it "parses a file of enumchrons" do 
    #match, no_match = CR.parse_file
    #expect(match).to eq(1566) #actual number in test file is 1566
  end
end

describe "sudoc_stem" do 
  it "has a sudoc_stem field" do 
    expect(CR.sudoc_stem).to eq('X 1.1:')
  end
end

describe "oclcs" do
  it "has an oclcs field" do
    #expect(UnitedStatesReports.oclcs).to include(10648533)
  end
end
