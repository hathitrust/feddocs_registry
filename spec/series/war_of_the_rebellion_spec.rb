# frozen_string_literal: true

require 'dotenv'
require 'json'

Dotenv.load
Mongoid.load!(ENV['MONGOID_CONF'])
SourceRecord = Registry::SourceRecord

WOTR = ECMangle::WarOfTheRebellion

describe 'WOTR' do
  let(:src) { WOTR.new }

  describe 'parse_ec' do
    it 'can parse them all' do
      matches = 0
      misses = 0
      input = File.dirname(__FILE__) +
              '/data/war_of_the_rebellion_ecs.txt'
      # output = File.open('fails.tmp', 'w')
      File.open(input, 'r').each do |line|
        line.chomp!
        ec = src.parse_ec(line)
        if ec.nil? || ec.empty?
          misses += 1
          # output.puts 'no match: ' + line
        else
          res = src.explode(ec)
          res.each_key do |canon|
            # output.puts canon
          end
          matches += 1
        end
      end
      puts "WOTR match: #{matches}"
      puts "WOTR no match: #{misses}"
      expect(matches).to eq(1907) # actual: 1962
      # expect(matches).to eq(matches + misses)
    end

    it 'parses canonical' do
      expect(src.parse_ec('Series:1, Volume:35, Part:1')['volume']).to eq('35')
      expect(
        src.parse_ec('Series:1, Volume:35, Part:1, Number:65')['number']
      ).to \
        eq('65')
    end

    it 'parses "SERIES 1 (V. 17,PT. 1)"' do
      expect(src.parse_ec('SERIES 1 (V. 17,PT. 1)')['part']).to eq('1')
    end

    it 'parses "C. 1 SER 1 V. 11 PT. 2"' do
      expect(src.parse_ec('C. 1 SER 1 V. 11 PT. 2')['part']).to eq('2')
    end

    it 'parses "99 (SERIES 1 V. 47 PT. 1)"' do
      expect(src.parse_ec('99 (SERIES 1 V. 47 PT. 1)')['part']).to eq('1')
    end

    it 'parses "V. 40,PT. 2 (SERIES 1)"' do
      expect(src.parse_ec('V. 40,PT. 2 (SERIES 1)')['part']).to eq('2')
    end

    it 'parses "SERIES 1 (V. 18)"' do
      expect(src.parse_ec('SERIES 1 (V. 18)')['volume']).to eq('18')
    end

    it 'parses "1/46/ PT. 1"' do
      expect(src.parse_ec('1/46/ PT. 1')['part']).to eq('1')
    end

    it 'parses "122 (SERIES 3 V. 1)"' do
      expect(src.parse_ec('122 (SERIES 3 V. 1)')['number']).to eq('122')
    end

    it 'does not use the 3004 in "3004 (SERIES 1 V. 40 PT. 1)"' do
      expect(src.parse_ec('3004 (SERIES 1 V. 40 PT. 1)')['number']).to be_nil
      expect(src.parse_ec('3004 (SERIES 1 V. 40 PT. 1)')['part']).to eq('1')
    end

    it 'ignores year when parsing' do
      expect(src.parse_ec('V. SERIES 1/V. 34/PT. 3/1891')['part']).to eq('3')
    end

    it 'ignores everything after reports or correspondence is mentioned' do
      expect(src.parse_ec('SER. 1:V. 49:PT. 1:REPORTS AND CORR')['part']).to \
        eq('1')
    end

    it 'parses "SER. 1:V. 42:PT. 1:REPORTS"' do
      expect(src.parse_ec('SER. 1:V. 42:PT. 1:REPORTS')['part']).to \
        eq('1')
    end

    it 'parses series numbers when they are I' do
      expect(src.parse_ec('I/26-1')['series']).to eq('I')
      expect(src.parse_ec('III/22-3')['series']).to eq('III')
    end

    it 'parses "1/17"' do
      expect(src.parse_ec('1/17')['series']).to eq('1')
    end
  end

  describe 'preprocess' do
    it 'removes copy information' do
      expect(src.preprocess('C. 2 SER. 1 V. 39 PT. 2')).to eq('SER. 1 V. 39 PT. 2')
    end

    it 'removes extraneous V' do
      expect(src.preprocess('V. SERIES 1/V. 15/1886')).to eq('SERIES 1/V. 15/1886')
    end
  end

  describe 'tokens.pt' do
    it 'matches "PT. 1"' do
      expect(/#{src.tokens[:pt]}/xi.match('PT. 1')['part']).to eq('1')
    end

    it 'matches "PT:1"' do
      expect(/#{src.tokens[:pt]}/xi.match('PT:1')['part']).to eq('1')
    end

    it 'matches "Part:1"' do
      expect(/#{src.tokens[:pt]}/xi.match('Part:1')['part']).to eq('1')
    end
  end

  describe 'tokens.s' do
    it 'matches "SERIES 1"' do
      expect(/#{src.tokens[:s]}/xi.match('SERIES 1')['series']).to eq('1')
    end

    it 'matches "SER 1"' do
      expect(/#{src.tokens[:s]}/xi.match('SER 1')['series']).to eq('1')
    end

    it 'matches "SER. 1"' do
      expect(/#{src.tokens[:s]}/xi.match('SER. 1')['series']).to eq('1')
    end

    it 'matches "Series:1"' do
      expect(/#{src.tokens[:s]}/xi.match('Series:1')['series']).to eq('1')
    end
  end

  describe 'tokens.n' do
    it 'matches Number:2' do
      expect(/#{src.tokens[:n]}/xi.match('Number:2')['number']).to eq('2')
    end

    it 'matches "NO. 2"' do
      expect(/#{src.tokens[:n]}/xi.match('NO. 2')['number']).to eq('2')
    end
  end

  describe 'tokens.v' do
    it 'matches Volume:50' do
      expect(/#{src.tokens[:v]}/xi.match('Volume:50')['volume']).to eq('50')
    end

    it 'matches "v.50"' do
      expect(/#{src.tokens[:v]}/xi.match('v.50')['volume']).to eq('50')
    end
  end

  describe 'tokens.y' do
    it 'matches Year:1984' do
      expect(/#{src.tokens[:y]}/xi.match('Year:1984')['year']).to eq('1984')
    end

    it 'matches "(1984)"' do
      expect(/#{src.tokens[:y]}/xi.match('(1984)')['year']).to eq('1984')
    end

    it 'matches "YR. 1945"' do
      expect(/#{src.tokens[:y]}/xi.match('YR. 1945')['year']).to eq('1945')
    end
  end

  describe 'canonicalize' do
    it "returns nil if ec can't be parsed" do
      expect(src.canonicalize({})).to be_nil
    end

    it 'turns a parsed ec into a canonical string' do
      ec = { 'series' => 'I',
             'volume' => '5',
             'part' => 1 }
      expect(src.canonicalize(ec)).to \
        eq('Series:1, Volume:5, Part:1')
    end
  end

  describe 'explode' do
    it 'explodes to a single ec with a canonical' do
      ec = src.parse_ec('SER. 1:V. 42:PT. 1:REPORTS')
      expect(src.explode(ec).first[0]).to \
        eq('Series:1, Volume:42, Part:1')
    end
  end

  describe 'title' do
    it 'has a title' do
      expect(src.title).to eq('War Of The Rebellion')
    end
  end

  describe 'oclcs' do
    it 'has an oclcs field' do
      expect(WOTR.new.ocns).to eq([427_057,
                                   471_419_901])
    end
  end

  describe 'everything' do
    it 'actually works' do
      wotr_src = File.open(File.dirname(__FILE__) +
                         '/data/wotr_rec.json').read
      wotr = SourceRecord.new
      wotr.org_code = 'miaahdl'
      wotr.source = wotr_src
      expect(wotr.enum_chrons).not_to include('SER. 1:V. 42:PT. 1:REPORTS')
    end
  end
end
