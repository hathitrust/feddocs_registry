require 'pp'
=begin
=end

module Registry
  module Series
    module CongressionalRecord
      #include EC
      class << self; attr_accessor :years, :editions end
      @years = {}
      @editions = {}

      def self.sudoc_stem
        'X 1.1:'
      end

      def self.oclcs 
        [5058415, 5302677, 22840665, 300300400]
      end
      
      def self.parse_ec ec_string
        #tokens 
        v = 'V\. ?(?<volume>\d+)'
        p = '(PT\.? ?)?(?<part>\d+)'
        y = '(( | ?\()(?<year>\d{4})( |\)|:|\z))'
        month = '(?<month>(JAN|FEB|MAR|APR|MAY|JUNE?|JULY?|AUG|SEPT?|OCT|NOV|DEC))'
        digest = '(?<digest>DIGEST)'
        congress = '(?<congress>\d{1,3})'

        #canonical 
        m ||= /^Volume:(?<volume>\d+), Part:(?<part>\d+)(, #{digest})?$/.match(ec_string)

        #V. 1:PT. 4 
        #V. 105 PT. 35
        #V. 155:PT. 26(2009)
        m ||= /^#{v}[:, ]#{p}#{y}?$/.match(ec_string)

        # V. 152:PT. 16(2006:SEPT. 29)
        m ||= /^#{v}[:, ]#{p}#{y}#{month}\.? (?<day>\d{1,2})(\)|\z)?$/.match(ec_string)
        # V. 129:PT. 2 1983:FEB. 2-22
        m ||= /^#{v}[:, ]#{p}#{y}#{month}\.? (?<start_day>\d{1,2})-(?<end_day>\d{1,2})(\)|\z)?$/.match(ec_string)

        #104/2-142/PT. 15
        # 64/1:53/PT. 1
        m ||= /^#{congress}\/[12][:-](?<volume>\d+)\/#{p}#{y}?$/.match(ec_string)

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
      def self.explode( ec, src=nil )
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
        input = File.dirname(__FILE__)+'/data/congressional_record_enumchrons.txt'
        open(input, 'r').each do | line |
          line.chomp!

          ec = self.parse_ec(line)
          if ec.nil? or ec.length == 0
            @no_match += 1
            #puts "no match: "+line
          else 
            #puts "match: "+self.explode(ec).to_s
            @match += 1
          end

        end

        puts "Congressional Record match: #{@match}"
        puts "Congressional Record no match: #{@no_match}"
        return @match, @no_match
      end

      def self.load_context 
      end
      self.load_context
    end
  end
end
