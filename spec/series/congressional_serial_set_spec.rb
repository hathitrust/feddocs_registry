require 'json'

CSS = ECMangle::CongressionalSerialSet

describe 'CongressionalSerialSet' do
  let(:src) { CSS.new }

  describe 'parse_ec' do
    it 'can parse them all' do
      matches = 0
      misses = 0
      can_canon = 0
      cant_canon = 0
      input = File.dirname(__FILE__) +
              '/data/congressional_serial_set_enumchrons.txt'
      File.open(input, 'r').each do |line|
        line.chomp!
        ec = src.parse_ec(line)
        if ec.nil? || ec.empty?
          misses += 1
          # puts "no match: "+line
        else
          matches += 1
          if src.canonicalize(ec)
            can_canon += 1
          else
            # puts "can't canon: "+line
            cant_canon += 1
          end
        end
      end

      puts "Congressional Serial Set match: #{matches}"
      puts "Congressional Serial Set no match: #{misses}"
      puts "Congressional Serial Set can canonicalize: #{can_canon}"
      puts "Congressional Serial Set can't canonicalize: #{cant_canon}"
      expect(matches).to eq(40_800)
      # expect(matches).to eq(matches+misses)
    end

    it 'matches "PT. 13 (1885)"' do
      expect(src.parse_ec('PT. 13 (1885)')['part']).to eq('13')
    end
  end

  describe 'explode' do
    it 'returns the serial number if given only a serial number' do
      expect(src.explode(src.parse_ec('12345')).keys[0]).to eq('Serial Number:12345')
    end
  end

  describe 'sudoc_stem' do
    it 'has a sudoc_stem field' do
      expect(CSS.new.sudoc_stems).to eq(['Y 1.1/2:'])
    end
  end

  describe 'oclcs' do
    it 'has an oclcs field' do
      expect(CSS.new.ocns).to include(3_888_071)
      expect(CSS.new.ocns).to include(4_978_913)
      expect(CSS.new.ocns).to include(191_710_879)
    end
  end
end
