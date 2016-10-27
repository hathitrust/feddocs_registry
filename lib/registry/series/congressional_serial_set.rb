require 'pp'
=begin
=end

module Registry
  module Series
    module CongressionalSerialSet
      #include EC
      class << self; attr_accessor :years, :editions end
      @years = {}
      @editions = {}

      def self.sudoc_stem
        'Y 1.1/2:'
      end

      def self.oclcs 
        #[10648533, 1768670]
      end
      
      def self.parse_ec ec_string
        # (1996:104TH)
        # year: congress
        yc = '(( | ?\()(YR\. )?(?<year>\d{4})(:(?<congress>[A-Z0-9]+))?( |\)|\z))'
        srn_ern = '(?<start_report_number>\d+)[-\/](?<end_report_number>\d+)'
        sdn_edn = '(?<start_document_number>\d+)[-\/](?<end_document_number>\d+)'
        dn = '(?<document_number>\d+)'
        rn = '(?<report_number>\d+)'
        sn = '(?<serial_number>\d{4,5}[A-Z]?)'

        ec_string.sub!(/^V\. (V\. )?/, '')
        ec_string.sub!(/^NO\. /, '')
        ec_string.sub!(/^SER(\.|IAL) /, '')
        ec_string.sub!(/^DOC /, '')
        ec_string.sub!(/ \d+(TH|ST|ND|RD) CONGRESS$/, '')

        #nothing important for our purposes comes after the year
        ec_string.sub!(/( \(\d{4}\)).*/, '\1')
        
        # 14097 YR. 1992
        m ||= /^#{sn}#{yc}?$/.match(ec_string)

        m ||= /^Serial Number:(?<serial_number>[0-9A-Z]+)(, Part:(?<part>[0-9A-Z]+))?/.match(ec_string)
        
        m ||= /^#{sn} \((?<start_year>\d{4})[\/-](?<end_year>\d{2,4})\)$/.match(ec_string)
        
        #7976 1921-1922
        m ||= /^#{sn} (?<start_year>\d{4})[-\/](?<end_year>\d{4})$/.match(ec_string)

        # 13105-2
        # 9777:1
        # 13105-2 (1996)
        m ||= /^#{sn}[-:](?<part>(\d{1,2}|[A-Z]))#{yc}?$/.match(ec_string)

        # 14423:NO. 111
        # 14541:NO. 3 (1999)
        # 14230:NO. 26-39 (1994)
        # 14179:NOS. 74/89 (1993)
        # 14148:NO. 1102(1992)
        # 14193:NOS. 1-37(1993)
        # we don't actually care about those "nos."
        m ||= /^#{sn}:NOS?\. \d+([-\/]\d+)?#{yc}?$/.match(ec_string)

        # 100-1098 (1993)
        m ||= /^(?<congress>1\d\d)-(?<something>\d{1,4})#{yc}?$/.match(ec_string)
        
        # 14255:HR. 426-450 (1994) 
        # 14251:HD 338-340 (1994)
        m ||= /^#{sn}:[H|S]\.? ?R\.? #{srn_ern}#{yc}?$/.match(ec_string)
        m ||= /^#{sn}:[H|S]\.? ?D\.? #{sdn_edn}#{yc}?$/.match(ec_string)

        # 14253:HR. 342 (1994)
        # 14433:H. D. 154
        m ||= /^#{sn}:[H|S]\.? ?D\.? #{dn}#{yc}?$/.match(ec_string)
        m ||= /^#{sn}:[H|S]\.? ?R\.? #{rn}#{yc}?$/.match(ec_string)
       
        # 14093:TREATY D. 29-41 (1992) 
        m ||= /^#{sn}:TREATY D\.? (?<start_treaty_number>\d+)[-\/](?<end_treaty_number>\d+)( \((?<year>\d{4})\))?$/.match(ec_string)
        m ||= /^#{sn}:TREATY D\.? (?<treaty_number>\d+)( \((?<year>\d{4})\))?$/.match(ec_string)

        # 14367:H. R. 470/494 (1996:104TH)
        # m ||= /^(?<serial_number>\d{4,5}):[H|S]\. R\. (?<start_report_number>\d+)[-\/](?<end_report_number>\d+) ?(\((?<year>\d{4})(:(?<congress>[A-Z0-9]+))?\))?$/.match(ec_string)


        # 13216:QUARTO
        m ||= /^#{sn}:(?<quarto>QUARTO)/.match(ec_string)

        # 14812A 2003
        # 14687A (2001)
        m ||= /^(?<serial_number>\d{4,5}[A-Z])([ :]\(?(?<year>\d{4})\)?)?$/.match(ec_string)

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
      # Canonical string format: Serial Number:<serial number>, Part:<part number> 
      def self.explode( ec, src=nil )
        enum_chrons = {} 
        if ec.nil?
          return {}
        end

        #serial number and part are sufficient to uniquely identify them.
        #we'll keep the other parsed tokens around, but they aren't necessary for 
        #deduping/identification
        if ec['serial_number'] and ec['part']
          canon = "Serial Number:#{ec['serial_number']}, Part:#{ec['part']}"
          enum_chrons[canon] = ec
        elsif ec['serial_number']
          enum_chrons["Serial Number:#{ec['serial_number']}"] = ec
        end
        enum_chrons
      end

      def self.parse_file
        @no_match = 0
        @match = 0
        input = File.dirname(__FILE__)+'/data/congressional_serial_set_enumchrons.txt'
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

        puts "Congressional Serial Set match: #{@match}"
        puts "Congressional Serial Set no match: #{@no_match}"
        return @match, @no_match
      end

      def self.load_context 
      end
      self.load_context
    end
  end
end
