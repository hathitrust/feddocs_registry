require 'json'
SourceRecord = Registry::SourceRecord
ER = Registry::Series::EconomicReportOfThePresident
describe "EconomicReportOfThePresident" do 
  let(:src) { Class.new { extend ER }}

  describe "parse_ec" do
    it "can parse them all" do 
      matches = 0
      misses = 0
      can_canon = 0
      cant_canon = 0
      input = File.dirname(__FILE__)+'/data/econreport_enumchrons.txt'
      open(input, 'r').each do |line|
        line.chomp!
        ec = src.parse_ec(line)
        if ec.nil? or ec.length == 0
          misses += 1
          #puts "no match: "+line
        else 
          matches += 1
        end
      end
      expect(matches).to eq(186)
      #expect(matches).to eq(matches+misses)
    end

    it "parses a simple year" do
      expect(src.parse_ec('1964')['year']).to eq('1964')
    end

    it "parses a year with part" do
      expect(src.parse_ec('1964 PT. 4')['year']).to eq('1964')
      expect(src.parse_ec('1964 PT. 4')['part']).to eq('4')
    end
    
    it "parses a year with multiple parts" do
      expect(src.parse_ec('1964 PT. 1-3')['end_part']).to eq('3')
    end

    it "parses multi-years" do
      expect(src.parse_ec('1961-1962')['end_year']).to eq('1962')
    end

    it "eliminates 'C 1' junk" do
      expect(src.parse_ec('C. 1 1988')['year']).to eq('1988')
    end
    
    it "can parse it's own canonical version" do
      expect(src.parse_ec('Year:1972, Part:4')['year']).to eq('1972')
    end

    it "parses the simple sudoc" do
      expect(src.parse_ec('Y 4. EC 7:EC 7/2/2002')['year']).to eq('2002')
    end

  end

  describe "explode" do
    it "handles a simple year" do 
      expect(src.explode(src.parse_ec('1960'), {})).to have_key('Year:1960')
    end

    it "explodes parts" do
      expect(src.explode(src.parse_ec('1966 PT. 1-4'), {})).to have_key('Year:1966, Part:3')
    end

    it "explodes years" do
      expect(src.explode(src.parse_ec('1949-1952'), {})).to have_key('Year:1951')
    end

    it "uses pub_date/sudocs to create a better enum_chron" do
      # this records enum_Chron is 'PT. 2' but has a pub_Date of 1975
      sr = SourceRecord.new
      sr.org_code = "miaahdl"
      sr.source = open(File.dirname(__FILE__)+'/data/econreport_src_pub_date.json').read
      expect(sr.enum_chrons).to include('Year:1975, Part:2')
    end

    it "uses pub_Date/sudocs to create a better enumchron take 2" do
      sr_new = SourceRecord.new
      sr_new.org_code = "miaahdl"
      sr_new.source = open(File.dirname(__FILE__)+'/data/econreport_sudoc_ec.json').read
      expect(sr_new.sudocs).to include('Y 4.EC 7:EC 7/2/962')
      expect(sr_new.enum_chrons).to include('Year:1962')
    end

    it "returns nultiple sets of features" do
      exploded = src.explode(src.parse_ec('1966 PT. 1-4'), {})
      expect(exploded['Year:1966, Part:2']).to_not be(exploded['Year:1966, Part:3'])
    end

      

  end

  describe "parse_file" do
    it "parses a file of enumchrons" do 
      match, no_match = ER.parse_file
      expect(match).to be >= 186
      #expect(match).to eq(206) #actual number in test file is 206
    end
  end

  describe "load_context" do
    it "has a hash of years => parts" do
      expect(ER.class_eval('@@parts')['1975']).to include('2')
    end
  end
    

  describe "sudoc_stem" do 
    it "has a sudoc_stem field" do 
      expect(ER.sudoc_stem).to eq('Y 4.EC 7:EC 7/2/')
    end
  end

  describe "oclcs" do
    it "has an oclcs field" do
      expect(ER.oclcs).to eq([3160302, 8762269, 8762232])
    end
  end
end
