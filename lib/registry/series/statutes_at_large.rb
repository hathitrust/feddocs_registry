require 'pp'

module Registry
  module Series
    # Statutes At Large series
    module StatutesAtLarge
      # include EC
      # attr_accessor :number_counts, :volume_year

      def self.oclcs
        [1_768_474,
         4_686_465,
         3_176_465,
         3_176_512,
         426_275_236,
         15_347_313,
         15_280_229,
         17_554_670,
         12_739_515,
         17_273_536]
      end

      def parse_ec(ec_string)
        m = nil

        # sometimes has junk in the front
        ec_string.gsub!(/^KF50 \. U5 /, '')
        ec_string.gsub!(/^[A-Z] V\./, 'V.')
        ec_string.sub!(/ ?C\. \d+ ?/, '')

        patterns = [
          # 'V. 96:PT. 1 (1984)' /* 517 */
          # V. 114:PART 1 (2000)
          %r{
            ^V\.\s(?<volume>\d+)[\s,:]P(AR)?T\.?\s(?<part>\d{1})\s?\(?
            (?<year>\d{4})\)?$
          }x,

          # canonical
          %r{
            ^Volume:(?<volume>\d+),\sPart:(?<part>\d{1,2})$
          }x,
          %r{
            ^Volume:(?<volume>\d+),\sPart:(?<part>\d{1,2}),\s
            Pages:(?<start_page>\d{1,4})-(?<end_page>\d{1,4})$
          }x,

          #  V. 112:PP. 2787-3823 (1998) PT. 5
          %r{
            ^V\.\s(?<volume>\d+)[\/:,]PP\.\s(?<start_page>\d{1,4})-
            (?<end_page>\d{4})\s\((?<year>\d{4})\)\sP(AR)?T\.?\s
            (?<part>\d{1,2})$
          }x,

          # V. 61PT. 4 1947 /* 133 */
          %r{
            ^V\.\s(?<volume>\d+)PT\.\s(?<part>\d{1,2})\s(?<year>\d{4})$
          }x,

          # V. 32 PT. 1 1901/02-1902/03
          %r{
            ^V\.\s(?<volume>\d+)[\/:,\s]P(AR)?T\.?\s(?<part>\d{1,2})\s
            (?<start_year>\d{4})\/\d\d-(?<end_year>\d{4})\/\d\d$
          }x,

          # 'V. 99:PT. 1' /* 231 */
          # V. 57/PT. 1
          # V. 61,PT. 2
          %r{
            ^V\.\s(?<volume>\d+)[\/:,]P(AR)?T\.?\s(?<part>\d{1,2})$
          }x,

          # V. 64/PT. 3 (1950-1951)
          %r{
            ^V\.\s(?<volume>\d+)[\/:,]P(AR)?T\.?\s(?<part>\d{1,2})\s?\(?
            (?<start_year>\d{4})-(?<end_year>\d{4})\)?$
          }x,

          # KF50 . U5 V. 94 PT. 2  /* 72 */
          # KF50 . U5 V. 78
          # %r{^KF50\s.\sU5\sV\.\s(?<volume>\d+)(\sPT\.\s(?<part>\d{1,2}))?$}x,

          #  'V. 96:2 1982' /* 135 */
          %r{
            ^V\.\s(?<volume>\d+):(?<part>\d{1,2})\s(?<year>\d{4})$
          }x,

          # V. 124:PT. 1:1/1128(2010) /* 5 */
          %r{
            ^V\.\s(?<volume>\d+):PT\.\s(?<part>\d{1}):(?<start_page>\d{1,4})\/
            (?<end_page>\d{4})\((?<year>\d{4})\)$
          }x,

          # V. 45:PT. 2:BOOK 2 (1929)
          %r{
            ^V\.\s(?<volume>\d+):PT\.\s(?<part>\d{1}):BOOK\s\d\s\(
            (?<year>\d{4})\)$
          }x,

          # V. 124, PT. 2 /* 4 */
          %r{
            ^V\.\s(?<volume>\d+),\sPT\.\s(?<part>\d{1})$
          }x,

          # 'V. V. 12 1859-1863' /* 30 */
          # V. V. 23 1883-85
          %r{
            ^V\.\sV\.\s(?<volume>\d{1,2})\s(?<start_year>\d{4})-
            (?<end_year>\d{2,4})$
          }x,

          # V. V. 32:1 1901-03 /* 7 */
          %r{
            ^V\.\sV\.\s(?<volume>\d{1,2}):(?<part>\d)\s(?<start_year>\d{4})-
            (?<end_year>\d{2,4})$
          }x,

          # V. V. 2 1848 /* 1 */
          %r{
            ^V\.\sV\.\s(?<volume>\d{1,2})\s(?<year>\d{4})$
          }x,

          # 'V. V. 36 PT1 1909-12  /* 21 */
          # V. V. 36 PT2 1909-1911
          # V. V. 37 PT. 1 1911-12
          %r{
            ^V\.\sV\.\s(?<volume>\d{1,2})\sPT(\.\s)?(?<part>\d{1,2})\s
            (?<start_year>\d{4})-(?<end_year>\d{2,4})$
          }x,

          # 102: PT. 3 /* 375 */
          # 102/PT. 3
          # 104/ PT. 5
          # 103: PT. 1989 <- bad
          # 108:PT. 1
          # 113 PT. 2
          %r{
            ^(?<volume>\d{2,3})(:|\s|:\s|\/)\s?PT\.\s(?<part>\d)$
          }x,

          # V. 100 PT. 5 /* 370 */
          # V. 100;PT. 5
          # V. 101 1987 PT. 1
          # V. 101:1987:PT. 1
          %r{
            ^V\.\s(?<volume>\d+)[\s:;\/](?<year>\d{4})?[\s:;]?
             PT\.\s(?<part>\d{1,2})$
          }x,

          # V. 33:2 1903-1905
          %r{
            ^V\.\s?(?<volume>\d+)[:;\/](?<part>\d)\s(?<start_year>\d{4})-
            (?<end_year>\d{2,4})$
          }x,

          # V. 93  /* 164 */
          # V. 93 1979
          # V. 93 (1979)
          # V. 77A
          # V. 77A 1963
          # V. 77A (1963)
          %r{
            ^V\.\s(?<volume>\d+A?)(\s\(?(?<year>\d{4})\)?)?$
          }x,

          # V. 112:PT. 1,PP. 1/912 (1998) /* 8 */
          %r{
            ^V\.\s(?<volume>\d+):P(ART|T\.)\s(?<part>\d{1})[,:]PP\.\s
            (?<start_page>\d+)[\/-](?<end_page>\d+)\s\((?<year>\d{4})\)$
          }x,

          # V. 44 PT. 1 BK. 1
          # V. 33:PT. 1:BK. 1 (1903-1905)
          %r{
            ^V\.\s(?<volume>\d+)\sPT\.\s(?<part>\d{1})\sBK\.\s\d{1}(\s\(
            (?<start_year>\d{4})-(?<end_year>\d{4})\))?
          }x,

          # V. 84:PT. 1 (1970/71) /* 279 */
          # V. 84 PT. 2 1970/71
          # V. 84:PT. 2 (1970-71)

          # V. 10 1851-1855
          # V. 10 1851/1855
          # V. 10 (1851/55)
          %r{
            ^V\.\s(?<volume>\d+)([\s:]PT\.\s(?<part>\d))?\s\(?
            (?<start_year>\d{4})[-\/](?<end_year>\d{2,4})\)?$
          }x,

          # V. 44 1925-1926 PT. 1 /* 44 */
          %r{
            ^V\.\s(?<volume>\d+)\s(?<start_year>\d{4})[\/-]
            (?<end_year>\d{4})\sPT\.\s(?<part>\d+)$
          }x,

          # V. 85-89  /* 5 */
          # V. 85-89 1971-1975
          %r{
            ^V.\s(?<start_volume>\d{2})-(?<end_volume>\d{2})(\s
            (?<start_year>\d{4})-(?<end_year>\d{4}))?$
          }x,

          # V. 118:PT. 1(2004) /* 28 */
          # V. 119/PT. 1 (2005)
          %r{
            ^V.\s(?<volume>\d{1,3})[:\/,]PT.\s(?<part>\d)\s?\((?<year>\d{4})\)?$
          }x,

          # V. 110:PP. 1755-2870 (1996) /* 9 */
          %r{
            ^V.\s(?<volume>\d+)[,:]PP\.\s(?<start_page>\d+)[\/-](?<end_page>\d+)
            \s\((?<year>\d{4})\)$
          }x,

          # V. 119:PT. 1,PP. 1/1143(2005)  /* 45 */
          # V. 119:PT. 1:PP. 1/1143(2005) PUBLIC LAWS
          # V. 116:PT. 4,PP. 2457/3357(2002)PRIVATE LAWS
          %r{
            ^V.\s(?<volume>\d{1,3}):PT.\s(?<part>\d).PP.\s(?<start_page>\d{1,4})
            \/(?<end_page>\d{4}).(?<year>\d{4})
          }x,

          # V. 34:PT. 3(1905:DEC. -1907:MAR. )
          # V. 118/PT. 1 (108TH. CONG. -2ND SESS. )
          # V. 116/PT. 3 (107TH. CONG. -2ND SESS. )
          #  V. 119/PT. 3 (109TH. CONG. -1ST SESS.
          %r{
            ^(V\.\s)?(?<volume>\d+)[\s\/:]PT\.\s(?<part>\d{1})\s?
            \(.*[A-Z]{3}\..*\)?$
          }x,

          # 2005 /* 7 */
          %r{
            ^(?<year>\d{4})\.?$
          }x,
          # 1845-1867. /* 6 */
          %r{
            ^(?<start_year>\d{4})-(?<end_year>\d{4})\.?$
          }x
        ]

        patterns.each do |p|
          break unless m.nil?
          m ||= p.match(ec_string)
        end

        unless m.nil?
          ec = Hash[m.names.zip(m.captures)]
          if ec.key?('end_year') && /^\d\d$/.match(ec['end_year'])
            ec['end_year'] = ec['start_year'][0, 2] + ec['end_year']
          end

        end
        ec # ec string parsed into hash
      end

      # take a parsed enumchron and expand it into its constituent parts
      # enum_chrons - { <canonical ec string> : {<parsed features>}, }
      #
      def explode(ec, _src = nil)
        enum_chrons = {}
        return {} if ec.nil?

        if (canon = canonicalize(ec))
          enum_chrons[canon] = ec
        end

        enum_chrons
      end

      def canonicalize(ec)
        if ec['volume'] && ec['part']
          canon = "Volume:#{ec['volume']}, Part:#{ec['part']}"
          if ec['start_page']
            canon << ", Pages:#{ec['start_page']}-#{ec['end_page']}"
          end
        end
        canon
      end

      def self.load_context; end
      load_context
    end
  end
end
