require 'json'

Exp = Registry::Series::USExports

describe 'USExports' do
  let(:src) { Class.new { extend Exp } }

  describe 'parse_ec' do
    it 'can parse them all' do
      matches = 0
      misses = 0
      input = File.dirname(__FILE__) +
              '/data/us_exports_ec.txt'
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
      puts "US Exports match: #{matches}"
      puts "US Exports no match: #{misses}"
      expect(matches).to eq(444) # actual: 447
      # expect(matches).to eq(matches + misses)
    end

    it 'can parse "V. 1977:MAY-JUNE"' do
      expect(src.parse_ec('V. 1977:MAY-JUNE')['start_month']).to eq('May')
    end

    it 'can parse "1976:8"' do
      expect(src.parse_ec('1976:8')['month']).to eq('August')
    end

    it 'can parse "1975/7-8"' do
      expect(src.parse_ec('1975/7-8')['end_month']).to eq('August')
    end

    it 'can parse "1977-5 (MAY)"' do
      expect(src.parse_ec('1977-5 (MAY)')['month']).to eq('May')
    end

    it 'can parse "1974(JAN. -MAR. )"' do
      expect(src.parse_ec('1974(JAN. -MAR. )')['start_month']).to eq('January')
      expect(src.parse_ec('1974JAN-MAR 1976')['start_month']).to eq('January')
    end

    it 'can parse "JAN. -DEC 1962 PT. 1"' do
      expect(src.parse_ec('JUL -DEC 1962 PT. 2')['end_month']).to eq('December')
    end
  end

  describe 'title' do
    it 'has a title' do
      expect(Exp.title).to eq('U.S. Exports')
    end
  end

  describe 'oclcs' do
    it 'has an oclcs field' do
      expect(Exp.oclcs).to eq([1_799_484, 698_024_555])
    end
  end

  describe 'preprocess' do
    it 'adds a one to a year at the start of an enumchron' do
      expect(src.preprocess('958/V. 2/PT. 2')).to eq('1958/V. 2/PT. 2')
    end
  end
end
