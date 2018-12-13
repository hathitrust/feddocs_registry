require 'pp'
require 'registry/series/default_series_handler'

module Registry
  module Series
    # The Statistical Abstract was published annually, 1878 through 2012.
    # The 1944/1945, 1982/1983, and 2004/2005 editions were published as two
    # year volumes. No volume was produced for 1884 or 1927.
    class StatisticalAbstract < DefaultSeriesHandler
      class << self; attr_accessor :years, :editions end
      @years = {}
      @editions = {}

      def initialize
        super
        @patterns = [
          # canonical form
          %r{
            ^Edition:(?<edition>\d{1,3}),\s
            Year:(?<year>\d{4})$
          }xi,
          %r{
            ^Edition:(?<edition>\d{1,3}),\s
            Year:(?<start_year>\d{4})-(?<end_year>\d{4})$
          }xi,
          %r{
            ^Edition:(?<start_edition>\d{1,3})-(?<end_edition>\d{1,3}),\s
            Year:(?<year>\d{4})$
          }xi,

          # simple year
          # 2008 /* 257 */
          # (2008)
          # Year:2008
          /^\(?(?<year>\d{4})\)?$/xi,
          /^Year:(?<year>\d{4})$/xi,

          # edition prefix /* 316 */
          # 101ST 1980
          # 101ST (1980)
          # 101ST ED. 1980
          # 101ST ED. (1980)
          %r{
            ^(?<edition>\d{1,3})(TH|ST|ND|RD)?\s(ED\.)?\s?
            \(?(?<year>\d{4})\)?$
          }xi,

          # V. 120
          /^V\.\s?(?<edition>\d{1,3})$/xi,

          # edition/volume prefix then year /* 177 */
          # V. 2007
          # V. 81 1960
          # V. 81 (1960)
          # V. 81 (960)
          %r{
            ^V\.\s?(NO\.?\s)?(?<edition>\d{1,3})?\s
            \(?(?<year>\d{3,4})\)?$
          }xi,

          # just edition/volume /* 55 */
          /^(V\.?\s?\s)?(?<edition>\d{1,3})$/xi,

          # 1971 (92ND ED. ) /* 83 */
          # 1971 92ND ED.
          %r{
            ^(?<year>\d{4})\s
            \(?(?<edition>\d{1,3})(TH|ST|ND|RD)\sED\.\s?\)?$
          }xi,

          # 1930 (NO. 52) /* 54 */
          /^(?<year>\d{4})\s\(NO\.\s(?<edition>\d{1,3})\)$/xi,

          # edition year /* 66 */
          # 92 1971
          /^(?<edition>\d{1,3})D?\s(?<year>\d{4})$/xi,

          # 94TH,1973 /* 100 */
          /^(?<edition>\d{1,3})(TH|ST|ND|RD)?,\s?(?<year>\d{4})$/xi,

          # 43RD(1920)
          /^(?<edition>\d{1,3})(TH|ST|ND|RD)\((?<year>\d{4})\)$/xi,

          # 54TH NO. 1932 /* 54 */
          /^(?<edition>\d{1,3})(TH|ST|ND|RD)\sNO\.\s(?<year>\d{4})$/xi,

          # 110TH /* */
          # 110TH ED.
          /^(?<edition>\d{1,3})(TH|ST|ND|RD)(\sED\.)?$/xi,

          # V. 2010 129 ED /* 13 */
          # V. 2010 ED 129
          /^V\.\s(?<year>\d{4})\s(ED\.?\s)?(?<edition>\d{1,3})(\sED\.?)?$/xi,

          # year range /* */
          # 989-990
          # 1961-1963
          # V. 2004-2005 124
          %r{
            ^(V\.\s)?(?<start_year>\d{4})[-\/](?<end_year>\d{2,4})
            (\s(?<edition>\d{1,3}))?$
          }xi,

          # 122ND ED. (2002/2003)
          # 103RD (1982-1983)
          # 122ND EDITION 2002
          # 122ND ED. (2002/2003)
          # 122ND EDITION 2002
          # 103RD ED. (1982-1983)
          %r{
            ^(?<edition>\d{1,3})(TH|ST|ND|RD)(\sED\.|\sEDITION)?\s
            \(?((?<year>\d{4})|(?<start_year>\d{4})[\/-]
                (?<end_year>\d{2,4}))\)?$
          }xi,

          # ED. 127 2008
          # V. 103 1982-83
          # V. 103 1982/83
          %r{
            ^(ED\.|V\.)\s(?<edition>\d{1,3})\s
            ((?<year>\d{4})|(?<start_year>\d{4})[-\/]
             (?<end_year>\d{2,4}))$
          }xi,

          # 26-27 (903-904)
          %r{
            ^(?<start_edition>\d{1,2})
            -(?<end_edition>\d{1,2})\s
            \((?<start_year>\d{3,4})-
            (?<end_year>\d{3,4})\)$
          }xi,

          # 1973-1974 P83-1687
          /^(?<start_year>\d{4})-(?<end_year>\d{2,4})\sP83.*/xi,

          # 1878-82 (NO. 1-5)
          # 1883-87 (NO. 6-10)
          # 1944-45 (NO. 66)
          %r{
            ^(?<start_year>\d{4})-(?<end_year>\d{2,4})\s
            \(NO\.\s((?<start_edition>\d{1,3})
                     -(?<end_edition>\d{1,3})|(?<edition>\d{1,3}))\)$
          }xi,

          # 101(1980)
          # 103 1982-83
          # 103D 1982-83
          # 103RD,1982/83
          %r{
            ^(?<edition>\d{1,3})(TH|ST|ND|RD|D)?[\(\s,]
            \(?((?<start_year>\d{4})[-\/]
                (?<end_year>\d{2,4})|(?<year>\d{4}))\)?$
          }xi,

          # V. 16-17 1893-94
          # V. 7-8 1884-85
          # V. 9-11 1887-1889
          %r{
            ^V\.\s(?<start_edition>\d{1,3})-(?<end_edition>\d{1,3})\s
            (?<start_year>\d{4})-(?<end_year>\d{2,4})$
          }xi,

          # (2004-2005)
          %r{
            ^\((?<start_year>\d{4})-(?<end_year>\d{2,4})\)$
          }xi,

          # 11 (888)
          # 49 (926 )
          # NO. 20(1897)
          %r{
            ^(NO\.\s)?(?<edition>\d{1,3})\s?
            \((?<year>\d{3,4})\s?\)$
          }xi,

          # 130H ED. (2011)
          # 130TH ED. ,2011
          # 131ST ED. ,2012
          %r{
            ^(?<edition>\d{1,3})(H|TH|ST|ND|RD|D)?
              \sED[\.,]\s[\(,]?(?<year>\d{4})\)?$
          }xi,

          # 12TH-13TH,1889-90
          # 12TH-13TH NO. 1889-1890
          # 14TH-15TH,1891-92
          # 16TH-17TH,1893-94
          # 1ST-4TH NO. 1878-1881
          # 10TH-11TH NO. 1887-1888
          %r{
            ^(?<start_edition>\d{1,3})(TH|ST|ND|RD)-
            (?<end_edition>\d{1,3})(TH|ST|ND|RD)(,|\sNO\.\s)
            (?<start_year>\d{4})-(?<end_year>\d{2,4})$
          }xi,

          # 1982-83 (103RD ED.)
          # 1982/83 (103RD ED.)
          %r{
            ^(?<start_year>\d{4})[-\/]
            (?<end_year>\d{2,4})\s
            \(?(?<edition>\d{1,3})(TH|ST|ND|RD)\sED\.\)?$
          }xi,

          # broader than it should be, but run close to last it should be okay
          # 1988 (108TH EDITION)
          # 2006, 125TH ED.
          %r{
            ^(V\.\s)?(?<year>\d{4})[,\s]\D+
              (?<edition>\d{1,3})(\D+|$)
          }xi,

          # hypothetical
          # 7TH-9TH
          %r{
            ^(?<start_edition>\d{1,3})(TH|ST|ND|RD)-
            (?<end_edition>\d{1,3})(TH|ST|ND|RD)$
          }xi,

          # 129TH ED. 2010 129 ED.
          # 129 2010 ED. 129
          %r{
            ^(?<edition>\d{1,3})(TH|ST|ND|RD|\s)\D*
              (?<year>\d{4})(\D|$)
          }xi
        ] # patterns
      end

      def self.oclcs
        [1_193_890]
      end

      def parse_ec(ec_string)
        matchdata = nil

        # some junk in the front
        ec_string.gsub!(/REEL \d+.* P77-/, '')
        ec_string.gsub!(/^A V\./, 'V.')
        ec_string.gsub!(/^: /, '')
        ec_string.gsub!(/^C\. \d+ V/, 'V')
        ec_string.gsub!(/^C\. \d+ ?/, '')

        # space before trailing ) is always a typo
        ec_string.gsub!(/ \)/, ')')

        # trailing junk
        ec_string.gsub!(/[,: ]$/, '')

        # remove unnecessary crap
        ec_string.gsub!(/ ?= ?[0-9]+.*/, '')

        # remove useless 'copy' information
        ec_string.gsub!(/ C(OP)?\. \d$/, '')

        # we don't care about withdrawn status for enumchron parsing
        ec_string.gsub!(/ - WD/, '')

        # fix the three digit years
        ec_string = '1' + ec_string if ec_string.match?(/^[89]\d\d[^0-9]*/)
        # seriously
        ec_string = '2' + ec_string if ec_string.match?(/^0\d\d[^0-9]*/)

        # sometimes years get duplicated
        ec_string.gsub!(/(?<y>\d{4}) \(?\k<y>\)?/, '\k<y>')


        @patterns.each do |p|
          break unless matchdata.nil?

          matchdata ||= p.match(ec_string)
        end

        unless matchdata.nil?
          ec = matchdata.named_captures 
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
            ec['end_year'] = if ec['end_year'].to_i < \
                                ec['start_year'][2, 2].to_i
                               # crosses century. e.g. 1998-01
                               (ec['start_year'][0, 2].to_i + 1).to_s +
                                 ec['end_year']
                             else
                               ec['start_year'][0, 2] + ec['end_year']
                             end
          elsif ec.key?('end_year') && /^\d\d\d$/.match(ec['end_year'])
            # add a 2; 1699 and 2699 are both wrong, but...
            ec['end_year'] = if ec['end_year'].to_i < 700
                               '2' + ec['end_year']
                             else
                               '1' + ec['end_year']
                             end
          end
        end
        ec # ec string parsed into hash
      end

      # Take a parsed enumchron and expand it into its constituent parts
      # Real simple for this series because we have the complete list and can
      # perform a lookup using edition or year.
      # enum_chrons - { <canonical ec string> : {<parsed features>}, }
      #
      # Canonical string format: <edition number>, <year>-<year>
      def explode(ec, _src = nil)
        enum_chrons = {}
        return {} if ec.nil?

        # we will trust edition more than year so start there
        if ec['edition']
          canon = StatisticalAbstract.editions[ec['edition']]
          enum_chrons[canon] = ec if canon
        elsif ec['start_edition'] && ec['end_edition']
          # might end up with duplicates for the combined years. Won't matter
          (ec['start_edition']..ec['end_edition']).each do |ed|
            canon = StatisticalAbstract.editions[ed]
            enum_chrons[canon] = ec if canon
          end
        elsif ec['year']
          canon = StatisticalAbstract.years[ec['year']]
          enum_chrons[canon] = ec if canon
        elsif ec['start_year'] && ec['end_year']
          (ec['start_year']..ec['end_year']).each do |y|
            canon = StatisticalAbstract.years[y]
            enum_chrons[canon] = ec if canon
          end
        end
        # else enum_chrons still equals {}

        enum_chrons
      end

      def canonicalize(ec); end

      def self.load_context
        # Be able to look up the correct canonical string with
        # any missing elements.
        canonical_items = File.dirname(__FILE__) +
                          '/data/statistical_abstract_editions.tsv'
        File.open(canonical_items).each do |line|
          edition, year = line.chomp.split(/\t/)
          canonical_string = "Edition:#{edition}, Year:#{year}"

          editions = edition.split('-')
          years = year.split('-')
          editions.each do |ed|
            self.editions[ed] = canonical_string
          end
          years.each do |y|
            self.years[y] = canonical_string
          end
        end
      end
      load_context
    end
  end
end
