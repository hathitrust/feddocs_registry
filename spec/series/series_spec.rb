include Registry::Series
Series = Registry::Series
describe 'Series.calc_end_year' do
  it 'handles simple 3 digit years' do
    expect(Series.calc_end_year('1995', '998')).to eq('1998')
  end

  it 'handles simple 2 digit years' do
    expect(Series.calc_end_year('1995', '98')).to eq('1998')
  end

  it 'handles 3 character rollovers' do
    expect(Series.calc_end_year('1999', '002')).to eq('2002')
  end

  it 'handles 2 character rollovers' do
    expect(Series.calc_end_year('1999', '02')).to eq('2002')
  end
end

describe 'tokens' do
  let(:src) { Class.new { extend Series } }
  it 'matches "OCT."' do
    expect(/#{Series.tokens[:m]}/xi.match('OCT.')['month']).to eq('OCT.')
  end
end

describe 'matchdata_to_hash' do
  # Converting the MatchData into a Hash becomes problematic when
  # there are repeated named groups.
  # These tests are to confirm our understanding ofMatchData weirdness.

  multi_months = %r{
    (?<year>\d{4})\s
    (?<start_month>(?<month>(JAN|FEB)))-
    (?<end_month>(?<month>(JAN|FEB)))\s
    (?<day>\d{2})
  }xi
  md = multi_months.match('1998 JAN-FEB 24')
  # <MatchData "1998 JAN-FEB 24" year:"1998" start_month:"JAN" month:"JAN"
  #             end_month:"FEB" month:"FEB" day:"24">

  it 'zip clobbers the day with the last month' do
    expect(md.names.zip(md.captures).to_h['day']).to eq('FEB')
  end

  it 'mapping gives us the correct named captures' do
    expect(md.names.map { |n| [n, md[n]] }.to_h['day']).to eq('24')
  end

  it 'named_captures in Ruby 2.4 gives us the correct named captures' do
    expect(md.named_captures['day']).to eq('24')
  end
end

describe 'fix_months' do
  it 'removes bogus month and looksup' do
    multi_months = %r{
      (?<year>\d{4})\s
      (?<start_month>(?<month>(JAN|FEB)))-
      (?<end_month>(?<month>(JAN|FEB)))\s
      (?<day>\d{2})
    }xi
    ec = multi_months.match('1998 JAN-FEB 24').named_captures
    fixed = Series.fix_months(ec)
    expect(fixed['month']).to be_nil
    expect(fixed['end_month']).to eq('February')
  end

  it 'converts numbered months to text months' do
    ec = /(?<month>\d{1,2})/.match('08').named_captures
    expect(Series.fix_months(ec)['month']).to eq('August')
  end
end

describe 'parse_ec' do
  it 'parses "V. 3:PT. 2 1972"' do
    expect(Series.parse_ec('V. 3:PT. 2 1972')['part']).to eq('2')
  end

  it 'parses "V. 3:PT. 2 1972"' do
    expect(Series.parse_ec('V. 3:PT. 2 1972')['part']).to eq('2')
  end

  it 'looksup months' do
    expect(Series.parse_ec('OCT.')['month']).to eq('October')
  end

  it 'parses "NOV 1977"' do
    expect(Series.parse_ec('NOV 1977')['month']).to eq('November')
  end

  it 'parses "Year:1977, Month:November"' do
    expect(Series.parse_ec('Year:1977, Month:November')['month']).to eq('November')
  end

  it 'parses "1976 SEP-OCT"' do
    expect(Series.parse_ec('1976 SEP-OCT')['start_month']).to eq('September')
  end

  it 'removes erroneous months' do
    expect(Series.parse_ec('1976 SEP-OCT')['month']).to be_nil
  end

  it 'parses "NO. 9 SEPT. 1975"' do
    expect(Series.parse_ec('NO. 9 SEPT. 1975')['number']).to eq('9')
    expect(
      Series.parse_ec('Year:1975, Month:September, Number:9')['month']
    ).to eq('September')
  end

  it 'parses "NO. 165 PT. 2"' do
    expect(Series.parse_ec('NO. 165 PT. 2')['number']).to eq('165')
    expect(Series.parse_ec('NO. 165 PT. 2')).to eq('number' => '165',
                                                   'part' => '2')
  end

  it 'parses "NO. 1531 (1976)"' do
    expect(Series.parse_ec('NO. 1531 (1976)')['number']).to eq('1531')
  end
end

describe 'Series.lookup_month' do
  it 'returns August for aug' do
    expect(Series.lookup_month('aug.')).to eq('August')
  end

  it 'returns June for JE.' do
    expect(Series.lookup_month('JE.')).to eq('June')
  end

  it 'returns nil for SUP' do
    expect(Series.lookup_month('SUP')).to be_nil
  end

  it 'returns "April" for "4" and "04"' do
    expect(Series.lookup_month('4')).to eq('April')
    expect(Series.lookup_month('04')).to eq('April')
    expect(Series.lookup_month('13')).to be_nil
  end
end

describe 'Series.correct_year' do
  it 'handles 21st century' do
    expect(Series.correct_year('005')).to eq('2005')
  end

  it 'handles 19th centruy' do
    expect(Series.correct_year(895)).to eq('1895')
  end

  # TODO: not entirely sure what we should do with these.
  # Should we return nil?
  it 'handles bogus centuries' do
    expect(Series.correct_year(650)).to eq('2650')
  end
end

describe 'all Series' do
  Registry::Series.constants.select { |c| eval(c.to_s).class == Module }.each do |c|
    s = Class.new { extend eval(c.to_s) }
    it 'the canonicalize method returns nil if {} given' do
      puts c
      expect(s.respond_to?(:canonicalize)).to be_truthy
      expect(s.canonicalize({})).to be_nil
    end

    it "fails to explode if it can't canonicalize" do
      expect(s.respond_to?(:explode)).to be_truthy
      expect(s.explode('string' => 'cant_canonicalize_this').keys.count).to eq(0)
    end
  end
end
