require 'json'

USR = Registry::Series::UnitedStatesReports

describe "parse_ec" do
  it "can parse them all" do 
    volumes = Hash.new {|h,k| h[k] = {}}
    matches = 0
    misses = 0
    input = File.dirname(__FILE__)+'/data/usreports_enumchrons.txt'
    open(input, 'r').each do |line|
      line.chomp!
      ec = USR.parse_ec(line)
      if ec.nil? or ec.length == 0
        misses += 1
        #puts "no match: "+line
      else
        USR.explode(ec).each do | canon, enum_chron |
          volumes[enum_chron["volume"]] = volumes[enum_chron["volume"]].merge(enum_chron)
          #puts enum_chron['volume']+"\t"+canon
        end
        matches += 1
      end
    end
    volumes.each do | v, enum_chron |
      #puts v+"\t"+USR.canonicalize(enum_chron)
    end

    puts "US Reports Record match: #{matches}"
    puts "US Reports Record no match: #{misses}"
    expect(matches).to eq(matches+misses)
  end

  it "parses V. 364 (OCT. TERM 1959/60)" do
    expect(USR.parse_ec('V. 364 (OCT. TERM 1959/60)')['start_year']).to eq('1959')
  end

  it "parses V. 19 (WHEATON 6)" do 
    expect(USR.parse_ec('V. 19 (WHEATON 6)')['reporter']).to eq('WHEATON')
  end

  it "parses V. 507 (1992)" do
    expect(USR.parse_ec('V. 607 (1992)')['year']).to eq('1992')
  end

  it "parses V. 507 YR. 1992" do
    expect(USR.parse_ec('V. 607 YR. 1992')['year']).to eq('1992')
  end

  it "parses V. 443 (OCT. TERM 1978)" do
    expect(USR.parse_ec('V. 443 (OCT. TERM 1978)')['october']).to eq('OCT. TERM')
  end

  it "parses V. 556PT. 2" do
    expect(USR.parse_ec('V. 556PT. 2')['part']).to eq('2')
  end

  it "parses V. 546:1" do
    expect(USR.parse_ec('V. 556:1')['part']).to eq('1')
  end

  it "parses V496PT1" do
    expect(USR.parse_ec('V496PT1')['volume']).to eq('496')
  end

  it "parses V497" do
    expect(USR.parse_ec('V497')['volume']).to eq('497')
  end

  it "expands V. 35 1899-01" do 
    expect(USR.parse_ec('V. 35 1899-01')['end_year']).to eq('1901')
  end
end

describe "canonicalize" do
  it "returns nil if ec can't be parsed" do
    expect(USR.canonicalize({})).to be_nil
  end
end

describe "explode" do
  it "expands multivolumes" do
    expect(USR.explode(USR.parse_ec('V. 53-58')).count).to eq(6)
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
