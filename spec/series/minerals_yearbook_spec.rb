require 'json'

MY = ECMangle::MineralsYearbook

describe 'MineralsYearbook' do
  let(:src) { MY.new }

  describe 'parse_ec' do
    it 'can parse them all' do
      matches = 0
      misses = 0
      input = File.dirname(__FILE__) + '/data/minerals_yearbook_enumchrons.txt'
      File.open(input, 'r').each do |line|
        line.chomp!
        ec = src.parse_ec(line)
        if ec.nil? || ec.empty?
          misses += 1
          # puts "no match: "+line
        else
          unless ec['description'].nil?
            # puts src.normalize_description(ec['description'])
          end
          res = src.explode(ec)
          res.each do |canon, features|
            # puts canon
          end
          matches += 1
        end
      end
      puts "Minerals Yearbook Record match: #{matches}"
      puts "Minerals Yearbook Record no match: #{misses}"
      expect(matches).to eq(4020)
      # expect(matches).to eq(matches+misses)
    end

    it "parses '2007 V. 3 PT. 3'" do
      expect(src.parse_ec('2007 V. 3 PT. 3')['part']).to eq('3')
    end

    it "parses '1991:2 (DOMESTIC)'" do
      expect(src.parse_ec('1991:2 (DOMESTIC)')['volume']).to eq('2')
    end

    it "parses '993-94/V. 2'" do
      expect(src.parse_ec('993-94/V. 2')['end_year']).to eq('1994')
    end

    it "parses '991/V. 3/LATIN'" do
      expect(src.parse_ec('991/V. 3/LATIN')['volume']).to eq('3')
    end

    it "parses '2003/V. 3/NO. 4 EUROPE AND CENTRAL EURASIA'" do
      expect(src.parse_ec('2003/V. 3/NO. 4 EUROPE AND CENTRAL EURASIA')['volume']).to eq('3')
    end

    it "parses canonical '2003/v. 3/no. 4 europe and central eurasia'" do
      parsed = src.parse_ec('Year:2003, Volume:3, Part:2, Description:EUROPE AND CENTRAL EURASIA')
      expect(parsed['part']).to eq('2')
      parsed = src.parse_ec('Year:2003-2004, Volume:3, Part:2, Description:EUROPE AND CENTRAL EURASIA')
      expect(parsed['part']).to eq('2')
    end
  end

  describe 'canonicalize' do
    it "returns nil if ec can't be parsed" do
      expect(src.canonicalize({})).to be_nil
    end

    it 'turns a parsed ec into a canonical string' do
      expect(src.canonicalize(src.parse_ec('992/V. 2'))).to eq('Year:1992, Volume:2')
    end

    it 'turns a parsed ec into a canonical string' do
      expect(src.canonicalize(src.parse_ec('1981:V. 3:PT. 5'))).to eq('Year:1981, Volume:3, Part:5')
    end

    it 'turns a parsed ec into a canonical string' do
      expect(src.canonicalize(src.parse_ec('V. 31993:EUROPE/CENTRAL EURASIA'))).to eq('Year:1993, Volume:3, Description:EUROPE AND CENTRAL EURASIA')
    end
  end

  describe 'normalize_description' do
    it "removes 'AREA REPORTS'" do
      expect(src.normalize_description('AREA REPORTS: INTERNATIONAL ASIA AND THE PACIFIC')).to eq('INTERNATIONAL ASIA AND THE PACIFIC')
    end

    it "normalizes 'EUROPE/CENTRAL EURASIA'" do
      expect(src.normalize_description('EUROPE/CENTRAL EURASIA')).to eq('EUROPE AND CENTRAL EURASIA')
    end
  end

  describe 'explode' do
    it 'expands multi volumes' do
      expect(src.explode(src.parse_ec('V. 1-2(1968)')).count).to eq(2)
      expect(src.explode(src.parse_ec('V. 1-2(1968)')).keys[1]).to eq('Year:1968, Volume:2')
    end

    it 'does not expand multi years' do
      parsed = src.parse_ec('1978-79:1')
      expect(src.explode(parsed).count).to eq(1)
      expect(src.explode(parsed).values[0]['canon']).to eq('Year:1978-1979, Volume:1')
    end
  end

  describe 'oclcs' do
    it 'has an oclcs field' do
      expect(MY.new.ocns).to include(1_847_412)
    end
  end
end
