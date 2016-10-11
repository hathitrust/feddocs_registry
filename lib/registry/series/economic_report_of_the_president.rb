require 'pp'
=begin
  Yearly, sometimes in multiple parts. We need to look at pub_date for monographs. 
=end

module Registry
  module Series
    module EconomicReportOfThePresident
      #include EC
      class << self; attr_accessor :parts end
      @parts = Hash.new {|hash, key| hash[key] = Array.new() }
      
      def self.sudoc_stem
        'Y 4.EC 7:EC 7/2/'
      end

      def self.oclcs 
        [3160302, 8762269, 8762232]
      end
      
      def self.parse_ec ec_string

        #simple year
        #2008  /* 28 */
        #(2008)
        #2008.
        m ||= /^\(?(?<year>\d{4})\.?\)?$/.match(ec_string)
        
        # year with part  /* 33 */
        # 1973 PT. 1 
        m ||= /^(?<year>\d{4}) PT\. (?<part>\d{1})$/.match(ec_string)
        # year with parts
        # 1973 PT. 1-3
        m ||= /^(?<year>\d{4}) PT\. (?<start_part>\d{1})-(?<end_part>\d{1})$/.match(ec_string)

        # multiple years /* 2 */
        m ||= /^(?<start_year>\d{4})-(?<end_year>\d{4})$/.match(ec_string)

        # only part /* 11 */
        # PT. 1-5
        # PT. 2 
        m ||= /^PT\. (?<start_part>\d{1})-(?<end_part>\d{1})$/.match(ec_string)
        m ||= /^P(AR)?T\.? (?<part>\d{1})$/.match(ec_string)

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
      # Canonical string format: Year:<year>, Part:<part>
      def self.explode( ec, src)
        ec ||= {}

        #some of these are monographs with the year info in pub_date
        if !src[:pub_date].nil?
          if ec['year'].nil? and ec['start_year'].nil? and src[:pub_date].count == 1
            ec['year'] = src[:pub_date][0]
          end
        end

        enum_chrons = {} 
        if ec.keys.count == 0
          return {}
        end

        canon = ''
        if ec['year'] and !ec['part'].nil?
          canon = "Year: #{ec['year']}, Part: #{ec['part']}"
          enum_chrons[canon] = ec
          #puts "canon: #{canon}"
          @parts[ec['year']] << ec['part']
          @parts[ec['year']].uniq!
        elsif ec['year'] and ec['start_part']
          for pt in ec['start_part']..ec['end_part']
            canon = "Year: #{ec['year']}, Part: #{pt}"
            enum_chrons[canon] = ec
            @parts[ec['year']] << pt 
          end
          @parts[ec['year']].uniq!
        elsif ec['year'] #but no parts. 
          # we can't assume all of them, horrible marc
          #if @parts[ec['year']].count > 0 
          #  for pt in @parts[ec['year']]
          #    canon = "Year: #{ec['year']}, Part: #{pt}"
          #    enum_chrons[canon] = ec
          #  end
          #else
            canon = "Year: #{ec['year']}"
            enum_chrons[canon] = ec
          #end
        elsif ec['start_year']
          for y in ec['start_year']..ec['end_year']
            #if @parts[y].count > 0
            #  for pt in @parts[y]
            #    canon = "Year: #{y}, Part: #{pt}"
            #    enum_chrons[canon] = ec
            #  end
            #else
              canon = "Year: #{y}"
              enum_chrons[canon] = ec
            #end
          end
        end

        enum_chrons
      end

      def self.parse_file
        @no_match = 0
        @match = 0
        input = File.dirname(__FILE__)+'/data/econreport_enumchrons.txt'

        open(input, 'r').each do | line |
          line.chomp!

          ec = self.parse_ec(line)


          if ec.nil? or ec.length == 0
            @no_match += 1
            #puts "no match: "+line
          else 
            #puts "match: "+self.explode(ec).to_s
            self.explode(ec, {})
            @match += 1
          end

        end
        #this creates our econreport parts file
        #parts_out = open(File.dirname(__FILE__)+'/data/econreport_parts.json', 'w')
        #parts_out.puts @parts.to_json
        #puts "Economic Reports match: #{@match}"
        puts "Economic Reports no match: #{@no_match}"
        return @match, @no_match
      end

      def self.load_context 
        ps = open(File.dirname(__FILE__)+'/data/econreport_parts.json', 'r')
        #copy individually so we don't clobber the @parts definition 
        #i.e. no @parts = JSON.parse(ps.read)
        JSON.parse(ps.read).each do | key, parts |
          @parts[key] = parts
        end
      end
      self.load_context
    end
  end
end