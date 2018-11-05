require 'json'

MLR = Registry::Series::MonthlyLaborReview

describe 'MonthlyLaborReview' do
  let(:src) { Class.new { extend MLR } }

  describe 'parse_ec' do
    it 'can parse them all' do
      matches = 0
      misses = 0
      input = File.dirname(__FILE__) + '/data/monthly_labor_review_enumchrons.txt'
      File.open(input, 'r').each do |line|
        line.chomp!
        ec = src.parse_ec(line)
        if ec.nil? || ec.empty?
          misses += 1
          # puts "no match: "+line
        else
          res = src.explode(ec)
          res.each do |canon, _features|
            if canon =~ /Volume:.*Year:/ && canon !~ /INDEX/i
              # puts [features['volume'], features['year']].join("\t")
            end
          end
          matches += 1
        end
      end
      puts "MLR Record match: #{matches}"
      puts "MLR Record no match: #{misses}"
      expect(matches).to eq(5542)
      # expect(matches).to eq(matches+misses)
    end

    it "parses 'V. 62-63 (1946)'" do
      expect(src.parse_ec('V. 62-63 (1946)')['start_volume']).to eq('62')
      expect(src.parse_ec('V. 62-63 (1946)')['start_number']).to be_nil
    end

    it "parses '96 1973:JAN. -JUNE'" do
      expect(src.parse_ec('96 1973:JAN. -JUNE')['volume']).to eq('96')
    end

    it "parses 'V. 125:NO. 1/6 (2002:JAN. /JUNE)'" do
      expect(src.parse_ec('V. 125:NO. 1/6 (2002:JAN. /JUNE)')['volume']).to eq('125')
    end

    it "parses 'V. 127 NO. 1-3 2004 JAN-MAR'" do
      expect(src.parse_ec('V. 127 NO. 1-3 2004 JAN-MAR')['volume']).to eq('127')
    end

    it 'parses V. 100 NO. 1-4 1977' do
      expect(src.parse_ec('V. 100 NO. 1-4 1977')['volume']).to eq('100')
    end

    it 'parses 101/1-6 (JAN-JUN 1978)' do
      expect(src.parse_ec('101/1-6 (JAN-JUN 1978)')['volume']).to eq('101')
    end

    it "parses 'Volume:100, Number:2, Year:1977, Month:February'" do
      expect(src.parse_ec('Volume:100, Number:2, Year:1977, Month:February')['month']).to eq('February')
    end

    it "parses '81 1958'" do
      expect(src.parse_ec('81 1958')['volume']).to eq('81')
      expect(src.parse_ec('81 1958')['year']).to eq('1958')
      expect(src.parse_ec('81 1958')['start_month']).to be_nil
    end

    it "parses 'V. 19:NO. 3 (1924)'" do
      expect(src.parse_ec('V. 19:NO. 3 (1924)')['number']).to eq('3')
    end

    it "parses 'V. 114, NOS. 7-12(1991)'" do
      expect(src.parse_ec('V. 114, NOS. 7-12(1991)')['start_number']).to eq('7')
    end

    it "parses 'V. 64 1947'" do
      expect(src.parse_ec('V. 64 1947')['volume']).to eq('64')
      expect(src.parse_ec('V. 64 1947')['year']).to eq('1947')
    end

    it "parses 'V. 61 NO. 10 1977'" do
      expect(src.parse_ec('V. 61 NO. 10 1977')['number']).to eq('10')
    end

    it " parses 'V. 123:5-8 (MAY-AUG 2000)'" do
      expect(src.parse_ec('V. 123:5-8 (MAY-AUG 2000)')['start_number']).to eq('5')
    end

    it "parses 'V. 127:NO. 3(2004:MAR. )'" do
      expect(src.parse_ec('V. 127:NO. 3(2004:MAR. )')['number']).to eq('3')
    end
    it "parses 'V. 128 NO. 10'" do
      expect(src.parse_ec('V. 128 NO. 10')['volume']).to eq('128')
    end

    it "parses 'V. 128NO. 10-12'" do
      expect(src.parse_ec('V. 128NO. 10-12')['volume']).to eq('128')
    end

    it "parses 'V. 128:NO. 5-8 (2005:MAY-AUG. )'" do
      expect(src.parse_ec('V. 128:NO. 5-8 (2005:MAY-AUG. )')['volume']).to eq('128')
    end

    it "parses ' V. 129:NO. 1-3(2006:JAN. -MAR. )'" do
      expect(src.parse_ec('V. 129:NO. 1-3(2006:JAN. -MAR. )')['volume']).to eq('129')
      expect(src.parse_ec('V. 128:NO. 5-8 (2005:MAY-AUG. )')['volume']).to eq('128')
    end

    it "parses '119:1-6 1996'" do
      expect(src.parse_ec('119:1-6 1996')['volume']).to eq('119')
    end

    it "parses 'V. 94(1971NO. 7-12)'" do
      expect(src.parse_ec('V. 94(1971NO. 7-12)')['volume']).to eq('94')
    end
  end

  describe 'canonicalize' do
    it "returns nil if ec can't be parsed" do
      expect(src.canonicalize({})).to be_nil
    end

    it 'turns a parsed ec into a canonical string' do
      expect(src.canonicalize(src.parse_ec('V. 10:NO. 4 (1920)'))).to eq('Volume:10, Number:4, Year:1920, Month:April')
    end

    it 'converts multi months into numbers' do
      parsed = src.parse_ec('V. 2 JA-JE(1916)')
      exploded = src.explode(parsed).values[2]
      expect(exploded['canon']).to eq('Volume:2, Number:3, Year:1916, Month:March')
    end
  end

  describe 'explode' do
    it 'expands multi numbers' do
      expect(src.explode(src.parse_ec('V. 100 NO. 1-4 1977')).count).to eq(4)
      expect(src.explode(src.parse_ec('V. 100 NO. 1-4 1977')).keys[1]).to eq('Volume:100, Number:2, Year:1977, Month:February')
    end

    it 'expands multi months into numbers' do
      parsed = src.parse_ec('V. 2 JA-JE(1916)')
      expect(src.explode(parsed).count).to eq(6)
      expect(src.explode(parsed).values[2]['number']).to eq(3)
      expect(src.explode(parsed).values[2]['month']).to eq('March')
    end
  end

  describe 'oclcs' do
    it 'has an oclcs field' do
      expect(MLR.oclcs).to include(5_345_258)
    end
  end
end
