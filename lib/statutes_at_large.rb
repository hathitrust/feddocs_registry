require 'pp'
require 'source_record'

module StatutesAtLarge
  #include EC
  #attr_accessor :number_counts, :volume_year

  def self.oclcs 
    [1768474,
     4686465,
     3176465,
     3176512, 
     426275236, 
     15347313,
     15280229, 
     17554670, 
     12739515, 
     17273536 
     ]
  end
  
  def self.parse_ec ec_string
    #sometimes has junk in the front
    ec_string.gsub!(/^KF50 \. U5 /, '')

    # 'V. 96:PT. 1 (1984)' /* 517 */
    # V. 114:PART 1 (2000) 
    m ||= /^V\. (?<volume>\d+)[ ,:]P(AR)?T\.? (?<part>\d{1,2}) \(?(?<year>\d{4})\)?$/.match(ec_string)



    # 'V. 99:PT. 1' /* 231 */
    # V. 57/PT. 1
    m ||= /^V\. (?<volume>\d+)[\/:]PT\. (?<part>\d{1,2})$/.match(ec_string)
 
    # KF50 . U5 V. 94 PT. 2  /* 72 */
    # KF50 . U5 V. 78
    #m ||= /^KF50 . U5 V\. (?<volume>\d+)( PT\. (?<part>\d{1,2}))?$/.match(ec_string)  

    #  'V. 96:2 1982' /* 135 */
    m ||= /^V\. (?<volume>\d+):(?<part>\d{1,2}) (?<year>\d{4})$/.match(ec_string)
                                    
    # V. 124:PT. 1:1/1128(2010) /* 5 */
    m ||= /^V\. (?<volume>\d+):PT\. (?<part>\d{1}):(?<start_page>\d{1,4})\/(?<end_page>\d{4})\((?<year>\d{4})\)$/.match(ec_string)
    
    #V. 124, PT. 2 /* 4 */ 
    m ||= /^V\. (?<volume>\d+), PT\. (?<part>\d{1})$/.match(ec_string)

    # 'V. V. 12 1859-1863' /* 30 */
    # V. V. 23 1883-85
    m ||= /^V\. V\. (?<volume>\d{1,2}) (?<start_year>\d{4})-(?<end_year>\d{2,4})$/.match(ec_string)

    # V. V. 32:1 1901-03 /* 7 */
    m ||= /^V\. V\. (?<volume>\d{1,2}):(?<part>\d) (?<start_year>\d{4})-(?<end_year>\d{2,4})$/.match(ec_string)

    # 'V. V. 36 PT1 1909-12  /* 21 */
    # V. V. 36 PT2 1909-1911
    # V. V. 37 PT. 1 1911-12
    m ||= /^V\. V\. (?<volume>\d{1,2}) PT(\. )?(?<part>\d{1,2}) (?<start_year>\d{4})-(?<end_year>\d{2,4})$/.match(ec_string)

    # 102: PT. 3 /* 375 */
    # 102/PT. 3
    # 103: PT. 1989 <- bad
    # 108:PT. 1
    # 113 PT. 2
    m ||= /^(?<volume>\d{2,3})(:| |: |\/)PT\. (?<part>\d)$/.match(ec_string)
 
    # V. 100 PT. 5 /* 370 */
    # V. 100;PT. 5
    # V. 101 1987 PT. 1
    # V. 101:1987:PT. 1
    m ||= /^V\. (?<volume>\d+)[ :;](?<year>\d{4})?[ :;]?PT\. (?<part>\d{1,2})$/.match(ec_string)

    # V. 93  /* 164 */
    # V. 93 1979
    # V. 93 (1979)
    # V. 77A
    # V. 77A 1963
    # V. 77A (1963)    
    m ||= /^V\. (?<volume>\d+A?)( \(?(?<year>\d{4})\)?)?$/.match(ec_string)

    #V. 112:PT. 1,PP. 1/912 (1998) /* 8 */
    m ||= /^V\. (?<volume>\d+):P(ART|T\.) (?<part>\d{1})[,:]PP\. (?<start_page>\d+)[\/-](?<end_page>\d+) \((?<year>\d{4})\)$/.match(ec_string)

    # V. 84:PT. 1 (1970/71) /* 279 */ 
    # V. 84 PT. 2 1970/71
    # V. 84:PT. 2 (1970-71)
    # V. 10 1851-1855
    # V. 10 1851/1855
    # V. 10 (1851/55)
    m ||= /^V\. (?<volume>\d+)([ :]PT\. (?<part>\d))? \(?(?<start_year>\d{4})[-\/](?<end_year>\d{2,4})\)?$/.match(ec_string)

    # V. 44 1925-1926 PT. 1 /* 44 */
    m ||= /^V\. (?<volume>\d+) (?<start_year>\d{4})[\/-](?<end_year>\d{4}) PT\. (?<part>\d+)$/.match(ec_string)

    #V. 85-89  /* 5 */
    #V. 85-89 1971-1975
    m ||= /^V. (?<start_volume>\d{2})-(?<end_volume>\d{2})( (?<start_year>\d{4})-(?<end_year>\d{4}))?$/.match(ec_string)

    #V. 118:PT. 1(2004) /* 28 */
    m ||=/^V. (?<volume>\d{1,3}):PT. (?<part>\d).(?<year>\d{4}).?$/.match(ec_string)

    #V. 110:PP. 1755-2870 (1996) /* 9 */
    m ||= /^V. (?<volume>\d+)[,:]PP\. (?<start_page>\d+)[\/-](?<end_page>\d+) \((?<year>\d{4})\)$/.match(ec_string)

    #V. 119:PT. 1,PP. 1/1143(2005)  /* 45 */
    #V. 119:PT. 1:PP. 1/1143(2005) PUBLIC LAWS
    #V. 116:PT. 4,PP. 2457/3357(2002)PRIVATE LAWS
    m ||= /^V. (?<volume>\d{1,3}):PT. (?<part>\d).PP. (?<start_page>\d{1,4})\/(?<end_page>\d{4}).(?<year>\d{4})/.match(ec_string) 

    # 2005 /* 7 */
    m ||= /^(?<year>\d{4})\.?$/.match(ec_string)
    # 1845-1867. /* 6 */
    m ||= /^(?<start_year>\d{4})-(?<end_year>\d{4})\.?$/.match(ec_string)

    if !m.nil?
      ec = Hash[ m.names.zip( m.captures ) ]
      if ec.key? 'end_year' and /^\d\d$/.match(ec['end_year'])
        ec['end_year'] = ec['start_year'][0,2]+ec['end_year']
      end

    end
    ec  #ec string parsed into hash
  end


  # take a parsed enumchron and expand it into its constituent parts
  # enum_chrons - { <canonical ec string> : {<parsed features>}, }
  #
  def self.explode ec
    enum_chrons = {} 
    if ec.nil? 
      return {}
    end

    if ec['volume'] and ec['part']
     enum_chrons["Volume:#{ec['volume']}, Part:#{ec['part']}"] = ec
    end
    enum_chrons
  end

  def self.parse_file
    @no_match = 0
    @match = 0
    input = File.dirname(__FILE__)+'/../data/statutes_enumchrons.txt'
    open(input, 'r').each do | line |
      line.chomp!

      ec = self.parse_ec(line)
      if ec.nil?
        @no_match += 1
        #puts line
      else 
        @match += 1
      end

    end

    puts "Statutes at Large match: #{@match}"
    puts "Statutes at Large no match: #{@no_match}"
    return @match, @no_match
  end

  def self.load_context 
  end
  self.load_context
end
