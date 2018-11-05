require 'json'

VS = Registry::Series::VitalStatistics

describe 'VitalStatistics' do
  let(:src) { Class.new { extend VS } }

  describe 'parse_ec' do
    it 'can parse them all' do
      matches = 0
      misses = 0
      input = File.dirname(__FILE__) + '/data/vital_statistics_ecs.txt'
      File.open(input, 'r').each do |line|
        line.chomp!
        ec = src.parse_ec(line)
        if ec.nil? || ec.empty?
          misses += 1
          # puts "no match: "+line
        else
          res = src.explode(ec)
          res.each do |canon, features|
            # puts canon
          end
          matches += 1
        end
      end
      puts "Vital Statistics match: #{matches}"
      puts "Vital Statistics no match: #{misses}"
      expect(matches).to eq(2759)
      # expect(matches).to eq(matches+misses)
    end

    it 'parses canonical' do
      expect(src.parse_ec('Year:1960, Volume:2, Part:A')['part']).to eq('A')
      expect(src.parse_ec('Year:1960, Volume:2, Appendix')['volume']).to eq('2')
      expect(src.parse_ec('Year:1943, Section:1')['section']).to eq('1')
    end

    it "parses '1961 V. 2 PT. B'" do
      expect(src.parse_ec('1961 V. 2 PT. B')['part']).to eq('B')
    end

    it "parses 'YR. 1972 V. 2 PT. 0A'" do
      expect(src.parse_ec('YR. 1972 V. 2 PT. 0A')['part']).to eq('0A')
    end

    it "parses 'V. 3 (1968)'" do
      expect(src.parse_ec('V. 3 (1968)')['volume']).to eq('3')
      expect(src.parse_ec('V. 1(1988)')['volume']).to eq('1')
    end

    it "parses 'V. 2B (1978)'" do
      expect(src.parse_ec('V. 2B (1978)')['part']).to eq('B')
      expect(src.parse_ec('V. 2:PT. A(1988)')['part']).to eq('A')
    end

    it "parses 'V. 1950:3'" do
      expect(src.parse_ec('V. 1950:3')['volume']).to eq('3')
    end

    it "parses '1983:V. 1:APPDX.'" do
      expect(src.parse_ec('1983:V. 1:APPDX.')['volume']).to eq('1')
      expect(src.parse_ec('1983 V. 1 APPENDIX')['volume']).to eq('1')
    end

    it 'ignores Copy information' do
      expect(src.parse_ec('1961:V. 1 C. 1')['volume']).to eq('1')
    end
  end

  describe 'canonicalize' do
    it "returns nil if ec can't be parsed" do
      expect(src.canonicalize({})).to be_nil
    end

    it 'turns a parsed ec into a canonical string' do
      expect(src.canonicalize(src.parse_ec('1961 V. 2 PT. B'))).to eq('Year:1961, Volume:2, Part:B')
    end
  end

  describe 'explode' do
  end

  describe 'oclcs' do
    it 'has an oclcs field' do
      expect(VS.oclcs).to eq([1_168_068, 48_062_652])
    end
  end
end
