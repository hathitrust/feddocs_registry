include Registry::Series
Series = Registry::Series
require 'registry/source_record' 
SourceRecord = Registry::SourceRecord

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

describe 'preprocess' do
  it 'removes copy information' do
    expect(Series.preprocess('C. 1 V. 5 1990 PP. 4783-5463')).to eq('V. 5 1990 PP. 4783-5463')
  end
end

describe 'remove_dupe_years' do
  it 'cuts off duplicate years' do
    ec_string = 'V. 91, NO. 13-18 1999 1999'
    expect(Series.remove_dupe_years(ec_string)).to eq('V. 91, NO. 13-18 1999')
    ec_string = 'V. 91, NO. 13-18 1999 2000'
    expect(
      Series.remove_dupe_years(ec_string)
    ).to eq('V. 91, NO. 13-18 1999 2000')
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

describe 'ec_handler' do
  it 'gives us default handler if no series matches' do
    rec = SourceRecord.new(oclc_resolved:[],
                           sudocs:[])
    expect(rec.ec_handler.title).to eq('Default Series Handler')
  end

  it 'gives us a particular handler if a series does match' do
    rec = SourceRecord.new(oclc_resolved:[14_964_165],
                           sudocs:[])
    #expect(rec.series).to eq(['FCCRecord'])
    expect(rec.ec_handler.title).to eq('FCC Record')
  end
end

describe 'parse_ec' do
  it 'parses "V. 8:NO. 6 (1993:MAR. 19)"' do
    expect(Series.parse_ec('V. 8:NO. 6 (1993:MAR. 19)')['month']).to eq('March')
  end

  it 'parses "V. 16, NO. 12 (APR. 2001)"' do
    expect(Series.parse_ec('V. 16, NO. 12 (APR. 2001)')['month']).to eq('April')
    expect(Series.parse_ec('V. 12, NO. 29, (OCT. 1997)')['month']).to eq('October')
  end

  it 'parses "1896 PT. 1"' do
    expect(Series.parse_ec('1896 PT. 1')['part']).to eq('1')
  end

  it 'parses "1896 V. 2 PT. 1"' do
    expect(Series.parse_ec('1896 V. 2 PT. 1')['part']).to eq('1')
  end

  it 'parses "V. 2, NO. 25-26 (DEC. 1987)"' do
    expect(Series.parse_ec('V. 2, NO. 25-26 (DEC. 1987)')['month']).to eq('December')
  end

  it 'parses "V. 2, NO. 25-26 (JUL. -AUG. 1995)"' do
    expect(Series.parse_ec('V. 2, NO. 25-26 (JUL. -AUG. 1995)')['end_month']).to eq('August')
  end

  it 'parses "V. 30NO. 6 2015"' do
    expect(Series.parse_ec('V. 30NO. 6 2015')['number']).to eq('6')
  end

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

  it 'parses "NO. 42 (2005:APR. 13)"' do
    expect(Series.parse_ec('NO. 42 (2005:APR. 13)')['number']).to eq('42')
  end

  it 'parses "1988:MAY 17"' do
    expect(Series.parse_ec('1988:MAY 17')['day']).to eq('17')
  end

  it 'parses "NO. 165 PT. 2"' do
    expect(Series.parse_ec('NO. 165 PT. 2')['number']).to eq('165')
    expect(Series.parse_ec('NO. 165 PT. 2')).to eq('number' => '165',
                                                   'part' => '2')
  end

  it 'parses "NO. 1531 (1976)"' do
    expect(Series.parse_ec('NO. 1531 (1976)')['number']).to eq('1531')
  end

  it 'parses "V. 24:NO. 1(2009)"' do
    expect(Series.parse_ec('V. 24:NO. 1(2009)')['year']).to eq('2009')
    expect(Series.parse_ec('V. 22:NO. 8 (2007)')['year']).to eq('2007')
    expect(Series.parse_ec('V. 16,NO. 23 2001 SEP.')['year']).to eq('2001')
    expect(Series.parse_ec('V. 12 NO. 37 1997 SUP.')['supplement']).to eq('Supplement')
  end

  it 'parses "V. 27, NO. 13 (SEPTEMBER 21 - SEPTEMBER 28, 2012)"' do
    expect(Series.parse_ec('V. 27, NO. 13 (SEPTEMBER 21 - SEPTEMBER 28, 2012)')['end_month']).to eq('September')
  end

  it 'parses "V. 5 NO. 12-13"' do
    expect(Series.parse_ec('V. 5 NO. 12-13')['start_number']).to eq('12')
  end

  it 'parses "V. 8:NO. 19-22 1993"' do
    expect(Series.parse_ec('V. 8:NO. 19-22 1993')['end_number']).to eq('22')
  end

  it 'parses "V. 9 PG. 1535-2248 1994"' do
    expect(Series.parse_ec('V. 9 PG. 1535-2248 1994')['start_page']).to eq('1535')
  end

  it 'parses "V. 5 1990 PP. 4783-5463"' do
    expect(Series.parse_ec('V. 5 1990 PP. 4783-5463')['start_page']).to eq('4783')
  end

  it 'parses "2012 FEB. 21-MAR. 16"' do
    expect(Series.parse_ec('2012 FEB. 21-MAR. 16')['end_month']).to eq('March')
  end

  it 'parses "2013 FEB. 1-26"' do
    expect(Series.parse_ec('2013 FEB. 1-26')['end_day']).to eq('26')
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

  it 'returns "January" for "JA"' do
    expect(Series.lookup_month('JA')).to eq('January')
  end

  it 'returns "March" for "MR"' do
    expect(Series.lookup_month('MR')).to eq('March')
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
