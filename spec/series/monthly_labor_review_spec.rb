require 'json'

MLR = Registry::Series::MonthlyLaborReview

describe "parse_ec" do
  it "can parse them all" do 
    matches = 0
    misses = 0
    input = File.dirname(__FILE__)+'/data/monthly_labor_review_enumchrons.txt'
    open(input, 'r').each do |line|
      line.chomp!
      ec = MLR.parse_ec(line)
      if ec.nil? or ec.length == 0
        misses += 1
        puts "no match: "+line
      else
        matches += 1
      end
    end
    puts "MLR Record match: #{matches}"
    puts "MLR Record no match: #{misses}"
    expect(matches).to eq(matches+misses)
  end

  it "parses '96 1973:JAN. -JUNE'" do
    expect(MLR.parse_ec('96 1973:JAN. -JUNE')['volume']).to eq('96')
  end

  it "parses 'V. 125:NO. 1/6 (2002:JAN. /JUNE)'" do
    expect(MLR.parse_ec('V. 125:NO. 1/6 (2002:JAN. /JUNE)')['volume']).to eq('125')
  end
  
  it "parses 'V. 127 NO. 1-3 2004 JAN-MAR'" do 
    expect(MLR.parse_ec('V. 127 NO. 1-3 2004 JAN-MAR')['volume']).to eq('127')
  end

  it "parses V. 100 NO. 1-4 1977" do 
    expect(MLR.parse_ec('V. 100 NO. 1-4 1977')['volume']).to eq('100')
  end

  it "parses 101/1-6 (JAN-JUN 1978)" do
    expect(MLR.parse_ec('101/1-6 (JAN-JUN 1978)')['volume']).to eq('101')
  end

  it "parses 'Volume:100, Number:2, Year:1977, Month:February'" do
    expect(MLR.parse_ec('Volume:100, Number:2, Year:1977, Month:February')['month']).to eq('February')
  end

  it "parses '81 1958'" do
    expect(MLR.parse_ec('81 1958')['volume']).to eq('81')
  end

  it "parses 'V. 19:NO. 3 (1924)'" do
    expect(MLR.parse_ec('V. 19:NO. 3 (1924)')['number']).to eq('3')
  end

  it "parses 'V. 114, NOS. 7-12(1991)'" do
    expect(MLR.parse_ec('V. 114, NOS. 7-12(1991)')['start_number']).to eq('7')
  end

  it "parses 'V. 64 1947'" do
    expect(MLR.parse_ec('V. 64 1947')['volume']).to eq('64')
  end

  it "parses 'V. 61 NO. 10 1977'" do
    expect(MLR.parse_ec('V. 61 NO. 10 1977')['number']).to eq('10')
  end

  it " parses 'V. 123:5-8 (MAY-AUG 2000)'" do
    expect(MLR.parse_ec('V. 123:5-8 (MAY-AUG 2000)')['start_number']).to eq('5')
  end

  it "parses 'V. 127:NO. 3(2004:MAR. )'" do
    expect(MLR.parse_ec('V. 127:NO. 3(2004:MAR. )')['number']).to eq('3')
  end
  it "parses 'V. 128 NO. 10'" do
    expect(MLR.parse_ec('V. 128 NO. 10')['volume']).to eq('128')
  end

  it "parses 'V. 128NO. 10-12'" do
    expect(MLR.parse_ec('V. 128NO. 10-12')['volume']).to eq('128')
  end
  
  it "parses 'V. 128:NO. 5-8 (2005:MAY-AUG. )'" do
    expect(MLR.parse_ec('V. 128:NO. 5-8 (2005:MAY-AUG. )')['volume']).to eq('128')
  end

  it "parses ' V. 129:NO. 1-3(2006:JAN. -MAR. )'" do
    expect(MLR.parse_ec('V. 129:NO. 1-3(2006:JAN. -MAR. )')['volume']).to eq('129')
    expect(MLR.parse_ec('V. 128:NO. 5-8 (2005:MAY-AUG. )')['volume']).to eq('128')
  end

  it "parses '119:1-6 1996'" do
    expect(MLR.parse_ec('119:1-6 1996')['volume']).to eq('119')
  end

  it "parses 'V. 94(1971NO. 7-12)'" do
    expect(MLR.parse_ec('V. 94(1971NO. 7-12)')['volume']).to eq('94')
  end
end

describe "canonicalize" do
  it "returns nil if ec can't be parsed" do
    expect(MLR.canonicalize({})).to be_nil
  end

  it "turns a parsed ec into a canonical string" do
    expect(MLR.canonicalize(MLR.parse_ec('V. 10:NO. 4 (1920)'))).to eq('Volume:10, Number:4')
  end

  it "converts multi months into numbers" do
    parsed = MLR.parse_ec('V. 2 JA-JE(1916)')
    exploded = MLR.explode(parsed).values[2]
    expect(exploded['canon']).to eq('Volume:2, Number:3, Year:1916, Month:March')
  end
end

describe "explode" do
  it "expands multi numbers" do
    expect(MLR.explode(MLR.parse_ec('V. 100 NO. 1-4 1977')).count).to eq(4)
    expect(MLR.explode(MLR.parse_ec('V. 100 NO. 1-4 1977')).keys[1]).to eq('Volume:100, Number:2')
  end

  it "expands multi months into numbers" do
    parsed = MLR.parse_ec('V. 2 JA-JE(1916)')
    expect(MLR.explode(parsed).count).to eq(6)
    expect(MLR.explode(parsed).values[2]['number']).to eq(3)
    expect(MLR.explode(parsed).values[2]['month']).to eq('March')
  end

end

describe "oclcs" do
  it "has an oclcs field" do
    expect(MLR.oclcs).to include(5345258)
  end
end
