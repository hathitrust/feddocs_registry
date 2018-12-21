require 'json'

FCCR = ECMangle::FCCRecord

pages_to_numbers = {} # [<start>, <end>] => [<start>, <end>]

describe 'FCCRecord' do
  let(:fcc) { FCCR.new }

  describe 'parse_ec' do
    it 'can parse them all' do
      matches = 0
      misses = 0
      input = File.dirname(__FILE__) +
              '/data/fcc_record_ecs.txt'
      output = File.open('canonicals.tmp', 'w')
      File.open(input, 'r').each do |line|
        line.chomp!
        ec = fcc.parse_ec(line)
        if (ec.nil? || ec.empty?) && line !~ /^KF/
          misses += 1
          # puts 'no match: ' + line
        else
          res = fcc.explode(ec)
          res.each_key do |canon|
            output.puts canon + "\t" + line
          end
          if ec['start_page'] && (ec['number'] || ec['start_number'])
            ec['start_number'] ||= ec['number']
            ec['end_number'] ||= ec['number']
            pages_to_numbers[
              [ec['volume'],
               ec['start_page']]] = (ec['start_number'] || ec['number'])
          end
          matches += 1
        end
      end
      # p_t_n = File.open('pages_to_numbers.tmp', 'w')
      # p_t_n.puts pages_to_numbers.to_json()
      puts "FCC Record match: #{matches}"
      puts "FCC Record no match: #{misses}"
      expect(matches).to eq(9402) # actual 10106
    end
  end

  describe 'title' do
    it 'has a title' do
      expect(FCCR.new.title).to eq('FCC Record')
    end
  end

  describe 'oclcs' do
    it 'has an oclcs field' do
      expect(FCCR.new.ocns).to eq([14_964_165,
                                25_705_333,
                                31_506_723,
                                52_110_163,
                                58_055_590,
                                70_896_877])
    end
  end

  describe 'canonicalize' do
    it 'canonicalizes "V. 7 NO. 18"' do
      expect(fcc.canonicalize(fcc.parse_ec('V. 7 NO. 18'))).to eq('Volume:7, Number:18')
    end
  end

  describe 'parse_ec' do
    it 'parses "V. 11 NO. 32 SUP. 1996"' do
      expect(fcc.parse_ec('V. 11 NO. 32 SUP. 1996')['year']).to eq('1996')
      expect(fcc.parse_ec('V. 13,NO. 21 SUP.')['number']).to eq('21')
    end

    it 'parses "11/NOS. 30-31"' do
      expect(fcc.parse_ec('11/NOS. 30-31')['end_number']).to eq('31')
    end

    it 'parses "V. V. 17:17 JUN 21 - JUN 28 2002"' do
      expect(fcc.parse_ec('V. V. 17:17 JUN 21 - JUN 28 2002')['number']).to eq('17')
      expect(fcc.parse_ec('V. 15:34 (NOV 13/24, 2000)')['end_day']).to eq('24')
      expect(fcc.parse_ec('V. 15:33 (OCT 30/NOV 9, 2000)')['end_day']).to eq('9')
      expect(fcc.parse_ec('V. 24 NO. 2 JAN. 19-FEB 13, 2009')['end_day']).to eq('13')
    end

    it 'parses "V. V. 14:10"' do
      expect(fcc.parse_ec('V. V. 14:10')['number']).to eq('10')
      expect(fcc.parse_ec('V. V. 12:35 1997')['year']).to eq('1997')
      expect(fcc.parse_ec('V. V. 16:3 SUP')['supplement']).to eq('SUP')
    end

    it 'parses "16/9/SUP"' do
      expect(fcc.parse_ec('16/9/SUP')['number']).to eq('9')
    end

    it 'parses "3/16-18"' do
      expect(fcc.parse_ec('3/16-18')['start_number']).to eq('16')
      expect(fcc.parse_ec('8/21-22 (OCT 4-29, 1993)')['end_day']).to eq('29')
      expect(fcc.parse_ec('3/18-20 (AUG. 29-OCT. 7, 1988)')['start_number']).to eq('18')
      expect(fcc.parse_ec('11/32-33 1996')['start_number']).to eq('32')
      expect(fcc.parse_ec('V. 12:23-24 1997')['start_number']).to eq('23')
    end

    it 'parses "V. 6:10-11 (MAY 1991)"' do
      expect(fcc.parse_ec('V. 6:10-11 (MAY 1991)')['end_number']).to eq('11')
    end

    it 'parses "C. 1 V. 5 1990 PP. 4783-5463"' do
      expect(fcc.parse_ec('C. 1 V. 5 1990 PP. 4783-5463')['start_page']).to eq('4783')
    end

    it 'parses "V. 12 NO. 17 P. 9617-10204 1997"' do
      expect(fcc.parse_ec('V. 12 NO. 17 P. 9617-10204 1997')['end_page']).to eq('10204')
      expect(fcc.parse_ec('V. 9 NO. 15-16 P. 3239-3956 1994')['end_number']).to eq('16')
    end

    it 'parses "V. 7:P. 3755/4833(1992)"' do
      expect(fcc.parse_ec('V. 7:P. 3755/4833(1992)')['end_page']).to eq('4833')
    end

    it 'parses "V9NO11-12 1994"' do
      expect(fcc.parse_ec('V9NO11-12 1994')['end_number']).to eq('12')
      expect(fcc.parse_ec('V. 12NO. 7-8 1997')['end_number']).to eq('8')
    end

    it 'parses "V. 13:21 SUP. (1998)"' do
      expect(fcc.parse_ec('V. 13:21 SUP. (1998)')['number']).to eq('21')
    end

    it 'parses "V. 13:P. 19401/20049(1997/1998)"' do
      expect(fcc.parse_ec('V. 13:P. 19401/20049(1997/1998)')['end_page']).to eq('20049')
    end

    it 'parses "V. 5:22-23 (OCT-NOV 1990)"' do
      expect(fcc.parse_ec('V. 5:22-23 (OCT-NOV 1990)')['end_month']).to eq('November')
    end

    it 'parses "V. 6:NO. 19-22 1991:SEPT. 9-NOV. 1"' do
      expect(fcc.parse_ec('V. 6:NO. 19-22 1991:SEPT. 9-NOV. 1')['end_month']).to eq('November')
      expect(fcc.parse_ec('V. 6:NO. 21-22(1991:OCT. 7-NOV. 1) <P. 5732-6472>')['end_page']).to eq('6472')
    end

    it 'parses "V. 21:NO. 1 2006:JAN. 3-31"' do
      expect(fcc.parse_ec('V. 21:NO. 1 2006:JAN. 3-31')['end_day']).to eq('31')
      expect(fcc.parse_ec('V. 15:8(2000:MARCH 6-17)')['end_day']).to eq('17')
      expect(fcc.parse_ec('V. 21:NO. 1(2006:JAN. 3/31)')['end_day']).to eq('31')
      expect(fcc.parse_ec('V. 21:NO. 1(2006:JAN. 3/JAN. 31) <P. 1-945>')['end_day']).to eq('31')
      expect(fcc.parse_ec('V. 8:NO. 15 (1993:JULY 12/23) <P. 1-945>')['end_day']).to eq('23')
    end

    it 'parses "V. 23(2008) P. 8153-9023"' do
      expect(fcc.parse_ec('V. 23(2008) P. 8153-9023')['end_page']).to eq('9023')
      expect(fcc.parse_ec('V. 18:NO. 12(2003) P. 9282-10332')['end_page']).to eq('10332')
    end

    it 'parses "V. 16,NO. 20 2001 JULY-AUG."' do
      expect(fcc.parse_ec('V. 16,NO. 20 2001 JULY-AUG.')['end_month']).to eq('August')
    end

    it 'parses "V. 17:NO. 27(2001/02):P. 20086-20779"' do
      expect(fcc.parse_ec('V. 17:NO. 27(2001/02):P. 20086-20779')['end_page']).to eq('20779')
      expect(fcc.parse_ec('V. 22:NO. 13(2007)P. 9864-10683')['end_page']).to eq('10683')
    end

    it 'parses "V. 14 NO. 1 1998-1999"' do
      expect(fcc.parse_ec('V. 14 NO. 1 1998-1999')['end_year']).to eq('1999')
      expect(fcc.parse_ec('V. 14 NO. 1 1998/99')['end_year']).to eq('1999')
    end

    it 'parses "V. V. 25:21,P. 17467-18163,DEC 20-31 2010"' do
      expect(fcc.parse_ec('V. V. 25:21,P. 17467-18163,DEC 20-31 2010')['end_day']).to eq('31')
      expect(fcc.parse_ec('V. V. 25:2, P. 830-1765, JAN 22-FEB 19 2010')['end_month']).to eq('February')
    end

    it 'parses "V. 2 NO. 1-4 PG. 1-1358 1987"' do
      expect(fcc.parse_ec('V. 2 NO. 1-4 PG. 1-1358 1987')['end_page']).to eq('1358')
    end

    it 'parses "V. 8:25-26 N29-D23(1993)"' do
      expect(fcc.parse_ec('V. 8:25-26 N29-D23(1993)')['end_day']).to eq('23')
      expect(fcc.parse_ec('V. 8:25-26 N29-D23(1993)')['end_month']).to eq('December')
      expect(fcc.parse_ec('V. 12:20 JY28-AG8(1997)')['end_month']).to eq('August')
      expect(fcc.parse_ec('V. 9:26 D12-23(1994)')['start_month']).to eq('December')
      expect(fcc.parse_ec('12/13-14 JE. 2-13 1997')['end_day']).to eq('13')
    end

    it 'parses "13/NO. 13"' do
      expect(fcc.parse_ec('13/NO. 13')['volume']).to eq('13')
    end

    it 'parses "13/17-18 JE. 15-JL. 10 1998"' do
      expect(fcc.parse_ec('14/5-6 F. 8-MR. 5 1999')['end_day']).to eq('5')
      expect(fcc.parse_ec('13/17-18 JE. 15-JL. 10 1998')['end_day']).to eq('10')
      expect(fcc.parse_ec('V. 15 NO. 15-16 MY. 15-JE. 9 2000')['end_day']).to eq('9')
    end

    it 'parses "V. 2:20-22 S-N(1987)"' do
      expect(fcc.parse_ec('V. 2:20-22 S-N(1987)')['end_month']).to eq('November')
    end
  end

  describe 'numbers_from_pages' do
    it 'retrieves numbers using page numbers' do
      parsed = fcc.parse_ec('V. 7:P. 3755/4833(1992)')
      expect(fcc.numbers_from_pages(parsed)['end_number']).to eq('15')
    end

    it 'returns nil if it cant do anything' do
      parsed = fcc.parse_ec('V. 7:P. 3756/4834(1992)')
      expect(fcc.numbers_from_pages(parsed)['start_number']).to be_nil
    end
  end

  describe 'explode' do
    it 'explodes number ranges' do
      parsed = fcc.parse_ec('V. 7:P. 3755/4833(1992)')
      expect(fcc.explode(parsed).keys).to eq(['Volume:7, Number:13',
                                              'Volume:7, Number:14',
                                              'Volume:7, Number:15'])
    end
  end

  describe 'load_context' do
    it 'can look up some numbers' do
      expect(FCCR.pages_to_numbers[%w[9 3013].to_s]).to eq('14')
    end
  end
end
