require 'json'

CR = Registry::Series::CongressionalRecord

describe "Congressional Record" do
  let(:src) { Class.new { extend CR }} 

  describe "parse_ec" do
    xit "can parse them all" do 
      matches = 0
      misses = 0
      can_canon = 0
      cant_canon = 0
      input = File.dirname(__FILE__)+'/data/congressional_record_enumchrons.txt'
      open(input, 'r').each do |line|
        line.chomp!
        ec = src.parse_ec(line)
        if ec.nil? or ec.length == 0
          misses += 1
          #puts "no match: "+line
        else 
          matches += 1
          if src.canonicalize(ec)
            can_canon += 1
          else
            #puts "can't canon: "+line
            cant_canon += 1
          end
        end
      end

      puts "Congressional Record match: #{matches}"
      puts "Congressional Record no match: #{misses}"
      puts "Congressional Record can canonicalize: #{can_canon}"
      puts "Congressional Record can't canonicalize: #{cant_canon}"
      expect(matches).to eq(matches+misses)
    end
    
    it "parses it's canonical version" do
      expect(src.parse_ec('Volume:105, Part:20')['volume']).to eq('105')
    end

    it "parses 'V. 43 INDEX 1908-09'" do
      expect(src.parse_ec('V. 43 INDEX 1908-09')['volume']).to eq('43')
    end

    it "parses 'V. 5 1877 INDEX'" do
      expect(src.parse_ec('V. 5 1877 INDEX')['volume']).to eq('5')
    end
    
    it "parses 'V. 105 PT. 35'" do
      expect(src.parse_ec('V. 105 PT. 35')['volume']).to eq('105')
    end

    it "parses 'V. 98,PT. 5 1952'" do
      expect(src.parse_ec('V. 98,PT. 5 1952')['part']).to eq('5')
    end

    it "parses 'V. 137:PT. 16 (1991:SEPT. 10/23)'" do
      expect(src.parse_ec('V. 137:PT. 16 (1991:SEPT. 10/23)')['part']).to eq('16')
    end
        
    it "parses 'V. 97:15 (1951)'" do
      expect(src.parse_ec('V. 97:15 (1951)')['part']).to eq('15')
    end

    it "parses 'V. 155:PT. 26(2009)'" do
      expect(src.parse_ec('V. 155:PT. 26(2009)')['volume']).to eq('155')
      expect(src.parse_ec('V. 155:PT. 26(2009)')['year']).to eq('2009')
    end

    it "parses 'V. 152:PT. 16(2006:SEPT. 29)'" do
      expect(src.parse_ec('V. 155:PT. 16(2006:SEPT. 29)')['year']).to eq('2006')
    end

    it "parses 'V. 129:PT. 2 1983:FEB. 2-22'" do
      expect(src.parse_ec('V. 129:PT. 2 1983:FEB. 2-22')['year']).to eq('1983')
    end
    it "parses 'V. 152:PT. 16(2006:SEPT. 29)'" do
      expect(src.parse_ec('V. 155:PT. 16(2006:SEPT. 29)')['year']).to eq('2006')
    end

    it "parses '64/1:53/PT. 1'" do
      expect(src.parse_ec('64/1:53/PT. 1')['volume']).to eq('53')
    end

    it "parses '102/1-137/PT. 26'" do
      expect(src.parse_ec('102/1-137/PT. 26')['volume']).to eq('137')
    end

    it "parses '101/1:129/PT. 15'" do
      expect(src.parse_ec('101/1:129/PT. 15')['volume']).to eq('129')
    end

    it "parses 'V. 99:PT. 2 1953:FEB. 26-APR. 8'" do
      expect(src.parse_ec('V. 99:PT. 2 1953:FEB. 26-APR. 8')['part']).to eq('2')
    end

    it "parses '51ST:1ST:V. 21:PT. 7 (1890:JUNE 13/JULY 9)'" do
      expect(src.parse_ec('51ST:1ST:V. 21:PT. 7 (1890:JUNE 13/JULY 9)')['part']).to eq('7')
    end

    it "parses '102/2:V. 138:PT. 25'" do
      expect(src.parse_ec('102/2:V. 138:PT. 25')['part']).to eq('25')
    end

    it "parses '102ND CONG. , 1ST SES. V. 137 PT. 25 INDEX L-Z'" do
      expect(src.parse_ec('102ND CONG. , 1ST SES. V. 137 PT. 25 INDEX L-Z')['part']).to eq('25')
    end
    
    it "parses 'V. 84. PT. 10 1939'" do
      expect(src.parse_ec('V. 84. PT. 10 1939')['part']).to eq('10')
    end

=begin
    # We're going to assume Volume. Might as well decide on something.
    it "can NOT parse '108/PT. 17'" do
      expect(src.parse_ec('108/PT. 17')).to be_nil
    end
=end
    it "can parse '108/PT. 17'" do
      expect(src.parse_ec('108/PT. 17')['part']).to eq('17')
    end

    it "handles indexes" do 
      expect(src.parse_ec('102/1-138/PT. 24/INDEX L-Z')['index']).to eq('L-Z')
    end

  end

  describe "explode" do
    it "returns a canonical form" do
      expect(src.explode(src.parse_ec('V. 97:15 (1951)'), {})).to have_key('Volume:97, Part:15')
    end

    it "handles indexes" do 
      expect(src.explode(src.parse_ec('102/1-138/PT. 24/INDEX L-Z'), {})).to have_key('Volume:138, Part:24, Index:L-Z')
    end

  end

  describe "canonicalize" do
    it "returns a canonical form" do
      expect(src.canonicalize(src.parse_ec('V. 97:15 (1951)'))).to eq('Volume:97, Part:15')
    end

    it "returns nil if can't canonicalize" do
      expect(src.canonicalize(src.parse_ec('gibberish'))).to be_nil
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
end
