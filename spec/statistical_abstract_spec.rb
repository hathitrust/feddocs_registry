require 'statistical_abstract'
require 'json'

describe "parse_ec" do
  it "can handle a single year" do
    expect(StatisticalAbstract.parse_ec('1980')['year']).to eq('1980')
  end

  it "fixes 3 digit years" do
    expect(StatisticalAbstract.parse_ec('980')['year']).to eq('1980')
    expect(StatisticalAbstract.parse_ec('26-27 (903-904)')['start_year']).to eq('1903')
    expect(StatisticalAbstract.parse_ec('26-27 (903-904)')['end_year']).to eq('1904')
    expect(StatisticalAbstract.parse_ec('26-27 (903-904)')['end_edition']).to eq('27')
  end

  it "parses 'V. 2007' and 'V. 81 1960'" do
    expect(StatisticalAbstract.parse_ec('V. 2007')['year']).to eq('2007')
    expect(StatisticalAbstract.parse_ec('V. 81 1960')['year']).to eq('1960')
    expect(StatisticalAbstract.parse_ec('V. 81 1960')['edition']).to eq('81')
  end

  it "parses '92 1971
              92ND (1971)
              92ND,1971
              92ND ED. 1971
              92ND ED. (1971)'" do
    expect(StatisticalAbstract.parse_ec('92 1971')['year']).to eq('1971')
    expect(StatisticalAbstract.parse_ec('92ND (1971)')['year']).to eq('1971')
    expect(StatisticalAbstract.parse_ec('92ND,1971')['year']).to eq('1971')
    expect(StatisticalAbstract.parse_ec('92ND ED. 1971')['year']).to eq('1971')
    expect(StatisticalAbstract.parse_ec('92ND ED. (1971)')['year']).to eq('1971')
  end
  
  it "parses '1930 (NO. 52)'" do
    expect(StatisticalAbstract.parse_ec('1930 (NO. 52)')['year']).to eq('1930')
  end

  it "parses '1971 (92ND ED. )
              1971 92ND ED.'" do
    expect(StatisticalAbstract.parse_ec('1971 (92ND ED. )')['year']).to eq('1971')
    expect(StatisticalAbstract.parse_ec('1971 92ND ED.')['year']).to eq('1971')
  end

  it "deletes 'copy' nonsense" do
    expect(StatisticalAbstract.parse_ec('1921 COP. 2')['year']).to eq('1921')
    expect(StatisticalAbstract.parse_ec('1921 C. 2')['year']).to eq('1921')
  end

  it "fixes 2 and 3 digit years" do
    expect(StatisticalAbstract.parse_ec('1998-01')['end_year']).to eq('2001')
    expect(StatisticalAbstract.parse_ec('1898-903')['end_year']).to eq('1903')
    expect(StatisticalAbstract.parse_ec('1988-1993')['end_year']).to eq('1993')
  end



end

describe "explode" do
  it "should explode ranges" do
    expect(StatisticalAbstract.explode(StatisticalAbstract.parse_ec('1974-1977')).count).to eq(4)
  end

  it "should not explode 1944-1945" do
    expect(StatisticalAbstract.explode(StatisticalAbstract.parse_ec('1944-1945')).count).to eq(1)
  end

  it "should explode certain editions" do
    expect(StatisticalAbstract.explode(StatisticalAbstract.parse_ec('7TH-9TH')).count).to eq(2)
  end

end

describe "parse_file" do
  it "parses a file of enumchrons" do 
    #match, no_match = StatisticalAbstract.parse_file
    #expect(match).to eq(1566) #actual number in test file is 1566
  end
end

describe "oclcs" do
  it "has an oclcs field" do
    expect(StatisticalAbstract.oclcs).to include(1193890)
  end
end
