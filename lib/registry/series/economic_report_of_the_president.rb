require 'pp'
=begin
  Yearly, sometimes in multiple parts. We need to look at pub_date for monographs. 
=end

module Registry
  module Series
    module EconomicReportOfThePresident
      #include EC
      #class << self; attr_accessor :parts end
      #todo: make parts a constant?
      @@parts = Hash.new {|hash, key| hash[key] = Array.new() }
      
      def self.sudoc_stem
        'Y 4.EC 7:EC 7/2/'
      end

      def self.oclcs 
        [3160302, 8762269, 8762232]
      end
      
      def parse_ec ec_string
        #C. 1 crap from beginning and end
        ec_string.sub!(/ ?C\. 1 ?/, '')

        #occassionally a '-' at the end. not much we can do with that
        ec_string.sub!(/-$/, '')

        #own canonical format
        m ||= /^Year:(?<year>\d{4})(, Part:(?<part>\d{1}))?/.match(ec_string)

        #simple sudoc
        m ||= /^Y ?4\.? EC ?7:EC ?7\/2\/(?<year>\d{3,4})$/.match(ec_string)

        #stupid sudoc
        #Y 4. EC 7:EC 7/2/993/PT. 1-
        m ||= /^Y ?4\.? EC ?7:EC ?7\/2\/(?<year>\d{3,4}) ?\/PT. (?<part>\d{1})(\D|$)/.match(ec_string)

        # 1972/PT. 1
        m ||= /^(?<year>\d{3,4})\/PT. (?<part>\d{1})$/.match(ec_string)
        #1972/PT. 1-5
        m ||= /^(?<year>\d{3,4})\/PT. (?<start_part>\d{1})-(?<end_part>\d{1})$/.match(ec_string)
        
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
      def explode( ec, src={})
        ec ||= {}

        #some of these are monographs with the year info in pub_date or sudocs
        if ec['year'].nil? and ec['start_year'].nil?
          #try sudocs first
          if !src[:sudocs].nil? and !src[:sudocs].select { | s | s =~ /Y 4\.EC 7:EC 7\/2\/\d{3}/ }[0].nil?
            sudoc = src[:sudocs].select { | s | s =~ /Y 4\.EC 7:EC 7\/2\/\d{3}/ }[0]
            if !sudoc.nil?
              m = /EC 7\/2\/(?<year>\d{3,4})(\/.*)?$/.match(sudoc)
              if !m.nil? and m[:year][0] == '9'
                ec['year'] = '1'+m[:year]
              elsif !m.nil? 
                ec['year'] = m[:year]
              end
            end
          elsif !src[:pub_date].nil? and src[:pub_date].count == 1
            ec['year'] = src[:pub_date][0]
          end
        end

        enum_chrons = {} 
        if ec.keys.count == 0
          return {}
        end

        canon = ''
        if ec['year'] and !ec['part'].nil?
          canon = self.canonicalize(ec)
          enum_chrons[canon] = ec.clone
          @@parts[ec['year']] << ec['part']
          @@parts[ec['year']].uniq!
        elsif ec['year'] and ec['start_part']
          for pt in ec['start_part']..ec['end_part']
            canon = self.canonicalize({'year'=>ec['year'], 'part'=>pt})
            enum_chrons[canon] = ec.clone
            @@parts[ec['year']] << pt 
          end
          @@parts[ec['year']].uniq!
        elsif ec['year'] #but no parts. 
          # we can't assume all of them, horrible marc
          #if @parts[ec['year']].count > 0 
          #  for pt in @parts[ec['year']]
          #    canon = "Year: #{ec['year']}, Part: #{pt}"
          #    enum_chrons[canon] = ec
          #  end
          #else
          canon = self.canonicalize(ec)
          enum_chrons[canon] = ec.clone
          #end
        elsif ec['start_year']
          for y in ec['start_year']..ec['end_year']
            #if @parts[y].count > 0
            #  for pt in @parts[y]
            #    canon = "Year: #{y}, Part: #{pt}"
            #    enum_chrons[canon] = ec
            #  end
            #else
            canon = self.canonicalize({'year'=>y}) 
            enum_chrons[canon] = ec.clone
            #end
          end
        end

        enum_chrons
      end

      def canonicalize ec
        canon = []
        if ec['year']
          canon << "Year:#{ec['year']}"
        end
        if ec['part']
          canon << "Part:#{ec['part']}"
        end
        if canon.length > 0
          canon.join(", ")
        else
          nil
        end
      end

      def self.parse_file
        @no_match = 0
        @match = 0
        src = Class.new { extend EconomicReportOfThePresident } 
        input = File.dirname(__FILE__)+'/data/econreport_enumchrons.txt'

        open(input, 'r').each do | line |
          line.chomp!

          ec = src.parse_ec(line)


          if ec.nil? or ec.length == 0
            @no_match += 1
            #puts "no match: "+line
          else 
            #puts "match: "+self.explode(ec).to_s
            src.explode(ec, {})
            @match += 1
          end

        end
        #this creates our econreport parts file
        #parts_out = open(File.dirname(__FILE__)+'/data/econreport_parts.json', 'w')
        #parts_out.puts @parts.to_json
        #puts "Economic Reports match: #{@match}"
        #puts "Economic Reports no match: #{@no_match}"
        return @match, @no_match
      end

      def load_context 
        ps = open(File.dirname(__FILE__)+'/data/econreport_parts.json', 'r')
        #copy individually so we don't clobber the @parts definition 
        #i.e. no @parts = JSON.parse(ps.read)
        JSON.parse(ps.read).each do | key, parts |
          @@parts[key] = parts
        end
      end
    end
  end
end
