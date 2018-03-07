require 'pp'

module Registry
  module Series
    # The Congressional Serial Set consists of 10s of thousands of
    # Congressional reports.
    module CongressionalSerialSet
      # include EC
      class << self; attr_accessor :years, :editions end
      @years = {}
      @editions = {}

      def self.sudoc_stem
        'Y 1.1/2:'
      end

      def self.oclcs
        [191_710_879,
         3_888_071,
         4_978_913]
      end

      def parse_ec(ec_string)
        m = nil

        # (1996:104TH)
        # year: congress
        yc = '((\s|\s?\()(YR\.\s)?(?<year>\d{4})' \
              '(:(?<congress>[A-Z0-9]+))?(\s|\)|\z))'
        srn_ern = '(?<start_report_number>\d+)[-\/](?<end_report_number>\d+)'
        sdn_edn = '(?<start_document_number>\d+)[-\/]' \
          '(?<end_document_number>\d+)'
        dn = '(?<document_number>\d+)'
        rn = '(?<report_number>\d+)'
        sn = '(?<serial_number>\d{4,5}[A-Z]?)'
        p = 'P(art|T\.?)?[:\s]?(?<part>\w{1,2})'

        ec_string.sub!(/^V\. (V\. )?/, '')
        ec_string.sub!(/^NO\. /, '')
        ec_string.sub!(/^SER(\.|IAL) /, '')
        ec_string.sub!(/^DOC /, '')
        ec_string.sub!(/ \d+(TH|ST|ND|RD) CONGRESS$/, '')

        # nothing important for our purposes comes after the year
        ec_string.sub!(/( \(\d{4}\)).*/, '\1')

        patterns = [
          # PT. 13 (1885)
          %r{
            ^#{p}#{yc}?$
          }x,

          # 14097 YR. 1992
          %r{
            ^#{sn}#{yc}?$
            }x,

          %r{
            ^Serial\sNumber:(?<serial_number>[0-9A-Z]+)
            (,\sPart:(?<part>[0-9A-Z]+))?
            }x,

          %r{
            ^#{sn}\s\((?<start_year>\d{4})[\/-](?<end_year>\d{2,4})\)$
            }x,

          # 7976 1921-1922
          %r{
            ^#{sn}\s(?<start_year>\d{4})[-\/](?<end_year>\d{4})$
            }x,

          # 13105-2
          # 9777:1
          # 13105-2 (1996)
          %r{
            ^#{sn}[-:](?<part>(\d{1,2}|[A-Z]))#{yc}?$
            }x,

          # 14423:NO. 111
          # 14541:NO. 3 (1999)
          # 14230:NO. 26-39 (1994)
          # 14179:NOS. 74/89 (1993)
          # 14148:NO. 1102(1992)
          # 14193:NOS. 1-37(1993)
          # we don't actually care about those "nos."
          %r{
            ^#{sn}:NOS?\.\s\d+([-\/]\d+)?#{yc}?$
            }x,

          # 100-1098 (1993)
          %r{
            ^(?<congress>1\d\d)-(?<something>\d{1,4})#{yc}?$
            }x,

          # 14255:HR. 426-450 (1994)
          # 14251:HD 338-340 (1994)
          %r{
            ^#{sn}:[H|S]\.?\s?R\.?\s#{srn_ern}#{yc}?$
            }x,
          %r{
            ^#{sn}:[H|S]\.?\s?D\.?\s#{sdn_edn}#{yc}?$
            }x,

          # 14253:HR. 342 (1994)
          # 14433:H. D. 154
          %r{
            ^#{sn}:[H|S]\.?\s?D\.?\s#{dn}#{yc}?$
            }x,
          %r{
            ^#{sn}:[H|S]\.?\s?R\.?\s#{rn}#{yc}?$
            }x,

          # 14093:TREATY D. 29-41 (1992)
          %r{
            ^#{sn}:TREATY\sD\.?\s(?<start_treaty_number>\d+)[-\/]
            (?<end_treaty_number>\d+)(\s\((?<year>\d{4})\))?$
            }x,
          %r{
            ^#{sn}:TREATY\sD\.?\s(?<treaty_number>\d+)(\s\((?<year>\d{4})\))?$
            }x,

          # 13216:QUARTO
          %r{
            ^#{sn}:(?<quarto>QUARTO)
            }x,

          # 14812A 2003
          # 14687A (2001)
          %r{
            ^(?<serial_number>\d{4,5}[A-Z])([\s:]\(?(?<year>\d{4})\)?)?$
            }x
        ]

        patterns.each do |pat|
          break unless m.nil?
          m ||= pat.match(ec_string)
        end

        unless m.nil?
          ec = Hash[m.names.zip(m.captures)]
          # remove nils
          ec.delete_if { |_k, v| v.nil? }
          if ec.key?('year') && (ec['year'].length == 3)
            ec['year'] = if (ec['year'][0] == '8') || (ec['year'][0] == '9')
                           '1' + ec['year']
                         else
                           '2' + ec['year']
                         end
          end

          if ec.key?('start_year') && (ec['start_year'].length == 3)
            if (ec['start_year'][0] == '8') || (ec['start_year'][0] == '9')
              ec['start_year'] = '1' + ec['start_year']
            else
              ec['start_year'] = '2' + ec['start_year']
            end
          end

          if ec.key?('end_year') && /^\d\d$/.match(ec['end_year'])
            ec['end_year'] = if ec['end_year'].to_i < ec['start_year'][2, 2].to_i
                               # crosses century. e.g. 1998-01
                               (ec['start_year'][0, 2].to_i + 1).to_s +
                                 ec['end_year']
                             else
                               ec['start_year'][0, 2] + ec['end_year']
                             end
          elsif ec.key?('end_year') && /^\d\d\d$/.match(ec['end_year'])
            ec['end_year'] = if ec['end_year'].to_i < 700
                               # add a 2; 1699 and 2699 are both wrong, but...
                               '2' + ec['end_year']
                             else
                               '1' + ec['end_year']
                             end
          end
        end
        ec # ec string parsed into hash
      end

      # Take a parsed enumchron and expand it into its constituent parts
      # perform a lookup using edition or year.
      # enum_chrons - { <canonical ec string> : {<parsed features>}, }
      #
      # Canonical string format: Serial Number:<serial number>, Part:<part num>
      def explode(ec, _src = nil)
        enum_chrons = {}
        return {} if ec.nil?

        # serial number and part are sufficient to uniquely identify them.
        # we'll keep the other parsed tokens around, but they aren't necessary
        # for deduping/identification
        if ec['serial_number'] && ec['part']
          canon = "Serial Number:#{ec['serial_number']}, Part:#{ec['part']}"
          enum_chrons[canon] = ec
        elsif ec['serial_number']
          enum_chrons["Serial Number:#{ec['serial_number']}"] = ec
        end
        enum_chrons
      end

      def canonicalize(ec); end

      def self.load_context; end
      load_context
    end
  end
end
