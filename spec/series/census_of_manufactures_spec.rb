require 'json'

CM = ECMangle::CensusOfManufactures

describe 'CensusOfManufactures' do
  let(:src) { CM.new }

  describe 'parse_ec' do
    it 'can parse them all' do
      matches = 0
      misses = 0
      input = File.dirname(__FILE__) +
              '/data/census_of_manufactures_ec.txt'
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
          end
          matches += 1
        end
      end
      puts "CoM match: #{matches}"
      puts "CoM no match: #{misses}"
      expect(matches).to eq(61) # actual: 104
      # expect(matches).to eq(matches + misses)
    end
  end

  describe 'title' do
    it 'has a title' do
      expect(CM.new.title).to eq('Census of Manufactures')
    end
  end

  describe 'oclcs' do
    it 'has an oclcs field' do
      expect(CM.new.ocns).to eq([2_842_584, 623_028_861])
    end
  end

  describe 'preprocess' do
    it 'adds a one to a year at the start of an enumchron' do
      expect(src.preprocess('958/V. 2/PT. 2')).to eq('1958/V. 2/PT. 2')
    end
  end
end
