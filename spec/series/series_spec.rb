include Registry::Series
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

describe "lookup_month" do
  it "returns August for aug" do
    expect(lookup_month('aug.')).to eq('August')
  end

  it "returns June for JE." do
    expect(lookup_month('JE.')).to eq('June')
  end
end

describe "all Series" do
  Registry::Series.constants.each do | s |
    s = "Registry::Series::#{s.to_s}"
    if eval(s).respond_to?(:canonicalize)
      it "the canonicalize method returns nil if {} given" do
        puts s
        expect(eval(s).canonicalize({})).to be_nil
      end

      it "fails to explode if it can't canonicalize" do
        expect(eval(s).explode({'string'=>"cant_canonicalize_this"}).keys.count).to eq(0)
      end
    end
        
  end
end


