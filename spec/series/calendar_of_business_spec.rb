require 'json'

COB = Registry::Series::CalendarOfBusiness

describe 'CalendarOfBusiness' do
  let(:src) { Class.new { extend COB } }

  describe 'parse_ec' do
    it 'can parse them all' do
      matches = 0
      misses = 0
      input = File.dirname(__FILE__) +
              '/data/calendar_of_business_ecs.txt'
      output = File.open('canonicals.tmp', 'w')
      File.open(input, 'r').each do |line|
        line.chomp!
        ec = src.parse_ec(line)
        if ec.nil? || ec.empty?
          misses += 1
          # puts 'no match: ' + line
        else
          res = src.explode(ec)
          res.each_key do |canon|
            output.puts canon
          end
          matches += 1
        end
      end
      puts "Calendar of Business match: #{matches}"
      puts "Calendar of Business no match: #{misses}"
      expect(matches).to eq(3024) # actual: 3084
    end
  end

  describe 'title' do
    it 'has a title' do
      expect(COB.title).to eq('Calendar of Business')
    end
  end

  describe 'oclcs' do
    it 'has an oclcs field' do
      expect(COB.oclcs).to eq([30_003_375,
                               1_768_284,
                               41_867_070])
    end
  end

  describe 'parse_ec' do
    it 'parses "2001/13"' do
      expect(src.parse_ec('2001/13')['number']).to eq('13')
    end
  end

  describe 'canonicalize' do
    it 'canonicalizes "1988:MAY 17"' do
      expect(src.canonicalize(src.parse_ec('1988:MAY 17'))).to eq('Year:1988, Month:May, Day:17')
    end
  end

  describe 'preprocess' do
  end
end
