require 'json'

PHRS = ECMangle::PublicHealthReportSupplements

describe 'PublicHealthReportSupplements' do
  let(:src) {  PHRS.new }

  describe 'parse_ec' do
    it 'can parse them all' do
      matches = 0
      misses = 0
      input = File.dirname(__FILE__) +
              '/data/public_health_report_supplements_ecs.txt'
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
      puts "Public Health Report Supplements match: #{matches}"
      puts "Public Health Report Supplements no match: #{misses}"
      expect(matches).to eq(93) # actual 116
    end
  end

  describe 'title' do
    it 'has a title' do
      expect(PHRS.new.title).to eq('Public Health Report Supplements')
    end
  end

  describe 'oclcs' do
    it 'has an oclcs field' do
      expect(PHRS.new.ocns).to eq([29_651_249, 491_280_576])
    end
  end

  describe 'canonicalize' do
    it 'canonicalizes "NO. 165 PT. 2"' do
      expect(src.canonicalize(src.parse_ec('NO. 165 PT. 2'))).to eq('Number:165, Part:2')
    end
  end

  describe 'preprocess' do
  end
end
