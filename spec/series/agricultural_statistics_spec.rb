require 'registry/series/agricultural_statistics'
require 'registry/source_record'
require 'json'
AgriculturalStatistics = Registry::Series::AgriculturalStatistics

describe 'AgriculturalStatistics' do
  let(:src) { AgriculturalStatistics.new }

  describe 'parse_ec' do
    it 'can parse them all' do
      matches = 0
      misses = 0
      input = File.dirname(__FILE__) + '/data/agricultural_statistics_ecs.txt'
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
      puts "Ag Statistics match: #{matches}"
      puts "Ag Statistics no match: #{misses}"
      # actual number in test file is 367
      expect(matches).to eq(361)
      # expect(matches).to eq(matches+misses)
    end

    it "parses '2002 1 CD WITH CASE IN BINDER.'" do
      expect(src.parse_ec('2002 1 CD WITH CASE IN BINDER.')).to be_truthy
      expect(src.parse_ec('2002 1 CD WITH CASE IN BINDER.')['year']).to eq('2002')
    end

    it "parses '989-990'" do
      expect(src.parse_ec('989-990')['start_year']).to eq('1989')
      expect(src.parse_ec('989-990')['end_year']).to eq('1990')
    end

    it "hangs onto '1946, 1948' for explode" do
      expect(src.parse_ec('1946, 1948, 1950')['multi_year_comma']).to eq('1946, 1948, 1950')
    end
  end

  describe 'explode' do
    it 'creates a single enumchron' do
      expect(src.explode(src.parse_ec('V. 2002')).count).to eq(1)
    end

    it 'fills in gaps' do
      expect(src.explode(src.parse_ec('989-90')).count).to eq(2)
      expect(src.explode(src.parse_ec('989-90'))).to have_key('1990')
    end

    it 'handles special cases' do
      expect(src.explode(src.parse_ec('1944, 1946, 1948')).count).to eq(3)
      expect(src.explode(src.parse_ec('1944, 1946, 1948'))).to have_key('1946')
      expect(src.explode(src.parse_ec('1995/1996-1997')).count).to eq(2)
      expect(src.explode(src.parse_ec('1995/1996-1997'))).to have_key('1995-1996')
      expect(src.explode(src.parse_ec('1995/1996-1997'))).to have_key('1997')
    end
  end

  describe 'oclcs' do
    it 'has an oclcs field' do
      expect(AgriculturalStatistics.oclcs).to include(1_773_189)
    end
  end
end
