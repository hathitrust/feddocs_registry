require 'pp'
require 'source_record'

module FederalRegister
  #include EC
  #attr_accessor :number_counts, :volume_year
  class << self; attr_accessor :nums_per_vol, :year_to_vol end
  @nums_per_vol = {}
  @year_to_vol = {}

  #def initialize match_data
  #  match_data.names.each {|n| instance_variable_set("@#{n}", match_data[n])}
  #  #EC.convert_to_isodate self
  #end

  def self.oclcs 
    [1768512,
    3803349,
    9090879,
    6141934,
    27183168,
    9524639,
    60637209,
    25816139,
    27163912,
    7979808,
    4828080,
    18519766,
    41954100,
    43080713,
    38469925,
    97118565,
    70285150]
  end
  
  def self.parse_ec ec_string
    # V. 48:NO. 4 (1983:JAN. 6) /* 4,791 */
    # V. 78:NO. 193(2013:OCT. 4)
    # V. 72:NO. 235 ( 2007: DEC. 7) /* 6 more for optional spaces */
    # V. 68:NO. 225 2003:NOV. 21 /* 4 more for optional () */
    # V. 61:NO. 93 (1996:MAY13) /* 62 */
    m ||= /^V\.? ?(?<volume>\d+)(:| )NO\.? (?<number>\d+) ?\(? ?(?<year>\d{4}): ?(?<month>\p{Alpha}{3,})\.? ?(?<day>\d{1,2})\)?$/.match(ec_string)

    # V. 75:NO. 149(2010) /* 659 */
    m ||= /^V\. ?(?<volume>\d+):NO\. (?<number>\d+)\((?<year>\d{4})\)$/.match(ec_string)

    # V. 78 NO. 152 AUG 7, 2013 /* 242 */
    # V. 67:NO. 50 (MAY 14,2002) /* 3 */
    #m ||= /^V\. \d+:NO\. \d+ ?\(\p{Alpha}{3,}\.? \d{1,2}(,| )\d{4}\)$/.match(ec_string)
    m ||= /^V\.? ?(?<volume>\d+)(:| )NO\.? ?(?<number>\d+) ?\(?(?<month>\p{Alpha}{3,})\.? (?<day>\d{1,2})( |, |,)(?<year>\d{4})\)?$/.match(ec_string)

    # V. 1 (1936:MAY 28/JUNE 11)  /* 849 */
    # V. 1 (1936:SEPT. 15/25)
    m ||= /^V\.? ?(?<volume>\d+) ?\((?<year>\d{4}):(?<month_start>\p{Alpha}{3,4})\.? (?<day_start>\d{1,2})\/((?<month_end>\p{Alpha}{3,4})\.? )?(?<day_end>\d{1,2})\)$/.match(ec_string) 

    # crap /* 152 */
    ##m ||= /^V\. (?<volume>04\d) PT.*\d[A-Z]$/.match(ec_string)

    # 74,121 /* 196 */
    m ||= /^(?<volume>\d+),(?<number>\d+)$/.match(ec_string)

    # 1964 /* 44 */
    m ||= /^(?<year>\d{4})$/.match(ec_string)

    # V. 13 /* 36 */
    m ||= /^V\. (?<volume>\d+)$/.match(ec_string)

    # V. 72:PT. 61 /* 234 */
    # V. 70:PT186 /* 1 */
    m ||= /^V\. ?(?<volume>\d+):PT\.? ?(?<number>\d+)$/.match(ec_string)

    # V. 39-42 (1974-77) /* 9 */
    m ||= /^V\. (?<volume_start>\d+)-(?<volume_end>\d+) ?\((?<year_start>\d{4})-(?<year_end>\d{2,4})\)$/.match(ec_string)

    # V. 62:NO. 181 /* 4 */
    m ||= /^V\. (?<volume>\d+):NO\. (?<number>\d+)$/.match(ec_string)

    # V. 78:NO. 38-75(2013) /* 5 */
    m ||= /^V\. (?<volume>\d+): ?NO\. (?<number_start>\d+)-(?<number_end>\d+)(\((?<year>\d{4})\))?$/.match(ec_string)

    
    # V. 78:NO. 160-161(2013:AUG. 19-20) /* 18 */
    m ||= /^V\. (?<volume>\d+): ?NO\. (?<number_start>\d+)-(?<number_end>\d+)\((?<year>\d{4}):(?<month>\p{Alpha}{3,})\.? (?<day_start>\d+)-(?<day_end>\d+)\)$/.match(ec_string)

    # V. 4 (1939:DEC. 30) /* 37 */
    m ||= /^V\. (?<volume>\d+) \((?<year>\d{4}):(?<month>\p{Alpha}{3,})\.? (?<day>\d{1,2})\)$/.match(ec_string)


    # V. 9 (1944:JULY 22:P. 8284-8381) /* only 8 */
    m ||= /^V\. (?<volume>\d+) \((?<year>\d{4}):(?<month>\p{Alpha}{3,})\.? (?<day>\d{1,2}):P\. (?<page_start>\d+)-(?<page_end>\d+)\)$/.match(ec_string)

    # V. 47 (1982:JAN. 4-5) /* 33 */
    m ||= /^V\. (?<volume>\d+) \((?<year>\d{4}):(?<month>\p{Alpha}{3,})\.? (?<day_start>\d{1,2})-(?<day_end>\d{1,2})\)$/.match(ec_string)



    # V. 78:NO. 164-173(2013:AUG. 23-SEPT. 6) /* 10 */
    # V. 78:NO. 147-158(2013:JULY31-AUG. 15) /* 3 more by making the spaces optional */
    m ||= /^V\. (?<volume>\d+):NO\. (?<number_start>\d+)-(?<number_end>\d+)\((?<year>\d{4}):(?<month_start>\p{Alpha}{3,})\.? ?(?<day_start>\d{1,2})-(?<month_end>\p{Alpha}{3,})\.? ?(?<day_end>\d{1,2})\)$/.match(ec_string)

    # V. 15:P. 2701-4070 1950  /* wu */  /* 842 */
    # V. 8:P. 5659-7206 (1943) /* MNU */
    m ||= /^V\. (?<volume>\d+):P\. (?<page_start>\d+)-(?<page_end>\d+) \(?(?<year>\d{4})\)?$/.match(ec_string)

    # V. 9 JUL 1944  /* 354 */
    # V. 5 OCT-DEC 1940
    m ||= /^V\. (?<volume>\d+) (?<month>\p{Alpha}{3})(-(?<month_end>\p{Alpha}{3}))? (?<year>\d{4})$/.match(ec_string)

    # V. 40 MAY1-9 1975 /* 348 */
    m ||= /^V\. (?<volume>\d+) (?<month>\p{Alpha}{3})(?<day_start>\d{1,2})-(?<day_end>\d{1,2}) (?<year>\d{4})$/.match(ec_string)

    # V. 47 OCT28 1982 PP. 47799-49004  /* 114 */
    # V. 47 DEC10-16 1982 PP. 55455-56468
    m ||= /^V\. (?<volume>\d+) (?<month>\p{Alpha}{3})(?<day>\d{1,2})(-(?<day_end>\d{1,2}))? (?<year>\d{4}) PP\. (?<page_start>\d+)-(?<page_end>\d+)$/.match(ec_string) 

    # V. 3 JAN1-JUN3 1938 /* 7 */
    m ||= /^V\. (?<volume>\d+) (?<month_start>\p{Alpha}{3})(?<day_start>\d{1,2})-(?<month_end>\p{Alpha}{3})(?<day_end>\d{1,2}) (?<year>\d{4})$/.match(ec_string)

    # V. 47 JUN29-JUL1 1982 PP. 28067-28894 /* 12 */
    m ||= /^V\. (?<volume>\d+) (?<month_start>\p{Alpha}{3})(?<day_start>\d{1,2})-(?<month_end>\p{Alpha}{3})(?<day_end>\d{1,2}) (?<year>\d{4}) PP\. (?<page_start>\d+)-(?<page_end>\d+)$/.match(ec_string)

    if !m.nil?
      ec = Hash[ m.names.zip( m.captures ) ]
      if m.names.include?("year") and !m.names.include?("volume")
        ec["volume"] = FederalRegister.year_to_vol[ec["year"]]
      end
    end
    ec  #ec string parsed into hash
  end


  #take a parsed enumchron and expand it into its constituent parts
  # enum_chrons - { <canonical ec string> : {<parsed features>}, }
  def self.explode ec
    enum_chrons = {} 
    if ec.nil? 
      return {}
    end

    if ec["number"] and ec["volume"]
      enum_chrons["Volume:#{ec["volume"]}, Number:#{ec["number"]}"] = ec 
    elsif (ec["number_start"] and ec["volume"]) or
       (ec.keys.count == 1 and ec["volume"]) or
       (ec.keys.count == 2 and ec["volume"] and ec["year"])
      #a starting number and potentially ending number
      ec["number_start"] ||= "1"
      ec["number_end"] ||= FederalRegister.nums_per_vol[ec["volume"]]
      for n in (ec["number_start"]..ec["number_end"]) do 
        enum_chrons["Volume:#{ec["volume"]}, Number:#{n}"] = ec 
      end
    end

    return enum_chrons 
  end

  def self.parse_file
    @no_match = 0
    @match = 0
    input = File.dirname(__FILE__)+'/../data/fr_enumchrons.txt'
    open(input, 'r').each do | line |
      line.chomp!

      ec = FederalRegister.parse_ec(line)
      if ec.nil?
        @no_match += 1
      else 
        @match += 1
      end

    end

    puts "match: #{@match}"
    puts "no match: #{@no_match}"
    return @match, @no_match
  end

  def self.load_context 
    ncs = File.dirname(__FILE__)+'/../data/fr_number_counts.tsv'
    open(ncs).each do | line | 
      year, volume, numbers = line.chomp.split(/\t/)
      self.year_to_vol[year] = volume
      self.nums_per_vol[volume] = numbers
    end
  end
  self.load_context
end
