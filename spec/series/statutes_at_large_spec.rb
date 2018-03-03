require 'json'
SR = Registry::SourceRecord
StatutesAtLarge = Registry::Series::StatutesAtLarge

describe 'StatutesAtLarge' do
  let(:src) { Class.new { extend StatutesAtLarge } }

  describe 'parse_ec' do
    it 'can parse them all' do
      matches = 0
      misses = 0
      can_canon = 0
      cant_canon = 0
      input = File.dirname(__FILE__) + '/data/statutes_enumchrons.txt'
      open(input, 'r').each do |line|
        line.chomp!
        ec = src.parse_ec(line)
        if ec.nil? || ec.empty?
          misses += 1
          # puts "no match: "+line
        else
          matches += 1
        end
      end
      expect(matches).to eq(2912)
      # expect(matches).to eq(matches+misses)
    end

    it "parses 'V. 96:PT. 1 (1984)'" do
      expect(src.parse_ec('V. 96:PT. 1 (1984)')).to be_truthy
    end

    it "parses 'V. 96:2 1982'" do
      expect(src.parse_ec('V. 96:2 1982')).to be_truthy
    end

    it "parses 'V. V. 12 1859-1863'" do
      expect(src.parse_ec('V. V. 12 1859-1863')).to be_truthy
      expect(src.parse_ec('V. V. 12 1859-1863')['start_year']).to eq('1859')
    end

    it "parses 'V. V. 36 PT1 1909-12
                V. V. 36 PT2 1909-1911
                V. V. 37 PT. 1 1911-12'" do
      expect(src.parse_ec('V. V. 36 PT1 1909-12')).to be_truthy
      expect(src.parse_ec('V. V. 36 PT2 1909-1911')).to be_truthy
      expect(src.parse_ec('V. V. 37 PT. 1 1911-12')).to be_truthy
    end

    it "parses '102: PT. 3
                102/PT. 3'" do
      expect(src.parse_ec('102: PT. 3')).to be_truthy
      expect(src.parse_ec('102/PT. 3')).to be_truthy
      expect(src.parse_ec('103: PT. 1989')).to be_nil
      expect(src.parse_ec('108:PT. 1')).to be_truthy
      expect(src.parse_ec('113 PT. 2')).to be_truthy
    end

    it "parses 'V. V. 23 1883-85'" do
      expect(src.parse_ec('V. V. 23 1883-85')).to be_truthy
    end

    it "parses 'V. 99:PT. 1'" do
      expect(src.parse_ec('V. 99:PT. 1')).to be_truthy
    end

    it "parses 'V. V. 32:1 1901-03'" do
      expect(src.parse_ec('V. V. 32:1 1901-03')).to be_truthy
    end

    it "parses 'KF50 . U5 V. 94 PT. 2'" do
      expect(src.parse_ec('KF50 . U5 V. 94 PT. 2')).to be_truthy
    end

    it "parses 'V. 100 PT. 5
                V. 100;PT. 5
                V. 101 1987 PT. 1
                V. 101:1987:PT. 1'" do
      expect(src.parse_ec('V. 100 PT. 5')).to be_truthy
      expect(src.parse_ec('V. 100;PT. 5')).to be_truthy
      expect(src.parse_ec('V. 101 1987 PT. 1')).to be_truthy
      expect(src.parse_ec('V. 101:1987:PT. 1')).to be_truthy
    end

    it "parses 'V. 93
                V. 93 1979
                V. 93 (1979)'" do
      expect(src.parse_ec('V. 93')).to be_truthy
      expect(src.parse_ec('V. 93 1979')).to be_truthy
      expect(src.parse_ec('V. 93 (1979)')['year']).to eq('1979')
    end

    it "parses 'V. 84:PT. 1 (1970/71)
                V. 84 PT. 2 1970/71'" do
      expect(src.parse_ec('V. 84:PT. 1 (1970/71)')).to be_truthy
      expect(src.parse_ec('V. 84 PT. 2 1970/71')['end_year']).to eq('1971')
    end

    it "parses 'V. 112:PT. 1,PP. 1/912 (1998)'" do
      expect(src.parse_ec('V. 112:PT. 1,PP. 1/912 (1998)')).to be_truthy
      expect(src.parse_ec('V. 112:PT. 1,PP. 2681/2786 (1998)')['start_page']).to eq('2681')
    end

    it "parses 'V. 110:PP. 1755-2870 (1996)'" do
      expect(src.parse_ec('V. 110:PP. 1755-2870 (1996)')).to be_truthy
    end

    it "parses 'V. 10 1851-1855
                V. 10 1851/1855
                V. 10 (1851/55)'" do
      expect(src.parse_ec('V. 10 1851-1855')).to be_truthy
      expect(src.parse_ec('V. 10 1851/1855')).to be_truthy
      expect(src.parse_ec('V. 10 (1851/55)')['end_year']).to eq('1855')
    end

    it "parses 'V. 57/PT. 1'" do
      expect(src.parse_ec('V. 57/PT. 1')).to be_truthy
    end

    it "parses 'V. 44 1925-1926 PT. 1'" do
      expect(src.parse_ec('V. 44 1925-1926 PT. 1')).to be_truthy
    end

    it "parses '2005' and '1845-1867.'" do
      expect(src.parse_ec('2005')).to be_truthy
      expect(src.parse_ec('1845-1867')).to be_truthy
    end

    it "parses 'V. 77A
                V. 77A 1963
                V. 77A (1963)'" do
      expect(src.parse_ec('V. 77A')).to be_truthy
      expect(src.parse_ec('V. 77A 1963')).to be_truthy
      expect(src.parse_ec('V. 77A (1963)')).to be_truthy
    end

    it "parses 'V. 118:PT. 1(2004)'" do
      expect(src.parse_ec('V. 118:PT. 1(2004)')).to be_truthy
    end

    it "parses 'V. 114:PART 1 (2000)'" do
      expect(src.parse_ec('V. 114:PART 1 (2000)')).to be_truthy
    end

    it "parses 'V. 124:PT. 1:1/1128(2010)
                V. 124, PT. 2'" do
      expect(src.parse_ec('V. 124:PT. 1:1/1128(2010)')).to be_truthy
      expect(src.parse_ec('V. 124, PT. 2')).to be_truthy
    end
  end

  describe 'explode' do
    it 'standardizes enum chrons with the correct fields' do
      expect(src.explode(src.parse_ec('V. 96:2 1982')).count).to eq(1)
      expect(src.explode(src.parse_ec('V. 96:2 1982'))).to have_key('Volume:96, Part:2')
    end
  end

  describe 'oclcs' do
    it 'has an oclcs field' do
      expect(StatutesAtLarge.oclcs).to include(1_768_474)
    end
  end
end
