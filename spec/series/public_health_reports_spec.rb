require 'json'

PHR = Registry::Series::PublicHealthReports

describe 'PublicHealthReports' do
  let(:src) { PHR.new }

  describe 'preprocess' do
    it 'trims off copy info' do
      expect(src.preprocess('C. 1 V. 35 PT. 2 1920')).to \
        eq('V. 35 PT. 2 1920')
    end
  end

  describe 'parse_ec' do
    it 'can parse them all' do
      matches = 0
      misses = 0
      input = File.dirname(__FILE__) +
              '/data/public_health_reports_ec.txt'
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
      puts "PHR match: #{matches}"
      puts "PHR no match: #{misses}"
      expect(matches).to eq(1756) # actual: 2111
      # expect(matches).to eq(matches + misses)
    end

    it 'parses canonical' do
      expect(src.parse_ec('Volume:50')['volume']).to eq('50')
      expect(src.parse_ec('Volume:50, Part:1')['part']).to eq('1')
      expect(src.parse_ec('Volume:50, Part:1, Year:1935')['year']).to eq('1935')
      expect(src.parse_ec('Number:138')['number']).to eq('138')
    end

    it 'parses "C. 1 V. 23 PT. 1 1908"' do
      expect(src.parse_ec('C. 1 V. 23 PT. 1 1908')['year']).to eq('1908')
    end

    it 'parses "V. 103 (1988)"' do
      expect(src.parse_ec('V. 103 (1988)')['year']).to eq('1988')
    end

    it 'parses "V. 22:PT. 1(1907)"' do
      expect(src.parse_ec('V. 22:PT. 1(1907)')['year']).to eq('1907')
    end

    it 'parses "83/PT. 1"' do
      expect(src.parse_ec('83/PT. 1')['volume']).to eq('83')
    end

    it 'parses "V. 59 NO. 27-52 1944"' do
      expect(src.parse_ec('V. 59 NO. 27-52 1944')['start_number']).to eq('27')
    end

    it 'parses "V. 24,PT. 1,NO. 1-26 1909"' do
      expect(src.parse_ec('V. 24,PT. 1,NO. 1-26 1909')['start_number']).to \
        eq('1')
      expect(src.parse_ec('V. 24,PT. 1,NO. 1-26 1909')['part']).to \
        eq('1')
    end

    it 'parses "V. 98:NO. 2 (1983)"' do
      expect(src.parse_ec('V. 98:NO. 2 (1983)')['number']).to eq('2')
    end

    it 'parses "V. 82 1967 JUL-DEC"' do
      expect(src.parse_ec('V. 82 1967 JUL-DEC')['start_month']).to eq('JUL')
    end

    it 'parses "V. 13:NO. 46(1898:NOV. 18)"' do
      expect(src.parse_ec('V. 13:NO. 46(1898:NOV. 18)')['day']).to eq('18')
    end

    it 'parses "V. 54 PT. 1 NO. 01-26 YR. 1939 MO. JAN. -JUNE"' do
      expect(src.parse_ec('V. 54 PT. 1 NO. 01-26 YR. 1939 MO. JAN. -JUNE')['start_month']).to eq('JAN.')
    end

    it 'parses V. 112 1997 NO. 1-3' do
      expect(src.parse_ec('V. 112 1997 NO. 1-3')['start_number']).to eq('1')
    end

    it 'parses "V. 104:NO. 3(1989:MAY/JUNE)"' do
      expect(src.parse_ec('V. 104:NO. 3(1989:MAY/JUNE)')['start_month']).to \
        eq('MAY')
    end

    it 'parses "V. 47:14-26 (APR-JUNE 1932)"' do
      expect(src.parse_ec('V. 47:14-26 (APR-JUNE 1932)')['start_month']).to \
        eq('APR')
    end

    it 'parses "V. 66 PT. 2 (JULY-DEC. 1951)"' do
      expect(src.parse_ec('V. 66 PT. 2 (JULY-DEC. 1951)')['year']).to \
        eq('1951')
    end

    it 'parses "V. 60 PT. 1 NO. 01-26 YR. 1945"' do
      expect(src.parse_ec('V. 60 PT. 1 NO. 01-26 YR. 1945')['year']).to \
        eq('1945')
    end

    it 'parses "V. 13:NO. 23(1898:JUNE 10)"' do
      expect(src.parse_ec('V. 13:NO. 23(1898:JUNE 10)')['month']).to \
        eq('JUNE')
    end

    it 'parses "V. 63:PT. 1:NO. 1-26(1948:JAN. -JUNE)"' do
      expect(src.parse_ec('V. 63:PT. 1:NO. 1-26(1948:JAN. -JUNE)')['year']).to \
        eq('1948')
    end

    it 'parses "119 2004"' do
      expect(src.parse_ec('119')['volume']).to eq('119')
      expect(src.parse_ec('119 2004')['year']).to eq('2004')
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

  describe 'tokens.ns' do
    it 'matches "NO. 01-26"' do
      expect(/#{src.tokens[:ns]}/xi.match('NO. 01-26')['start_number']).to \
        eq('01')
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

  describe 'tokens.months' do
    it 'matches "MO. JAN. -JUNE"' do
      expect(
        /#{src.tokens[:months]}/xi.match('MO. JAN. -JUNE')['start_month']
      ).to \
        eq('JAN.')
    end
  end

  describe 'canonicalize' do
    it "returns nil if ec can't be parsed" do
      expect(src.canonicalize({})).to be_nil
    end

    it 'turns a parsed ec into a canonical string' do
      ec = { 'volume' => '24',
             'part' => '1',
             'number' => '8',
             'year' => '1909',
             'month' => 'Aug' }
      expect(src.canonicalize(ec)).to \
        eq('Volume:24, Part:1, Number:8, Year:1909, Month:August')
    end
  end

  describe 'explode' do
    it 'does not explode multiple numbers' do
      ec = { 'volume' => '24',
             'part' => '1',
             'start_number' => '1',
             'end_number' => '6',
             'year' => '1909',
             'month' => 'SUP' }
      expect(src.explode(ec).keys[3]).to be_nil
      expect(src.explode(ec).keys[0]).to eq('Volume:24, Part:1, Numbers:1-6, Year:1909')
    end
  end

  describe 'title' do
    it 'has a title' do
      expect(PHR.new.title).to eq('Public Health Reports')
    end
  end

  describe 'oclcs' do
    it 'has an oclcs field' do
      expect(PHR.oclcs).to eq([48_450_485, 1_007_653, 181_336_288, 1_799_423])
    end
  end
end
