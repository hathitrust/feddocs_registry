require 'pp'
require 'registry/series/default_series_handler'

module Registry
  module Series
    class FederalRegister < DefaultSeriesHandler
      @nums_per_vol = {}
      @year_to_vol = {}

      def initialize
        super
        @title = 'Federal Register'
        @patterns = [
          # canonical
          %r{
            ^Volume:(?<volume>\d+),\sNumber:(?<number>\d+)$
            }x,

          # V. 48:NO. 4 (1983:JAN. 6) /* 4,791 */
          # V. 78:NO. 193(2013:OCT. 4)
          # V. 72:NO. 235 ( 2007: DEC. 7) /* 6 more for optional spaces */
          # V. 68:NO. 225 2003:NOV. 21 /* 4 more for optional () */
          # V. 61:NO. 93 (1996:MAY13) /* 62 */
          # V. 65:NO. 220(2000:NOV. 14):BK. 1
          %r{
            ^V\.?\s?(?<volume>\d+)(:|\s)NO\.?\s(?<number>\d+)\s?\(?\s?
            (?<year>\d{4}):\s?(?<month>\p{Alpha}{3,})\.?\s?
            (?<day>\d{1,2})\)?(:BK.*)?$
            }x,

          # V. 75:NO. 226(2010) PART A
          # V. 75:NO. 226(2010) PART B
          # don't care about the parts
          %r{
            ^V\.?\s?(?<volume>\d+)(:|\s)NO\.?\s(?<number>\d+)\(
            (?<year>\d{4})\)(\sP(AR)?T\s.)?$
            }x,

          # V. 75:NO. 149(2010) /* 659 */
          %r{
          ^V\.\s?(?<volume>\d+):NO\.\s(?<number>\d+)\((?<year>\d{4})\)$
          }x,

          # V. 78 NO. 152 AUG 7, 2013 /* 242 */
          # V. 67:NO. 50 (MAY 14,2002) /* 3 */
          #   %r{
          # ^V\. \d+:NO\. \d+ ?\(\p{Alpha}{3,}\.? \d{1,2}(,| )\d{4}\)$
          # }x,
          %r{
            ^V\.?\s?(?<volume>\d+)(:|\s)NO\.?\s?(?<number>\d+)\s?\(?
            (?<month>\p{Alpha}{3,})\.?\s(?<day>\d{1,2})(\s|,\s|,)
            (?<year>\d{4})\)?$
            }x,

          # V. 1 (1936:MAY 28/JUNE 11)  /* 849 */
          # V. 1 (1936:SEPT. 15/25)
          %r{
            ^V\.?\s?(?<volume>\d+)\s?\((?<year>\d{4}):
            (?<month_start>\p{Alpha}{3,4})\.?\s(?<day_start>\d{1,2})\/
            ((?<month_end>\p{Alpha}{3,4})\.?\s)?(?<day_end>\d{1,2})\)$
            }x,

          # crap /* 152 */
          # #  %r{
          # ^V\.\s(?<volume>04\d)\sPT.*\d[A-Z]$
          # }x,

          # 74,121 /* 196 */
          %r{
            ^(?<volume>\d+),(?<number>\d+)$
            }x,

          # 1964 /* 44 */
          %r{
            ^(?<year>\d{4})$
            }x,

          # V. 13 /* 36 */
          %r{
            ^V\.\s(?<volume>\d+)$
            }x,

          # V. 72:PT. 61 /* 234 */
          # V. 70:PT186 /* 1 */
          %r{
            ^V\.\s?(?<volume>\d+):PT\.?\s?(?<number>\d+)$
            }x,

          # V. 39-42 (1974-77) /* 9 */
          %r{
            ^V\.\s(?<volume_start>\d+)-(?<volume_end>\d+)\s?\(
            (?<year_start>\d{4})-(?<year_end>\d{2,4})\)$
            }x,

          # V. 62:NO. 181 /* 4 */
          %r{
            ^V\.\s(?<volume>\d+):NO\.\s(?<number>\d+)$
            }x,

          # V. 78:NO. 38-75(2013) /* 5 */
          %r{
            ^V\.\s(?<volume>\d+):\s?NO\.\s(?<number_start>\d+)-
            (?<number_end>\d+)(\((?<year>\d{4})\))?$
            }x,

          # V. 78:NO. 160-161(2013:AUG. 19-20) /* 18 */
          %r{
            ^V\.\s(?<volume>\d+):\s?NO\.\s(?<number_start>\d+)-
            (?<number_end>\d+)\((?<year>\d{4}):(?<month>\p{Alpha}{3,})
            \.?\s(?<day_start>\d+)-(?<day_end>\d+)\)$
            }x,

          # V. 4 (1939:DEC. 30) /* 37 */
          %r{
            ^V\.\s(?<volume>\d+)\s\((?<year>\d{4}):(?<month>\p{Alpha}{3,})
            \.?\s(?<day>\d{1,2})\)$
            }x,

          # V. 9 (1944:JULY 22:P. 8284-8381) /* only 8 */
          %r{
            ^V\.\s(?<volume>\d+)\s\((?<year>\d{4}):(?<month>\p{Alpha}{3,})
            \.?\s(?<day>\d{1,2}):P\.\s(?<page_start>\d+)-(?<page_end>\d+)\)$
            }x,

          # V. 47 (1982:JAN. 4-5) /* 33 */
          %r{
            ^V\.\s(?<volume>\d+)\s\((?<year>\d{4}):(?<month>\p{Alpha}{3,})\.?\s
            (?<day_start>\d{1,2})-(?<day_end>\d{1,2})\)$
            }x,

          # V. 78:NO. 164-173(2013:AUG. 23-SEPT. 6) /* 10 */
          # V. 78:NO. 147-158(2013:JULY31-AUG. 15) /* 3 w/ spaces optional */
          %r{
            ^V\.\s(?<volume>\d+):NO\.\s(?<number_start>\d+)-(?<number_end>\d+)\(
            (?<year>\d{4}):(?<month_start>\p{Alpha}{3,})\.?\s?
            (?<day_start>\d{1,2})-(?<month_end>\p{Alpha}{3,})\.?\s?
            (?<day_end>\d{1,2})\)$
            }x,

          # V. 15:P. 2701-4070 1950  /* wu */  /* 842 */
          # V. 8:P. 5659-7206 (1943) /* MNU */
          %r{
            ^V\.\s(?<volume>\d+):P\.\s(?<page_start>\d+)-(?<page_end>\d+)\s\(?
            (?<year>\d{4})\)?$
            }x,

          # V. 9 JUL 1944  /* 354 */
          # V. 5 OCT-DEC 1940
          %r{
            ^V\.\s(?<volume>\d+)\s(?<month>\p{Alpha}{3})
            (-(?<month_end>\p{Alpha}{3}))?\s(?<year>\d{4})$
            }x,

          # V. 40 MAY1-9 1975 /* 348 */
          %r{
            ^V\.\s(?<volume>\d+)\s(?<month>\p{Alpha}{3})(?<day_start>\d{1,2})-
            (?<day_end>\d{1,2})\s(?<year>\d{4})$
            }x,

          # V. 47 OCT28 1982 PP. 47799-49004  /* 114 */
          # V. 47 DEC10-16 1982 PP. 55455-56468
          %r{
            ^V\.\s(?<volume>\d+)\s(?<month>\p{Alpha}{3})(?<day>\d{1,2})
            (-(?<day_end>\d{1,2}))?\s(?<year>\d{4})\sPP\.\s(?<page_start>\d+)-
            (?<page_end>\d+)$
            }x,

          # V. 3 JAN1-JUN3 1938 /* 7 */
          %r{
            ^V\.\s(?<volume>\d+)\s(?<month_start>\p{Alpha}{3})
            (?<day_start>\d{1,2})-(?<month_end>\p{Alpha}{3})
            (?<day_end>\d{1,2})\s(?<year>\d{4})$
          }x,

          # V. 47 JUN29-JUL1 1982 PP. 28067-28894 /* 12 */
          %r{
            ^V\.\s(?<volume>\d+)\s(?<month_start>\p{Alpha}{3})
            (?<day_start>\d{1,2})-(?<month_end>\p{Alpha}{3})(?<day_end>\d{1,2})
            \s(?<year>\d{4})\sPP\.\s(?<page_start>\d+)-(?<page_end>\d+)$
            }x,

          # V. 63 NO 62-74 (APR 1-17 1998) (1 RLLE)
          %r{
            ^V\.\s(?<volume>\d+)[\s:]NO\.\s(?<number_start>\d+)-
            (?<number_end>\d+)\s\(
            }x,

          # V. 70:NO. 222(2005:222) #Volume and Number is enough
          # V. 13:NO. 192-213(1948:OCT. )
          %r{
            ^V\.\s(?<volume>\d+)[:,\/\s]NO\.\s(?<number>\d+)\s?\(?
            }x,
          %r{
            ^V\.?\s?(?<volume>\d+)(:|\s)NO\.?\s?(?<number_start>\d+)-
            (?<number_end>\d+)[^\d]
            }x
        ]
      end

      def self.oclcs
        [1_768_512,
         3_803_349,
         9_090_879,
         6_141_934,
         27_183_168,
         9_524_639,
         60_637_209,
         25_816_139,
         27_163_912,
         7_979_808,
         4_828_080,
         18_519_766,
         41_954_100,
         43_080_713,
         38_469_925,
         97_118_565,
         70_285_150]
      end

      def parse_ec(ec_string)
        matchdata = nil

        ec_string = preprocess(ec_string).chomp

        @patterns.each do |p|
          break unless matchdata.nil?
          matchdata ||= p.match(ec_string)
        end

        unless matchdata.nil?
          ec = matchdata.named_captures 
          if matchdata.names.include?('year') && !matchdata.names.include?('volume')
            ec['volume'] = FederalRegister.year_to_vol[ec['year']]
          end
        end
        ec # ec string parsed into hash
      end

      # take a parsed enumchron and expand it into its constituent parts
      # enum_chrons - { <canonical ec string> : {<parsed features>}, }
      def explode(ec, _src = nil)
        enum_chrons = {}
        return {} if ec.nil?

        if ec['number'] && ec['volume']
          enum_chrons["Volume:#{ec['volume']}, Number:#{ec['number']}"] = ec
        elsif (ec['number_start'] && ec['volume']) ||
              ((ec.keys.count == 1) && ec['volume']) ||
              ((ec.keys.count == 2) && ec['volume'] && ec['year'])
          # a starting number and potentially ending number
          ec['number_start'] ||= '1'
          ec['number_end'] ||= FederalRegister.nums_per_vol[ec['volume']]
          (ec['number_start']..ec['number_end']).each do |n|
            enum_chrons["Volume:#{ec['volume']}, Number:#{n}"] = ec
          end
        end

        enum_chrons
      end

      def canonicalize(ec); end

      def self.year_to_vol
        @year_to_vol
      end

      def self.nums_per_vol
        @nums_per_vol
      end

      def self.load_context
        ncs = File.dirname(__FILE__) + '/data/fr_number_counts.tsv'
        File.open(ncs).each do |line|
          year, volume, numbers = line.chomp.split(/\t/)
          @year_to_vol[year] = volume
          @nums_per_vol[volume] = numbers
        end
      end
      load_context
    end
  end
end
