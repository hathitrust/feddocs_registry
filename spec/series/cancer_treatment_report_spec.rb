require 'json'

CTR = Registry::Series::CancerTreatmentReport

describe 'CancerTreatmentReport' do
  let(:src) { Class.new { extend CTR } }

  describe 'parse_ec' do
    it 'can parse them all' do
      matches = 0
      misses = 0
      input = File.dirname(__FILE__) + '/data/cancer_treatment_report_ecs.txt'
      open(input, 'r').each do |line|
        line.chomp!
        ec = src.parse_ec(line)
        if ec.nil? || ec.empty?
          misses += 1
          # puts 'no match: ' + line
        else
          res = src.explode(ec)
          res.each do |canon, features|
            # puts canon
          end
          matches += 1
        end
      end
      puts "Cancer Treatment match: #{matches}"
      puts "Cancer Treatment no match: #{misses}"
      expect(matches).to eq(409)
      # expect(matches).to eq(matches+misses)
    end

    it 'parses canonical' do
      expect(src.parse_ec('Volume:58, Number:3, Year:1977')['number']).to eq('3')
      expect(src.parse_ec('Volume:58, Numbers:1-3, Year:1958')['end_number']).to eq('3')
      expect(src.parse_ec('Volume:58, Year:1958, Month:September')['month']).to eq('September')
      expect(src.parse_ec('Volume:58, Year:1958, Months:July-September')['end_month']).to eq('September')
    end

    it "parses 'V. 62,NO. 7-9,1978'" do
      expect(src.parse_ec('V. 62,NO. 7-9,1978')['volume']).to eq('62')
    end

    it "parses '66/6-12'" do
      expect(src.parse_ec('66/6-12')['volume']).to eq('66')
    end

    it "parses 'V. 67:NO. 7-12 1983:JULY-DEC'" do
      expect(src.parse_ec('V. 67:NO. 7-12 1983:JULY-DEC')['start_number']).to eq('7')
    end

    it 'gets a year if there is a volume' do
      expect(src.parse_ec('V. 67:NO. 7-12')['volume']).to eq('67')
      expect(src.parse_ec('V. 67:NO. 7-12')['year']).to eq('1983')
    end
  end

  describe 'canonicalize' do
    it "returns nil if ec can't be parsed" do
      expect(src.canonicalize({})).to be_nil
    end

    it 'turns a parsed ec into a canonical string' do
      expect(src.canonicalize(src.parse_ec('V. 32, Number:5, Year:1964'))).to eq('Volume:32, Number:5, Year:1964')
    end

    it 'keeps Pages if we dont have numbers' do
      nums = 'V. 88:NO. 13-18<P. 853-1328> (1996:JULY-SEPT.)'
      expect(src.canonicalize(src.parse_ec(nums))).to eq('Volume:88, Numbers:13-18, Year:1996, Months:July-September')
      nonums = 'V. 70 <P. 853-1328> (1975:JULY-SEPT.)'
      expect(src.canonicalize(src.parse_ec(nonums))).to eq('Volume:70, Pages:853-1328, Year:1975, Months:July-September')
    end
  end

  describe 'explode' do
    it 'explodes multiple numbers' do
      expect(src.explode(src.parse_ec('V. 32 NO. 4-6 1964')).keys[0]).to eq('Volume:32, Number:4, Year:1964')
    end
  end

  describe 'oclcs' do
    it 'has an oclcs field' do
      expect(CTR.oclcs).to eq([2_101_497, 681_450_829])
    end
  end
end
