require 'federal_register'
require 'json'

describe "parse_ec" do
  it "parses 'V. 48:NO. 4 (1983:JAN. 6)'" do
    expect(FederalRegister.parse_ec('V. 48:NO. 4 (1983:JAN. 6)')).to be_truthy
  end

  it "parses 'V. 75:NO. 149(2010)'" do
    expect(FederalRegister.parse_ec('V. 75:NO. 149(2010)')).to be_truthy
  end

  it "parses 'V. 78 NO. 152 AUG 7, 2013'" do
    expect(FederalRegister.parse_ec('V. 78 NO. 152 AUG 7, 2013')).to be_truthy
  end

  it "parses 'V. 1 (1936:MAY 28/JUNE 11)'" do
    expect(FederalRegister.parse_ec('V. 1 (1936:MAY 28/JUNE 11)')["month_end"]).to eq('JUNE')
  end

  it "parses '74,121'" do 
    expect(FederalRegister.parse_ec('74,121')).to be_truthy
  end

  it "parses '1964'" do
    expect(FederalRegister.parse_ec('1964')['year']).to be_truthy
  end

  it "parses 'V. 13'" do
    expect(FederalRegister.parse_ec('V. 13')['volume']).to eq('13')
  end

  it "parses V. 62:NO. 181" do
    expect(FederalRegister.parse_ec('V. 62:NO. 181')['volume']).to eq('62')
  end

  it "parses 'V. 78:NO. 38-75(2013)'" do
    expect(FederalRegister.parse_ec('V. 78:NO. 38-75(2013)')['number_start']).to eq('38')
  end

  it "parses 'V. 78:NO. 160-161(2013:AUG. 19-20)'" do
    expect(FederalRegister.parse_ec('V. 78:NO. 160-161(2013:AUG. 19-20)')['number_end']).to eq("161")
  end
  
  it "parses page numbers: V. 15:P. 2701-4070 1950" do
    expect(FederalRegister.parse_ec('V. 15:P. 2701-4070 1950')['page_end']).to eq('4070')
  end

  it "can't parse page numbers like 'V. 9 (1944:JULY 22:P. 8284-8381)'" do
    expect(FederalRegister.parse_ec('V. 9 (1944:JULY 22:P. 8284-8381')).to be_nil
  end

  it "parses 'V. 78:NO. 164-173(2013:AUG. 23-SEPT. 6)'" do
    expect(FederalRegister.parse_ec('V. 78:NO. 164-173(2013:AUG. 23-SEPT. 6)')['day_end']).to eq('6') 
  end

  it "parses 'V. 47 (1982:JAN. 4-5)' " do
    expect(FederalRegister.parse_ec('V. 47 (1982:JAN. 4-5)')['day_end']).to eq('5') 
  end

  it "parses 'V. 9 (1944:JULY 22:P. 8284-8381)'" do
    expect(FederalRegister.parse_ec('V. 9 (1944:JULY 22:P. 8284-8381)')['page_end']).to eq('8381')
  end

  it "parses 'V. 40 MAY1-9 1975' " do
    expect(FederalRegister.parse_ec('V. 40 MAY1-9 1975')['day_end']).to eq('9')
  end

  it "parse 'V. 3 JAN1-JUN3 1938' " do
    expect(FederalRegister.parse_ec('V. 3 JAN1-JUN3 1938')['month_end']).to eq('JUN')
  end

  it "parses 'V. 4 (1939:DEC. 30)' " do
    expect(FederalRegister.parse_ec('V. 4 (1939:DEC. 30)')['day']).to eq('30')
  end

  it "parses 'V. 3 JAN1-JUN3 1938' " do
    expect(FederalRegister.parse_ec('V. 3 JAN1-JUN3 1938')['day_end']).to eq('3')
  end

  it "parses 'V. 47 JUN29-JUL1 1982 PP. 28067-28894' " do 
    expect(FederalRegister.parse_ec('V. 47 JUN29-JUL1 1982 PP. 28067-28894')['page_end']).to eq('28894')
  end

  it "parses multi-volume sets 'V. 47-50 (1982-85)' " do
    expect(FederalRegister.parse_ec('V. 47-50 (1982-85)')['volume_end']).to eq('50')
  end

  it "converts year to volume" do
    expect(FederalRegister.parse_ec('1983')['volume']).to eq('48')
  end

end

describe "explode" do
  it "creates a single enumchron" do
    expect(FederalRegister.explode(FederalRegister.parse_ec('V. 48:NO. 4')).count).to eq(1)
  end

  it "fills in gaps" do
    expect(FederalRegister.explode(FederalRegister.parse_ec('V. 48: NO. 160-163')).count).to eq(4)
    expect(FederalRegister.explode(FederalRegister.parse_ec('V. 48: NO. 160-163'))).to have_key('Volume:48, Number:162')
    expect(FederalRegister.explode(FederalRegister.parse_ec('V. 75')).count).to eq(250)
  end
end

describe "parse_file" do
  #it "parses a file of enumchrons" do 
  #  match, no_match, ecs = FederalRegister.parse_file
  #  expect(match).to be(8933)
  #  expect(ecs['volume:75, number:5']['month']).to eq('JAN')
  #end
end

describe "load_context" do
  it "loads the volume/year/numbers data" do
    expect(FederalRegister.year_to_vol["1981"]).to eq("46")
    expect(FederalRegister.nums_per_vol["52"]).to eq("251")
  end
end

describe "oclcs" do
  it "has an ocls field" do
    expect(FederalRegister.oclcs).to include(43080713)
  end
end