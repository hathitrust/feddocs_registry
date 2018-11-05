module Registry
  module Series
    # Foreign Relations series
    module ForeignRelations
      include Registry::Series
      class << self; attr_accessor :years, :editions end
      @years = {}
      @editions = {}

      def self.sudoc_stem
        'S 1.1:'
      end

      def self.oclcs
        # [10648533, 1768670]
      end

      def parse_ec(ec_string)
        v = 'V\.?\s?(?<volume>\d{1,2})'
        p = 'PT\.?\s?(?<part>\d{1,2})'
        div = '[\s:,;\/-]\s?'

        m = nil

        # some junk in the back
        ec_string.gsub!(/ COPY$/, '')
        ec_string.gsub!(/ ?=.*/, '')
        ec_string.gsub!(/#{div}FICHE \d+(-\d+)?$/, '')
        ec_string.gsub!(/#{div}MF\.? SUP\.?$/, '')
        ec_string.chomp!

        # some junk in the front
        ec_string.gsub!(/^KZ233 . U55 /, '')
        ec_string.gsub!(/^V\. \/V/, 'V')

        # expand some stuff
        ec_string.gsub!(/SUP\.?([^P])?/, 'SUPPLEMENT\1')
        ec_string.gsub!(/CONF\.?([^E])?/, 'CONFERENCE\1')
        # just telling us supplement doesn't do us any good anyway
        ec_string.gsub!(/#{div}SUPPLEMENT$/, '')

        # fix the three digit years
        ec_string = '1' + ec_string if ec_string.match?(/^[89]\d\d[^0-9]*/)
        # seriously
        ec_string = '2' + ec_string if ec_string.match?(/^0\d\d[^0-9]*/)

        # fix some manglings
        ec_string.gsub!(/(\d{2,4})V/, '\1 V')
        ec_string.gsub!(/(\d)PT/, '\1 PT')

        patterns = [
          # canonical
          %r{
            ^Year:(?<year>\d{4})(,\sVolume:(?<volume>\d+))?
            (,\sPart:(?<part>\d+))?$
          }x,
          %r{
            ^Years:(?<start_year>\d{4})-(?<end_year>\d{4})
            (,\sVolume:(?<volume>\d+))?(,\sPart:(?<part>\d+))?$
          }x,

          # simple year
          # 2008 /* 68 */
          # (2008)
          %r{
            ^\(?(?<year>\d{4})\)?$
          }x,

          # V. 4 1939 /* 154 */
          %r{
            ^V\.\s(?<volume>\d{1,3})\s(?<year>\d{4})$
          }x,

          # V. 1969-76:9 /* 140 */
          # V. 1969-76/V. 1
          %r{
            ^V\.\s(?<start_year>\d{4})-(?<end_year>\d{2})#{div}
            (V\.\s)?(?<volume>\d{1,2})$
          }x,

          # 1906 PT. 1
          # 1906,PT. 1
          # 1906:PT. 1
          # 1906/PT. 1
          # V. 1906/PT. 2
          %r{
            ^(V\.\s)?(?<year>\d{4})#{div}#{p}$
          }x,
          # 1864-65 PT. 4
          %r{
            ^(V\.\s)?(?<start_year>\d{4})#{div}(?<end_year>\d{2,4})#{div}#{p}$
          }x,

          # V. 1950/V. 3 /* 149 */
          %r{
            ^V\.\s(?<year>\d{4})#{div}#{v}$
          }x,

          # V. 3(1928) /* 370 */
          %r{
            ^#{v}\((?<year>\d{4})\)$
          }x,

          # V. 2 1958-1960 /* 98 */
          %r{
            ^#{v}\s(?<start_year>\d{4})-(?<end_year>\d{2,4})$
          }x,

          # wut?
          # V. 1914  /* 41 */
          %r{
            ^V\.\s(?<year>\d{4})$
          }x,

          # V. 1951/V. 7/PT. 2 /* 7 */
          %r{
            ^V\.\s(?<year>\d{4})#{div}#{v}#{div}#{p}$
          }x,

          # V. 1952-54/V. 11/PT. 1 /* 31 */
          %r{
            ^V\.\s(?<start_year>\d{4})-(?<end_year>\d{2,4})#{div}#{v}#{div}#{p}$
          }x,

          # V. -54/V. 5/PT. 1
          # V. 54/V. 5/PT. 1
          %r{
            ^V\.\s-?(?<year>\d{2})\/#{v}(\/#{p})?$
          }x,

          # 1934, V. 5 /* 743 */
          # 1934,V. 5
          # 1934: V. 5
          # 1934:V. 5
          # 1919/V. 2
          %r{
            ^(?<year>\d{4})#{div}#{v}$
          }x,

          # 1969-76:V. 14 /* 890 */
          %r{
            ^(?<start_year>\d{4})-(?<end_year>\d{2,4})#{div}#{v}$
          }x,

          # 952-954/V. 11:PT. 1 /* 25 */
          %r{
            ^(?<start_year>\d{4})-(?<end_year>\d{2,4})#{div}#{v}#{div}#{p}$
          }x,
          # 948/V. 1:PT. 1
          # 1951 V. 3 PT. 1
          %r{
            ^(?<year>\d{4})#{div}#{v}#{div}#{p}$
          }x,

          # V. 1/PT. 1
          # V. 9 PT. 1
          %r{
            ^#{v}#{div}#{p}$
          }x,

          # V. 7 PT. 1 1949
          # V. 6, PT. 2 1952-1954
          %r{
            ^#{v}#{div}#{p}\s(?<year>\d{4})$
          }x,
          %r{
            ^#{v}#{div}#{p}\s(?<start_year>\d{4})-(?<end_year>\d{2,4})$
          }x,

          #  V. 1872/PT. 2/V. 1
          %r{
            ^(V\.\s)?(?<year>\d{4})#{div}#{p}#{div}#{v}$
          }x,

          # PARIS V. 10 1919 /* 13 */
          %r{
            ^(?<paris>PARIS)\sV\.\s(?<volume>\d{1,2})\s(?<year>\d{4})$
          }x,

          # 1969/76:V. 14 /* 214 */
          # 1969/1976:V. 14
          # 1952-54:V. 9/PT. 2
          # 1952/54:V. 9 PT. 2
          %r{
            ^(?<start_year>\d{4})[-\/](?<end_year>\d{2,4})#{div}#{v}
            (#{div}#{p})?$
          }x,

          # 23
          # 23/PT. 1
          %r{
            ^(?<volume>\d{1,2})(#{div}#{p})?$
          }x,

          # 1951 V. 6:2
          %r{
            ^(?<year>\d{4})#{div}#{v}#{div}(?<part>\d)$
          }x,

          # 1964-1968 V. 31 2004
          # pretty sure that last 4 digits is something else
          %r{
            ^(?<start_year>\d{4})(#{div}(?<end_year>\d{2,4}))?#{div}#{v}#{div}
            (?<junk>\d{4})$
          }x,

          # 1952/54:V. 5:PT. 2:FICHE 1-5
          # 1952/54:V. 5:PT. 2:FICHE 6-9
          # 1952-54 V. 6:1
          %r{
            ^(?<start_year>\d{4})#{div}(?<end_year>\d{2,4})#{div}#{v}#{div}
            (PT\.\s)?(?<part>\d)(:FICHE\s\d(-\d)?)?$
          }x,

          # 1958-1960
          # 1969/76 (V. 34)
          %r{
            ^(?<start_year>\d{4})#{div}(?<end_year>\d{2,4})(\s\(#{v}\))?$
          }x,

          %r{
            ^#{v}$
          }x,

          # 1944:4
          # 1944:5
          %r{
            ^(?<year>\d{4}):(?<part>\d)$
          }x
        ]

        patterns.each do |pat|
          break unless m.nil?

          m ||= pat.match(ec_string)
        end

        unless m.nil?
          ec = Hash[m.names.zip(m.captures)]
          # remove nils
          ec.delete_if { |_k, val| val.nil? }
          if ec.key?('year') && (ec['year'].length == 2)
            ec['year'] = '19' + ec['year']
          elsif ec.key?('year') && (ec['year'].length == 3)
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
            ec['end_year'] = Series.calc_end_year(ec['start_year'],
                                                  ec['end_year'])
          end
        end
        ec # ec string parsed into hash
      end

      # Take a parsed enumchron and expand it into its constituent parts
      # enum_chrons - { <canonical ec string> : {<parsed features>}, }
      #
      def explode(ec, _src = nil)
        enum_chrons = {}
        return {} if ec.nil?

        if (canon = canonicalize(ec))
          ec['canon'] = canon
          enum_chrons[ec['canon']] = ec.clone
        end

        enum_chrons
      end

      def canonicalize(ec)
        if ec['year'] || ec['start_year'] || ec['volume']
          parts = []
          if ec['start_year']
            parts << "Year:#{ec['start_year']}-#{ec['end_year']}"
          end
          parts << "Year:#{ec['year']}" if ec['year']
          parts << "Volume:#{ec['volume']}" if ec['volume']
          parts << "Part:#{ec['part']}" if ec['part']
          canon = parts.join(', ')
        end
        canon
      end

      def self.load_context; end
      load_context
    end
  end
end
