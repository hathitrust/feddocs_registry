require 'json'

DCVA = Registry::Series::DecisionsOfTheCourtOfVeteransAppeals

describe "DecisionsOfTheCourtOfVeteransAppeals" do
  let(:src) { Class.new { extend DCVA } }

  describe "parse_ec" do
    xit "can parse them all" do 
      matches = 0
      misses = 0
      input = File.dirname(__FILE__)+'/data/decisions_vets_ec.txt'
      open(input, 'r').each do |line|
        line.chomp!
        ec = src.parse_ec(line)
        if ec.nil? or ec.length == 0
          misses += 1
          #puts "no match: "+line
        else
          res = src.explode(ec)
          res.each do | canon, features |
            puts canon
          end
          matches += 1
        end
      end
      puts "Decisions Vets Record match: #{matches}"
      puts "Decisions Vets Record no match: #{misses}"
      expect(matches).to eq(matches+misses)
    end

    it "parses 'NO. 79-7950'" do
      expect(src.parse_ec('NO. 79-7950')['number']).to eq('79-7950')
    end

    it "parses 'NO. 95-1100/999 (1999:APR. 1)'" do
      expect(src.parse_ec('NO. 95-1100/999 (1999:APR. 1)')['number']).to eq('95-1100')
    end

    it "parses multiple decisions: 'NO. 95-1068/999-2 (1999:MAR. 24)'" do
      expect(src.parse_ec('NO. 95-1068/999-2 (1999:MAR. 24)')['decision']).to eq('2')
    end

    it "chokes when years don't match" do
      expect(src.parse_ec('NO. 97-192/999 (2000:FEB. 15)')).to be_nil
    end

    it "parses '1990:753/2'" do
      expect(src.parse_ec('1990:753/2')['number']).to eq('90-753')
    end

    it "parses canonical" do
      expect(src.parse_ec('Number:95-1068-2')['decision']).to eq('2')
    end

    it "parses canonical" do
      expect(src.parse_ec('Number:95-1068-2, Decision Date:1999')['year']).to eq('1999')
    end

    it "parses canonical" do
      expect(src.parse_ec('Number:95-1068-2, Decision Date:1999-03-24')['day']).to eq('24')
    end

  end

  describe "canonicalize" do
    it "returns nil if ec can't be parsed" do
      expect(src.canonicalize({})).to be_nil
    end

    it "turns a parsed ec into a canonical string" do
      expect(src.canonicalize(src.parse_ec('NO. 79-7950'))).to eq('Number:79-7950')
      expect(src.canonicalize(src.parse_ec('NO. 95-1068/999-2 (1999:MAR. 24)'))).to eq('Number:95-1068-2, Decision Date:1999-03-24')
    end

  end

  describe "explode" do
  end

  describe "oclcs" do
    it "has an oclcs field" do
      expect(DCVA.oclcs).to include(27093456)
    end
  end

end
