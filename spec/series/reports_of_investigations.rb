require 'json'

ROI = Registry::Series::ReportsOfInvestigations

describe "ReportsOfInvestigations" do
  let(:src) { Class.new { extend ROI } }

  describe "parse_ec" do
    it "can parse them all" do 
      matches = 0
      misses = 0
      input = File.dirname(__FILE__)+'/data/mine_investigations.txt'
      open(input, 'r').each do |line|
        line.chomp!
        ec = src.parse_ec(line)
        if ec.nil? or ec.length == 0
          misses += 1
          puts "no match: "+line
        else
          res = src.explode(ec)
          res.each do | canon, features |
            #puts canon
          end
          matches += 1
        end
      end
      puts "Reports of Investigations Record match: #{matches}"
      puts "Reports of Investigations Record no match: #{misses}"
      expect(matches).to eq(matches+misses)
    end

    it "parses 'NO. 7936-7950'" do
      expect(src.parse_ec('NO. 7936-7950')['start_number']).to eq('7936')
    end

    it "parses 'NO. 7936-7950 YR. 1974'" do
      expect(src.parse_ec('NO. 7936-7950 YR. 1974')['start_number']).to eq('7936')
    end

    it "parses 'Year:1974'" do
      expect(src.parse_ec('Year:1974')['year']).to eq('1974')
    end

    it "parses 'Number:7945'" do
      expect(src.parse_ec('Number:7945')['number']).to eq('7945')
    end

    it "parses 'Year:1974, Number:7945'" do
      expect(src.parse_ec('Year:1974, Number:7945')['number']).to eq('7945')
    end

    it "parses '2575 (1924)'" do
      expect(src.parse_ec('2575 (1924)')['number']).to eq('2575')
    end

    it "parses '8510-8525 (1981)'" do
      expect(src.parse_ec('8510-8525 (1981)')['start_number']).to eq('8510')
    end

    it "parses 'NO. 8653 (1982)'" do
      expect(src.parse_ec('NO. 8653 (1982)')['number']).to eq('8653')
    end

    it "parses '7955-7964 (1974-75)'" do
      expect(src.parse_ec('7955-7964 (1974-75)')['start_number']).to eq('7955')
    end

    it "parses 'NO. 5377-5390 YR. 1957-58'" do
      expect(src.parse_ec('NO. 5377-5390 YR. 1957-58')['year']).to eq('1957-1958')
    end

    it "parses 'NO. 7936 YR. 1974'" do
      expect(src.parse_ec('NO. 7936 YR. 1974')['year']).to eq('1974')
    end

    it "parses '7936-7938 (1974-75)'" do
      expect(src.parse_ec('7936-7938 (1974-75)')['year']).to eq('1974-1975')
    end

  end

  describe "canonicalize" do
    it "returns nil if ec can't be parsed" do
      expect(src.canonicalize({})).to be_nil
    end

    it "turns a parsed ec into a canonical string" do
      expect(src.canonicalize(src.parse_ec('NO. 7936 YR. 1974'))).to eq('Year:1974, Number:7936')
    end

  end

  describe "explode" do
    it "expands multi numbers" do
      expect(src.explode(src.parse_ec('6007-6019')).count).to eq(13)
    end

    it "turns a parsed ec into a canonical string (multi year)" do
      parsed = src.parse_ec('7936-7938 (1974-75)')
      exploded = src.explode(parsed)
      expect(exploded.keys[0]).to eq('Year:1974-1975, Number:7936')
    end

  end

  describe "oclcs" do
    it "has an oclcs field" do
      expect(ROI.oclcs).to include(1728640)
    end
  end

end
