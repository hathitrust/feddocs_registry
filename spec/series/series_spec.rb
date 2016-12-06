
describe "calc_end_year" do
  it "handles simple 3 digit years" do
    expect(calc_end_year("1995", "998")).to eq("1998")
  end

  it "handles simple 2 digit years" do
    expect(calc_end_year("1995", "98")).to eq("1998")
  end

  it "handles 3 character rollovers" do
    expect(calc_end_year("1999", "002")).to eq("2002")
  end

  it "handles 2 character rollovers" do
    expect(calc_end_year("1999", "02")).to eq("2002")
  end

end
