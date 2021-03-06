require 'json'

JNCI = ECMangle::JournalOfTheNationalCancerInstitute

describe 'JournalOfTheNationalCancerInstitute' do
  let(:src) { JNCI.new }

  describe 'parse_ec' do
    it 'can parse them all' do
      matches = 0
      misses = 0
      input = File.dirname(__FILE__) + '/data/cancer_institute_ecs.txt'
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
      puts "Cancer Institute match: #{matches}"
      puts "Cancer Institute no match: #{misses}"
      expect(matches).to eq(3806)
      # expect(matches).to eq(matches+misses)
    end

    it 'parses canonical' do
      expect(
        src.parse_ec('Volume:58, Number:3, Year:1958')['year']
      ).to eq('1958')
      expect(
        src.parse_ec('Volume:58, Numbers:1-3, Year:1958')['end_number']
      ).to eq('3')
      expect(
        src.parse_ec('Volume:58, Year:1958, Month:September')['month']
      ).to eq('September')
      expect(
        src.parse_ec('Volume:58, Year:1958, Months:July-September')['end_month']
      ).to eq('September')
    end

    it "parses 'V. 32 NO. 4-6 1964'" do
      expect(src.parse_ec('V. 32 NO. 4-6 1964')['year']).to eq('1964')
      expect(src.parse_ec('V. 32 NO. 4-6 1964')['end_number']).to eq('6')
    end

    it "parses and fixes 'V. 3 1942-43'" do
      expect(src.parse_ec('V. 3 1942-43')['end_year']).to eq('1943')
    end

    it "parses 'V. 85:NO. 13-24 (1993:JULY-1993:DEC)'" do
      expect(
        src.parse_ec('V. 85:NO. 13-24 (1993:JULY-1993:DEC)')['year']
      ).to eq('1993')
    end

    it "parses 'V. 88:NO. 13-18<P. 853-1328> (1996:JULY-SEPT. )'" do
      expect(
        src.parse_ec('V. 88:NO. 13-18<P. 853-1328> (1996:JULY-SEPT. )')['year']
      ).to eq('1996')
    end

    it 'parses a bunch of examples' do
      expect(
        src.parse_ec('V. 3 (1942/43:AUG. /JUNE)')['end_month']
      ).to eq('June')
      expect(
        src.parse_ec('V. 1,AUG-JUN 1940-41')['end_year']
      ).to eq('1941')
      expect(
        src.parse_ec('V. 7 (AUG. 1946-JUNE 1947)')['end_year']
      ).to eq('1947')
      expect(
        src.parse_ec('47/1-3 (1971:JULY-SEPT. )')['end_month']
      ).to eq('September')
      expect(
        src.parse_ec('V. 83:NO. 13/18 1991:JULY/SEPT.')['end_month']
      ).to eq('September')
      expect(
        src.parse_ec('V. 91:NO. 9/16=P. 739-1436 1999:MAY/AUG.')['end_month']
      ).to eq('August')
      expect(
        src.parse_ec('V. 12FEB-JUNE')['end_month']
      ).to eq('June')
      expect(
        src.parse_ec('V. 94:NO. 13/18=P. 957-1418 2002:JULY/SEPT. (2002)')['end_month']
      ).to eq('September')
      expect(
        src.parse_ec('V. 61 JUL-AUG 1978 PP. 1-619')['end_month']
      ).to eq('August')
    end

    it 'gets a volume if there is a year' do
      expect(src.parse_ec('NO. 10 1990')['volume']).to eq('82')
      expect(src.parse_ec('NO. 10 1980')['volume']).to be_nil
    end

    it 'gets a year if there is a volume' do
      expect(src.parse_ec('V. 81NO. 13-24')['year']).to eq('1989')
      expect(src.parse_ec('V. 71NO. 13-24')['year']).to be_nil
    end

    it 'day and number are redundant' do
      expect(src.parse_ec('V. 93:NO. 19 (2001:OCT. 03)')['year']).to eq('2001')
      expect(src.parse_ec('V. 95:NO. 5(2003:MAR. 01)')['year']).to eq('2003')
    end
  end

  describe 'canonicalize' do
    it "returns nil if ec can't be parsed" do
      expect(src.canonicalize({})).to be_nil
    end

    it 'turns a parsed ec into a canonical string' do
      expect(
        src.canonicalize(src.parse_ec('V. 32, Number:5, Year:1964'))
      ).to eq('Volume:32, Number:5, Year:1964')
    end

    it 'keeps Pages if we dont have numbers' do
      nums = 'V. 88:NO. 13-18<P. 853-1328> (1996:JULY-SEPT.)'
      expect(
        src.canonicalize(src.parse_ec(nums))
      ).to eq('Volume:88, Numbers:13-18, Year:1996, Months:July-September')
      nonums = 'V. 70 <P. 853-1328> (1975:JULY-SEPT.)'
      expect(
        src.canonicalize(src.parse_ec(nonums))
      ).to eq('Volume:70, Pages:853-1328, Year:1975, Months:July-September')
    end
  end

  describe 'explode' do
    it 'does nothing with multiple numbers' do
      expect(
        src.explode(src.parse_ec('V. 32 NO. 4-6 1964')).keys[0]
      ).to eq('Volume:32, Numbers:4-6, Year:1964')
    end
  end

  describe 'oclcs' do
    it 'has an oclcs field' do
      expect(JNCI.new.ocns).to eq([1_064_763, 36_542_869, 173_847_259, 21_986_096])
    end
  end
end
