require 'json'

DAGL = ECMangle::DepartmentOfAgricultureLeaflet

describe 'DepartmentOfAgricultureLeaflet' do
  let(:src) { DAGL.new }

  describe 'parse_ec' do
    it 'can parse them all' do
      matches = 0
      misses = 0
      input = File.dirname(__FILE__) +
              '/data/department_of_agriculture_leaflet_ecs.txt'
      output = File.open('canonicals.tmp', 'w')
      File.open(input, 'r').each do |line|
        line.chomp!
        ec = src.parse_ec(line)
        if ec.nil? || ec.empty?
          misses += 1
          # puts 'no match: ' + line
        else
          res = src.explode(ec)
          # res.each_key do |canon|
          #  output.puts canon
          # end
          matches += 1
        end
      end
      puts "DAGL match: #{matches}"
      puts "DAGL no match: #{misses}"
      expect(matches).to eq(1203) # actual: 1266
      # expect(matches).to eq(matches + misses)
    end

    it 'parses canonical' do
      expect(src.parse_ec('Number:407, Year:1976, Revision')['year']).to \
        eq('1976')
      expect(src.parse_ec('Number:219, Year:1970, Revision:7')['year']).to \
        eq('1970')
      expect(src.parse_ec('Number:219')['number']).to eq('219')
    end

    it 'parses "NO. 533"' do
      expect(src.parse_ec('NO. 533')['number']).to eq('533')
    end

    it 'parses "550 1969"' do
      expect(src.parse_ec('550 1969')['number']).to eq('550')
    end

    it 'parses "NO. 533 (1974)"' do
      expect(src.parse_ec('NO. 533 (1974)')['number']).to eq('533')
    end

    it 'parses "NO. 187 (1977 REV. )"' do
      expect(src.parse_ec('NO. 187 (1977 REV. )')['rev']).to eq('REV.')
    end

    it 'parses "NO. 268/5 (1969)"' do
      expect(src.parse_ec('NO. 268/5 (1969)')['rev_num']).to eq('5')
    end

    it 'parses "NO. 407REV 1976"' do
      expect(src.parse_ec('NO. 407REV 1976')['rev_num']).to be_nil
      expect(src.parse_ec('NO. 407REV 1976')['rev']).to eq('REV')
    end

    it 'parses "NO. 201-250"' do
      expect(src.parse_ec('NO. 201-250')['start_number']).to eq('201')
    end

    it 'parses "NO. 130 REV. 3 (1940)"' do
      expect(src.parse_ec('NO. 130 REV. 3 (1940)')['rev_num']).to eq('3')
    end
  end

  describe 'tokens.y' do
    it 'matches Year:1984' do
      expect(/#{src.tokens[:y]}/xi.match('Year:1984')['year']).to eq('1984')
    end

    it 'matches "(1984)"' do
      expect(/#{src.tokens[:y]}/xi.match('(1984)')['year']).to eq('1984')
    end
  end

  describe 'tokens.r' do
    it 'matches "Revision"' do
      expect(/#{src.tokens[:r]}/xi.match('Revision')['rev']).to \
        eq('Revision')
    end

    it 'matches "REV."' do
      expect(/#{src.tokens[:r]}/xi.match('REV.')['rev']).to eq('REV.')
    end

    it 'matches "Revision:5" with number' do
      expect(/#{src.tokens[:r]}/xi.match('Revision:5')['rev_num']).to eq('5')
    end
  end

  describe 'canonicalize' do
    it "returns nil if ec can't be parsed" do
      expect(src.canonicalize({})).to be_nil
    end

    it 'turns a parsed ec into a canonical string' do
      ec = { 'number' => '407',
             'year' => '1976',
             'rev' => 'doesntmatter' }
      expect(src.canonicalize(ec)).to eq('Number:407, Year:1976, Revision')
      ec['rev_num'] = 5
      expect(src.canonicalize(ec)).to eq('Number:407, Year:1976, Revision:5')
      ec.delete('rev')
      expect(src.canonicalize(ec)).to eq('Number:407, Year:1976, Revision:5')
    end
  end

  describe 'explode' do
    it 'explodes multiple numbers' do
      expect(src.explode(src.parse_ec('NO. 200-250')).keys[3]).to eq('Number:203')
    end

    it 'ignores years if multiple numbers' do
      expect(src.explode(
        src.parse_ec('NO. 200-250 (1940-49)')
      ).keys[3]).to eq('Number:203')
    end
  end

  describe 'title' do
    it 'has a title' do
      expect(DAGL.new.title).to eq('Department of Agriculture Leaflet')
    end
  end

  describe 'oclcs' do
    it 'has an oclcs field' do
      expect(DAGL.new.ocns).to eq([1_432_804,
                                34_452_947,
                                567_905_741,
                                608_882_398])
    end
  end
end
