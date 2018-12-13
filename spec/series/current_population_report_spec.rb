require 'json'

CPR = Registry::Series::CurrentPopulationReport

describe 'CurrentPopulationReport' do
  let(:src) { CPR.new }

  describe 'parse_ec' do
    it 'can parse them all' do
      matches = 0
      misses = 0
      input = File.dirname(__FILE__) +
              '/data/current_population_report_ecs.txt'
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
      puts "Current Population Report match: #{matches}"
      puts "Current Population Report no match: #{misses}"
      expect(matches).to eq(253) # actual: 286
    end

    it 'parses "NO. 1171-1275"' do
      expect(src.parse_ec('NO. 1171-1275')['start_number']).to eq('1171')
    end

    it 'parses "1226-1300"' do
      expect(src.parse_ec('1226-1300')['start_number']).to eq('1226')
    end

    it 'parses "1704"' do
      expect(src.parse_ec('1704')['number']).to eq('1704')
    end
  end

  describe 'title' do
    it 'has a title' do
      expect(CPR.new.title).to eq('Current Population Report')
    end
  end

  describe 'oclcs' do
    it 'has an oclcs field' do
      expect(CPR.oclcs).to eq([6_432_855, 623_448_621])
    end
  end

  describe 'preprocess' do
  end
end
