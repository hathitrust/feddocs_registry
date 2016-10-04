require 'pp'
require 'source_record'
=begin
=end

module ForeignRelations
  #include EC
  class << self; attr_accessor :years, :editions end
  @years = {}
  @editions = {}

  def self.sudoc_stem
    'S 1.1:'
  end

  def self.oclcs 
    #[10648533, 1768670]
  end
  
  def self.parse_ec ec_string
    #some junk in the back
    ec_string.gsub!(/ COPY$/, '')
    #some junk in the front
    ec_string.gsub!(/^KZ233 . U55 /, '')

    #fix the three digit years
    if ec_string =~ /^[89]\d\d[^0-9]*/
      ec_string = '1' + ec_string
    end
    #seriously 
    if ec_string =~ /^0\d\d[^0-9]*/
      ec_string = '2' + ec_string
    end

=begin
    ec_string.gsub!(/REEL \d+.* P77-/, '')
    ec_string.gsub!(/^A V\./, 'V.')
    ec_string.gsub!(/^: /, '')

    #space before trailing ) is always a typo
    ec_string.gsub!(/ \)/, ')')

    #trailing junk
    ec_string.gsub!(/[,: ]$/, '')  

    #remove unnecessary crap
    ec_string.gsub!(/ ?= ?[0-9]+.*/, '')

    #sometimes years get duplicated
    ec_string.gsub!(/(?<y>\d{4}) \k<y>/, '\k<y>')
=end

    #simple year
    #2008 /* 68 */
    #(2008)
    m ||= /^\(?(?<year>\d{4})\)?$/.match(ec_string)

    # V. 4 1939 /* 154 */
    m ||= /^V\. (?<volume>\d{1,3}) (?<year>\d{4})$/.match(ec_string)

    # V. 1969-76:9 /* 140 */
    # V. 1969-76/V. 1 
    m ||= /^V\. (?<start_year>\d{4})-(?<end_year>\d{2})[:\/](V\. )?(?<volume>\d{1,2})$/.match(ec_string)

    # V. 1950/V. 3 /* 149 */
    m ||= /^V\. (?<year>\d{4})\/V\. (?<volume>\d{1,2})$/.match(ec_string)

    # V. 3(1928) /* 370 */
    m ||= /^V\. (?<volume>\d{1,2})\((?<year>\d{4})\)$/.match(ec_string)

    # V. 2 1958-1960 /* 98 */
    m ||= /^V\. (?<volume>\d{1,2}) (?<start_year>\d{4})-(?<end_year>\d{2,4})$/.match(ec_string)

    # wut?
    # V. 1914  /* 41 */
    m ||= /^V\. (?<year>\d{4})$/.match(ec_string)

    # V. 1951/V. 7/PT. 2 /* 7 */
    m ||= /^V\. (?<year>\d{4})\/V\. (?<volume>\d{1,2})\/PT\. (?<part>\d{1,2})$/.match(ec_string)

    # V. 1952-54/V. 11/PT. 1 /* 31 */
    m ||= /^V\. (?<start_year>\d{4})-(?<end_year>\d{2,4})\/V\. (?<volume>\d{1,2})\/PT\. (?<part>\d{1,2})$/.match(ec_string)

    # 1934, V. 5 /* 743 */
    # 1934,V. 5
    # 1934: V. 5
    # 1934:V. 5
    # 1919/V. 2
    m ||= /^(?<year>\d{4})[,:\/]? ?V\. (?<volume>\d{1,2})$/.match(ec_string)

    # 1969-76:V. 14 /* 890 */
    m ||= /^(?<start_year>\d{4})-(?<end_year>\d{2,4})[,:\/]? ?V\. (?<volume>\d{1,2})$/.match(ec_string)
   
    # 952-954/V. 11:PT. 1 /* 25 */ 
    m ||= /^(?<start_year>\d{4})-(?<end_year>\d{2,4})\/V\. (?<volume>\d{1,2}):PT\. (?<part>\d{1,2})$/.match(ec_string)
    # 948/V. 1:PT. 1
    m ||= /^(?<year>\d{4})\/V\. (?<volume>\d{1,2}):PT\. (?<part>\d{1,2})$/.match(ec_string)

    # V. 7 PT. 1 1949
    # V. 6, PT. 2 1952-1954
    m ||= /^V\. (?<volume>\d{1,2}),? PT\. (?<part>\d{1,2}) (?<year>\d{4})$/.match(ec_string)
    m ||= /^V\. (?<volume>\d{1,2}),? PT\. (?<part>\d{1,2}) (?<start_year>\d{4})-(?<end_year>\d{2,4})$/.match(ec_string)

    # PARIS V. 10 1919 /* 13 */
    m ||= /^(?<paris>PARIS) V\. (?<volume>\d{1,2}) (?<year>\d{4})$/.match(ec_string)

    # 1969/76:V. 14 /* 214 */
    # 1969/1976:V. 14
    m ||= /^(?<start_year>\d{4})\/(?<end_year>\d{2,4}):V\. (?<volume>\d{1,2})$/.match(ec_string)

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
  # enum_chrons - { <canonical ec string> : {<parsed features>}, }
  #
  def self.explode ec
    enum_chrons = {} 
    if ec.nil?
      return {}
    end

    enum_chrons
  end

  def self.parse_file
    @no_match = 0
    @match = 0
    input = File.dirname(__FILE__)+'/../data/foreign_relations_enumchrons.txt'
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

    puts "Foreign Relations match: #{@match}"
    puts "Foreign Relations no match: #{@no_match}"
    return @match, @no_match
  end

  def self.load_context 
  end
  self.load_context
end
