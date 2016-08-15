require 'pp'
require 'source_record'

module AgriculturalStatistics
  #include EC
  #attr_accessor :number_counts, :volume_year

  def self.oclcs 
    [1773189,  
     471365867,
     33822997,
     37238142
    ]
  end
  
  def self.parse_ec ec_string
    #fix the three digit years
    if ec_string =~ /^9\d\d[^0-9]*/
      ec_string = '1' + ec_string
    end
    #some junk in the front
    ec_string.gsub!(/^HD1751 . A43 /, '')
    ec_string.gsub!(/^V\. /, '')
    #these are insignificant
    ec_string.gsub!(/[()]/, '')

    #simple year
    #2008 /* 264 */
    m ||= /^(?<year>\d{4})$/.match(ec_string)

    #year range /* 70 */
    # 989-990
    # 1961-1963
    m ||= /^(?<start_year>\d{4})[-\/](?<end_year>\d{2,4})$/.match(ec_string)

    if !m.nil?
      ec = Hash[ m.names.zip( m.captures ) ]
      if ec.key? 'end_year' and /^\d\d$/.match(ec['end_year'])
        ec['end_year'] = ec['start_year'][0,2]+ec['end_year']
      elsif ec.key? 'end_year' and /^\d\d\d$/.match(ec['end_year'])
        ec['end_year'] = ec['start_year'][0,1]+ec['end_year']
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

    #if ec['volume'] and ec['part']
    #  key = "Volume:#{ec['volume']}, Part:#{ec['part']}"
    #  if ec['start_page']
    #    key << ", Pages:#{ec['start_page']}-#{ec['end_page']}"
    #  end
    #  enum_chrons[key] = ec
    #end

    enum_chrons
  end

  def self.parse_file
    @no_match = 0
    @match = 0
    input = File.dirname(__FILE__)+'/../data/agstats_enumchrons.txt'
    open(input, 'r').each do | line |
      line.chomp!

      ec = self.parse_ec(line)
      if ec.nil?
        @no_match += 1
        puts "no match: "+line
      else 
        #puts "match: "+self.explode(ec).to_s
        @match += 1
      end

    end

    puts "AgStats match: #{@match}"
    puts "AgStats no match: #{@no_match}"
    return @match, @no_match
  end

  def self.load_context 
  end
  self.load_context
end
