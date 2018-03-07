require 'pp'

module Registry
  module Series
    module CongressionalRecord
      include Registry::Series
      class << self; attr_accessor :years, :editions end
      @years = {}
      @editions = {}

      def self.sudoc_stem
        'X 1.1:'
      end

      def self.oclcs
        [5_058_415, 5_302_677, 22_840_665, 300_300_400]
      end

      def parse_ec(ec_string)
        # our match
        m = nil

        # tokens
        v = 'V\.\s?\.?(?<volume>\d+)'
        p = '(PT\.?\s?)?\.?(?<part>\d+)'
        y = '((\s|\s?\()(?<year>\d{4})(\s|\)|:|\/|\z))'
        month = '(?<month>(JAN|FEB|MAR|APR|MAY|JUNE?|JULY?|AUG|SEPT?|OCT|NOV|DEC)\.?)'
        # digest = '(?<digest>DIGEST)'
        congress = '(?<congress>\d{1,3})'
        index = '([\/\s]IND(EX)?\.?[:\/,\.\s]\s?(?<index>[A-Z]-[A-Z]))'

        # double V for no apparent reason
        ec_string.sub!(/V\. V\./, 'V.')

        patterns = [
          # canonical
          %r{
            ^Volume:(?<volume>\d+)
            (,\sPart:(?<part>\d+))?
            (,\sIndex:(?<index>[A-Z]-[A-Z]))?
            (,\s(?<index>Index))?
            (,\s(?<appendix>Appendix))?$
          }x,

          # V. 1:PT. 4
          # V. 105 PT. 35
          # V. 155:PT. 26(2009)
          # V. 84. PT. 10 1939
          # V. 91:PT. 14:INDEX (1945)
          %r{
            ^#{v}[:,\.;\s]\s?#{p}([:\s](?<index>INDEX))?(#{y}
            (?<end_year>\d{2,4})?)?#{index}?$
          }x,

          # V. 78 PT. 12 1934 INDEX
          %r{
            ^#{v}[:,\s;]#{p}#{y}(?<index>INDEX)?$
          }x,

          # V. 152:PT. 16(2006:SEPT. 29)
          %r{
            ^#{v}[:,\s]#{p}#{y}#{month}\.?\s(?<day>\d{1,2})(\)|\z)?$
          }x,

          # V. 129:PT. 2 1983:FEB. 2-22
          %r{
            ^#{v}[:,\s]#{p}#{y}#{month}\.?\s(?<start_day>\d{1,2})
            -(?<end_day>\d{1,2})(\)|\z)?$
          }x,

          # 104/2-142/PT. 15
          # 64/1:53/PT. 1
          %r{
            ^#{congress}\/[12][:-](?<volume>\d+)\/#{p}#{y}?#{index}?$
          }x,

          # V. 99:PT. 2 1953:FEB. 26-APR. 8
          %r{
            ^#{v}:#{p}#{y}
            (?<start_month>#{month})\.?\s(?<start_day>\d{1,2})-
            (?<end_month>#{month})\.?\s(?<end_day>\d{1,2})
          }x,

          # V. 137:PT. 16 (1991:SEPT. 10/23) /* 307 */
          %r{
            ^#{v}:#{p}#{y}(?<start_month>#{month})\.?\s(?<start_day>\d{1,2})\/
            (?<end_month>#{month})?\.?\s?(?<end_day>\d{1,2})\)$
          }x,

          # 105/1/143/PT. 20
          # 76/3:86/PT. 19
          %r{
            ^#{congress}\/(?<session>\d)[\/:]
            (?<volume>\d{1,3})\/#{p}
            (\/(?<index>INDEX))?$
          }x,

          # 85TH/2ND 104/PT. 6
          %r{
            ^#{congress}(TH|ST|ND|RD)\/\d(TH|ST|ND|RD)?
             [ \s:\/]
            (?<volume>\d{1,3})\/#{p}$
          }x,

          # 102/2:V. 138:PT. 25 /* 7 */
          %r{
            ^#{congress}\/(?<session>\d):\s?#{v}[\/:]#{p}(\/(?<index>INDEX))?
              #{index}?$
          }x,

          # V. 43 INDEX 1908-09 /* 83 */
          %r{
            ^#{v}[\s|:](?<index>INDEX)((\s|\s?\()(?<start_year>\d{4})
                                       -(?<end_year>\d{2,4})\)?)?$
          }x,
          %r{
            ^#{v}[\s|:](?<index>INDEX)#{y}?$
          }x,

          # V. 5 1877 INDEX /* 40 */
          %r{
            ^#{v}#{y}(?<index>INDEX)$
          }x,

          # 108/PT. 17/INDEX A-K /* 1918 */
          %r{
            ^(?<volume>\d+)\/#{p}#{index}?$
          }x,
          # 126/PT. 26/INDEX
          # 127/PT. 25/INDEX/A-K
          %r{
            ^(?<volume>\d+)\/#{p}\/INDEX\/(?<index>[A-Z]-[A-Z])$
          }x,
          %r{^(?<volume>\d+)\/#{p}\/(?<index>INDEX)\/?$
          }x,
          # 137/PT. 25/L-Z/INDEX
          %r{
            ^(?<volume>\d+)\/#{p}\/(?<index>[A-Z]-[A-Z])\/INDEX$
          }x,

          # 91/PT. 13 AND APPENDIX
          # 92/PT. 10+APPENDIX
          %r{
            ^(?<volume>\d+)\/#{p}(\+|\sAND\s)(?<appendix>APPENDIX)$
          }x,

          # 98/1: V. 129/PT. 25/INDEX/A-L
          %r{
            #{v}[\s:\/,]\s?#{p}\/
            INDEX[\/ ](?<index>[A-Z]-[A-Z])$
          }x,

          # 102ND CONG. , 1ST SES. V. 137 PT. 25 INDEX L-Z #4#
          %r{
            ^#{congress}(TH|ST|ND|RD)\sCONG\.\s,\s
            (?<session>\d)(TH|ST|ND|RD)\sSESS?\.\s(;\s)?
            #{v}[\s:\/,]\s?#{p}
            #{y}?
            #{index}?$
          }x,

          # congressional junk... V. 137 PT. 25 INDEX L-Z
          %r{
            #{v}[\s:\/,]\s?#{p}
            #{y}?
            ([\s\/:,](#{index}|(?<index>INDEX)))?$
          }x,

          # 65/1: 55/ PT. 1 (1917, PP. 1-1070)
          %r{
            \d+\/\d:\s
            (?<volume>\d+)\/\s
            PT\.\s(?<part>\d+)\s
            \(\d{4}
          }x,

          # V. 107 1961 APPX. PT. 7
          %r{
            #{v}#{y}
            (?<appendix>APPX\.?)\s
            #{p}
           }x,

          # 61ST:1ST:V. 44:PT. 2 (1909:APR. 3/MAY 22)
          # 51ST:1ST:V. 21:PT. 7 (1890:JUNE 13/JULY 9)
          %r{
            ^#{congress}(TH|ST|ND|RD):
            (?<session>\d)(TH|ST|ND|RD):
            #{v}:#{p}#{y}
            (?<start_month>#{month})\s(?<start_day>\d{1,2})\/
            (?<end_month>#{month})\s(?<end_day>\d{1,2})\)?$
          }x,

          # Fine, I don't care about the dates
          # 61ST:1ST:V. 44:PT. 3 (1909:MAY/JUNE 16)
          # 59TH:1ST SESS. :V. 40:PT. 3 1906:FEB. 3/FEB. 26
          %r{
            ^#{congress}(TH|ST|ND|RD):
            (?<session>\d)(TH|ST|ND|RD)(\sSESS\.\s)?:
            #{v}[\s,:]\s?#{p}#{y}(?!.*INDEX)(?!.*APP).*
          }x,

          # V. 96 PT. 12 1950-1951
          /#{v}[\s:\/,]#{p}\s(?<start_year>\d{4})([-\/](?<end_year>\d{2,4}))?$/,

          # V. 88:PT. 10 APP. 1942:JULY 27-DEC. 16
          %r{
            ^#{v}[\s:\/,]#{p}\s
            (?<appendix>APP(ENDIX|\.))\s
            (?<year>\d{4})
          }x,

          # V. 96,PT. 18 1950-1951 APPENDIX
          %r{
            ^#{v}[\s:\/,]\s#{p}\s
            (?<year>\d{4})(-(?<end_year>\d{2,4}))?
            \s?(?<appendix>APP(ENDIX|\.))$
          }x,

          # 83/2ND 100/PT. 10
          %r{
            ^\d+\/\d(TH|ST|ND|RD)\s
            (?<volume>\d+)\/#{p}$
          }x,

          # some congressional junk ... V. 84. PT. 10 1939
          %r{
            [^0-9]#{v}[:,\.\s]\s?#{p}#{y}?#{index}?$
          }x,

          # 25/INDEX (assuming first is volume)
          %r{
            ^(?<volume>[0-9]{1,3})\/(?<index>INDEX)$
          }x,

          # it has a volume and a part and no index and no DAILY digest
          # ( a hail mary )
          %r{
            #{v}\s?[\s:\/,\.]\s?#{p}
            (?!.*INDEX).*
            (?!.*APP).*
            (?!.*DAILY).*
          }x,

          # V. 129,PT. 25 1983 INDEX L-Z
          # V. 129:PT. 25:INDEX:A-L
          %r{
            ^#{v}\s?[\s:\/,\.]\s?#{p}
            ([\s:\/,\.]\s?
            (?<year>\d{4})?)
            ([\s:\/,\.]\s?#{index})?
          }x
        ] # patterns

        patterns.each do |p|
          break unless m.nil?
          m ||= p.match(ec_string)
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

          if ec.key? 'end_year'
            ec['start_year'] ||= ec['year']
            ec['end_year'] = Series.calc_end_year(ec['start_year'], ec['end_year'])
          end
        end
        ec # ec string parsed into hash
      end

      # Take a parsed enumchron and expand it into its constituent parts
      # enum_chrons - { <canonical ec string> : {<parsed features>}, }
      #
      # Canonical string format: <volume number>, <part>, <index/abstract>
      def explode(ec, _src = nil)
        enum_chrons = {}
        return {} if ec.nil?

        if canon = canonicalize(ec)
          enum_chrons[canon] = ec.clone
        end
        enum_chrons
      end

      def canonicalize(ec)
        if !ec.nil? && ec['volume']
          ec['volume'].sub!(/^0+/, '')
          canon = "Volume:#{ec['volume']}"
          if ec['part']
            ec['part'].sub!(/^0+/, '')
            canon += ", Part:#{ec['part']}"
          end
          if ec['index']
            canon += if ec['index'] == 'INDEX'
                       ', Index'
                     else
                       ", Index:#{ec['index']}"
                     end
          end
          canon += ', Appendix' if ec['appendix']
        end
        canon
      end

      def self.load_context; end
      load_context
    end
  end
end
