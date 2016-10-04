require 'pp'
require 'source_record'
=begin
=end

module UnitedStatesReports
  #include EC
  class << self; attr_accessor :years, :editions end
  @years = {}
  @editions = {}

  def self.sudoc_stem
    'JU 6.8'
  end

  def self.oclcs 
    [10648533, 1768670]
  end
  
  def self.parse_ec ec_string
=begin
    #some junk in the front
    ec_string.gsub!(/REEL \d+.* P77-/, '')
    ec_string.gsub!(/^A V\./, 'V.')
    ec_string.gsub!(/^: /, '')

    #space before trailing ) is always a typo
    ec_string.gsub!(/ \)/, ')')

    #trailing junk
    ec_string.gsub!(/[,: ]$/, '')  

    #remove unnecessary crap
    ec_string.gsub!(/ ?= ?[0-9]+.*/, '')

    #remove useless 'copy' information
    ec_string.gsub!(/ C(OP)?\. \d$/, '')

    #we don't care about withdrawn status for enumchron parsing
    ec_string.gsub!(/ - WD/, '')

    #fix the three digit years
    if ec_string =~ /^[89]\d\d[^0-9]*/
      ec_string = '1' + ec_string
    end
    #seriously 
    if ec_string =~ /^0\d\d[^0-9]*/
      ec_string = '2' + ec_string
    end

    #sometimes years get duplicated
    ec_string.gsub!(/(?<y>\d{4}) \k<y>/, '\k<y>')

    #simple year
    #2008 /* 257 */
    #(2008)
    m ||= /^\(?(?<year>\d{4})\)?$/.match(ec_string)

    #edition prefix /* 316 */
    #101ST 1980
    #101ST (1980)
    #101ST ED. 1980
    #101ST ED. (1980)
    m ||= /^(?<edition>\d{1,3})(TH|ST|ND|RD)? (ED\.)? ?\(?(?<year>\d{4})\)?$/.match(ec_string)

    # edition/volume prefix then year /* 177 */
    # V. 2007
    # V. 81 1960
    # V. 81 (1960)
    # V. 81 (960)
    m ||= /^V\. ?(NO\.? )?(?<edition>\d{1,3})? \(?(?<year>\d{3,4})\)?$/.match(ec_string)

    # just edition/volume /* 55 */
    m ||= /^(V\.? ? )?(?<edition>\d{1,3})$/.match(ec_string)

    #1971 (92ND ED. ) /* 83 */
    #1971 92ND ED.
    m ||= /^(?<year>\d{4}) \(?(?<edition>\d{1,3})(TH|ST|ND|RD) ED\. ?\)?$/.match(ec_string)

    #1930 (NO. 52) /* 54 */
    m ||= /^(?<year>\d{4}) \(NO\. (?<edition>\d{1,3})\)$/.match(ec_string)

    # edition year /* 66 */
    # 92 1971
    m ||= /^(?<edition>\d{1,3})D? (?<year>\d{4})$/.match(ec_string)

    # 94TH,1973 /* 100 */
    m ||= /^(?<edition>\d{1,3})(TH|ST|ND|RD)?, ?(?<year>\d{4})$/.match(ec_string)

    # 43RD(1920)
    m ||= /^(?<edition>\d{1,3})(TH|ST|ND|RD)\((?<year>\d{4})\)$/.match(ec_string)

    # 54TH NO. 1932 /* 54 */
    m ||= /^(?<edition>\d{1,3})(TH|ST|ND|RD) NO\. (?<year>\d{4})$/.match(ec_string)

    # 110TH /* */
    # 110TH ED.
    m ||= /^(?<edition>\d{1,3})(TH|ST|ND|RD)( ED\.)?$/.match(ec_string)

    # V. 2010 129 ED /* 13 */
    # V. 2010 ED 129
    m ||= /^V\. (?<year>\d{4}) (ED\.? )?(?<edition>\d{1,3})( ED\.?)?$/.match(ec_string)


    #year range /* */
    # 989-990
    # 1961-1963
    # V. 2004-2005 124
    m ||= /^(V\. )?(?<start_year>\d{4})[-\/](?<end_year>\d{2,4})( (?<edition>\d{1,3}))?$/.match(ec_string)


    #122ND ED. (2002/2003)
    #103RD (1982-1983)
    #122ND EDITION 2002
    #122ND ED. (2002/2003)
    #122ND EDITION 2002
    # 103RD ED. (1982-1983)
    m ||= /^(?<edition>\d{1,3})(TH|ST|ND|RD)( ED\.| EDITION)? \(?((?<year>\d{4})|(?<start_year>\d{4})[\/-](?<end_year>\d{2,4}))\)?$/.match(ec_string)

    # ED. 127 2008
    # V. 103 1982-83
    # V. 103 1982/83
    m ||= /^(ED\.|V\.) (?<edition>\d{1,3}) ((?<year>\d{4})|(?<start_year>\d{4})[-\/](?<end_year>\d{2,4}))$/.match(ec_string)

    # 26-27 (903-904)
    m ||= /^(?<start_edition>\d{1,2})-(?<end_edition>\d{1,2}) \((?<start_year>\d{3,4})-(?<end_year>\d{3,4})\)$/.match(ec_string)

    # 1973-1974 P83-1687
    m ||= /^(?<start_year>\d{4})-(?<end_year>\d{2,4}) P83.*/.match(ec_string)

    # 1878-82 (NO. 1-5)
    # 1883-87 (NO. 6-10)
    # 1944-45 (NO. 66)
    m ||= /^(?<start_year>\d{4})-(?<end_year>\d{2,4}) \(NO\. ((?<start_edition>\d{1,3})-(?<end_edition>\d{1,3})|(?<edition>\d{1,3}))\)$/.match(ec_string)

    # 101(1980)
    # 103 1982-83
    # 103D 1982-83
    # 103RD,1982/83
    m ||= /^(?<edition>\d{1,3})(TH|ST|ND|RD|D)?[\( ,]\(?((?<start_year>\d{4})[-\/](?<end_year>\d{2,4})|(?<year>\d{4}))\)?$/.match(ec_string)

    # V. 16-17 1893-94
    # V. 7-8 1884-85
    # V. 9-11 1887-1889
    m ||= /^V\. (?<start_edition>\d{1,3})-(?<end_edition>\d{1,3}) (?<start_year>\d{4})-(?<end_year>\d{2,4})$/.match(ec_string)

    # (2004-2005)
    m ||= /^\((?<start_year>\d{4})-(?<end_year>\d{2,4})\)$/.match(ec_string)

    # 11 (888)
    # 49 (926 )
    # NO. 20(1897)
    m ||= /^(NO\. )?(?<edition>\d{1,3}) ?\((?<year>\d{3,4}) ?\)$/.match(ec_string)
    

    # 130H ED. (2011)
    # 130TH ED. ,2011
    # 131ST ED. ,2012
    m ||= /^(?<edition>\d{1,3})(H|TH|ST|ND|RD|D)? ED[\.,] [\(,]?(?<year>\d{4})\)?$/.match(ec_string)

    # 12TH-13TH,1889-90
    # 12TH-13TH NO. 1889-1890
    # 14TH-15TH,1891-92
    # 16TH-17TH,1893-94
    # 1ST-4TH NO. 1878-1881
    # 10TH-11TH NO. 1887-1888
    m ||= /^(?<start_edition>\d{1,3})(TH|ST|ND|RD)-(?<end_edition>\d{1,3})(TH|ST|ND|RD)(,| NO\. )(?<start_year>\d{4})-(?<end_year>\d{2,4})$/.match(ec_string)

    # 1982-83 (103RD ED.)
    # 1982/83 (103RD ED.)
    m ||= /^(?<start_year>\d{4})[-\/](?<end_year>\d{2,4}) \(?(?<edition>\d{1,3})(TH|ST|ND|RD) ED\.\)?$/.match(ec_string)

    # broader than it should be, but run close to last it should be okay
    # 1988 (108TH EDITION)
    # 2006, 125TH ED.
    m ||= /^(V\. )?(?<year>\d{4})[, ]\D+(?<edition>\d{1,3})(\D+|$)/.match(ec_string)

    # hypothetical
    # 7TH-9TH
    m ||= /^(?<start_edition>\d{1,3})(TH|ST|ND|RD)-(?<end_edition>\d{1,3})(TH|ST|ND|RD)$/.match(ec_string)
    
    # 129TH ED. 2010 129 ED.
    # 129 2010 ED. 129
    m ||= /^(?<edition>\d{1,3})(TH|ST|ND|RD| )\D*(?<year>\d{4})(\D|$)/.match(ec_string)
=end
    if !m.nil?
      ec = Hash[ m.names.zip( m.captures ) ]
      #remove nils
      ec.delete_if {|k, v| v.nil? }
      if ec.key? 'year' and ec['year'].length == 3
        if ec['year'][0] == '8' or ec['year'][0] == '9'
          ec['year'] = '1' + ec['year']
        else
          ec['year'] = '2' + ec['year']
        end
      end
      
      if ec.key? 'start_year' and ec['start_year'].length == 3
        if ec['start_year'][0] == '8' or ec['start_year'][0] == '9'
          ec['start_year'] = '1' + ec['start_year']
        else
          ec['start_year'] = '2' + ec['start_year']
        end
      end

      if ec.key? 'end_year' and /^\d\d$/.match(ec['end_year'])
        if ec['end_year'].to_i < ec['start_year'][2,2].to_i
          # crosses century. e.g. 1998-01
          ec['end_year'] = (ec['start_year'][0,2].to_i + 1).to_s + ec['end_year']
        else
          ec['end_year'] = ec['start_year'][0,2]+ec['end_year']
        end
      elsif ec.key? 'end_year' and /^\d\d\d$/.match(ec['end_year'])
        if ec['end_year'].to_i < 700 #add a 2; 1699 and 2699 are both wrong, but...
          ec['end_year'] = '2'+ec['end_year']
        else
          ec['end_year'] = '1'+ec['end_year']
        end
      end 
    end
    ec  #ec string parsed into hash
  end


  # Take a parsed enumchron and expand it into its constituent parts
  # Real simple for this series because we have the complete list and can
  # perform a lookup using edition or year. 
  # enum_chrons - { <canonical ec string> : {<parsed features>}, }
  #
  # Canonical string format: <edition number>, <year>-<year>
  def self.explode ec
    enum_chrons = {} 
    if ec.nil?
      return {}
    end
=begin
    #we will trust edition more than year so start there
    if ec['edition']
      canon = StatisticalAbstract.editions[ec['edition']]
      if canon
        enum_chrons[canon] = ec
      end
    elsif ec['start_edition'] and ec['end_edition']
      #might end up with duplicates for the combined years. Won't matter
      for ed in ec['start_edition']..ec['end_edition']
        canon = StatisticalAbstract.editions[ed]
        if canon
          enum_chrons[canon] = ec
        end
      end
    elsif ec['year'] 
      canon = StatisticalAbstract.years[ec['year']]
      if canon
        enum_chrons[canon] = ec
      end
    elsif ec['start_year'] and ec['end_year']
      for y in ec['start_year']..ec['end_year']
        canon = StatisticalAbstract.years[y]
        if canon
          enum_chrons[canon] = ec
        end
      end
    end #else enum_chrons still equals {}
=end 
    enum_chrons
  end

  def self.parse_file
    @no_match = 0
    @match = 0
    input = File.dirname(__FILE__)+'/../data/usreports_enumchrons.txt'
    open(input, 'r').each do | line |
      line.chomp!

      ec = self.parse_ec(line)
      if ec.nil? or ec.length == 0
        @no_match += 1
        puts "no match: "+line
      else 
        #puts "match: "+self.explode(ec).to_s
        @match += 1
      end

    end

    puts "US Reports match: #{@match}"
    puts "US Reports no match: #{@no_match}"
    return @match, @no_match
  end

  def self.load_context 
  end
  self.load_context
end
