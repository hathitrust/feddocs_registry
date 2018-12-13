module Registry
  module Series
    class DefaultSeriesHandler
      attr_accessor :patterns
      attr_accessor :tokens
      attr_accessor :title

      def initialize
        @title = 'Default Series Handler'

        @tokens = {
          # divider
          div: '[\s:,;\/-]+\s?',

          # volume
          v: '(V\.\s?)?V(OLUME:)?\.?\s?(0+)?(?<volume>\d+)',

          # number
          n: 'N(O|UMBER:)\.?\s?(0+)?(?<number>\d+)',

          # numbers
          ns: '(START\s)?N(OS?|UMBERS?:)\.?\s?(0+)?(?<start_number>\d+)(-|,\sEND\sNUMBER:)(?<end_number>\d+)',

          # part
          # have to be careful with this due to frequent use of pages in enumchrons
          pt: '\[?P(AR)?T:?\.?\s?(0+)?(?<part>\d+)\]?',

          # year
          y: '(YEAR:|YR\.\s)?\[?(?<year>(1[8-9]|20)\d{2})\.?\]?',

          # book
          b: 'B(OO)?K:?\.?\s?(?<book>\d+)',

          # sheet
          sh: 'SHEET:?\.?\s?(?<sheet>\d+)',

          # month
          m: '(MONTH:)?(?<month>(JAN(UARY)?|FEB(RUARY)?|MAR(CH)?|APR(IL)?|MAY|JUNE?|JULY?|AUG(UST)?|SEPT?(EMBER)?|OCT(OBER)?|NOV(EMBER)?|DEC(EMBER)?)\.?)',

          # day
          day: '(DAY:)?(?<day>[0-3]?[0-9])',

          # supplement
          sup: '(?<supplement>(SUP|PLEMENT)\.?)',

          # pages
          pgs: 'P[PG]\.(\s|:)(?<start_page>\d{1,5})-(?<end_page>\d{1,5})'

        }

        @patterns = [
          /^#{@tokens[:v]}$/xi,

          # risky business
          /^(0+)?(?<volume>[1-9])$/xi,

          /^#{@tokens[:n]}$/xi,

          /^#{@tokens[:pt]}$/xi,

          /^#{@tokens[:y]}$/xi,

          /^#{@tokens[:b]}$/xi,

          /^#{@tokens[:sh]}$/xi,

          /^#{@tokens[:m]}$/xi,

          /^#{@tokens[:sup]}$/xi,

          # compound patterns
          /^#{@tokens[:v]}#{@tokens[:div]}#{@tokens[:pt]}$/xi,

          /^#{@tokens[:y]}#{@tokens[:div]}#{@tokens[:pt]}$/xi,

          /^#{@tokens[:y]}#{@tokens[:div]}#{@tokens[:v]}$/xi,

          # 1988:MAY 17
          %r{
            ^#{@tokens[:y]}#{@tokens[:div]}
            #{@tokens[:m]}#{@tokens[:div]}
            #{@tokens[:day]}$
          }xi,

          /^#{@tokens[:v]}#{@tokens[:div]}#{@tokens[:ns]}$/xi,

          /^#{@tokens[:v]}[\(\s]\s?#{@tokens[:y]}\)?$/xi,

          /^#{@tokens[:v]}#{@tokens[:div]}#{@tokens[:n]}$/xi,

          # NO. 42 (2005:APR. 13)
          %r{
            ^#{@tokens[:n]}#{@tokens[:div]}
            \(\s?#{@tokens[:y]}#{@tokens[:div]}
            #{@tokens[:m]}\s#{@tokens[:day]}\)$
          }xi,

          # 1896 PT. 1
          %r{
            ^#{@tokens[:y]}#{@tokens[:div]}
             #{@tokens[:pt]}$
          }xi,

          # 1896 V. 2 PT. 1
          %r{
            ^#{@tokens[:y]}#{@tokens[:div]}
             #{@tokens[:v]}#{@tokens[:div]}
             #{@tokens[:pt]}$
          }xi,

          %r{
            ^#{@tokens[:v]}#{@tokens[:div]}
            #{@tokens[:pt]}#{@tokens[:div]}
            #{@tokens[:y]}$
          }xi,

          # V. 24:NO. 1(2009)
          # V. 16,NO. 23 2001 SEP.
          # V. 12 NO. 37 1997 SUP.
          %r{
            ^#{@tokens[:v]}#{@tokens[:div]}
            #{@tokens[:n]}\s?
            (#{@tokens[:div]}|\()
            #{@tokens[:y]}
            (#{@tokens[:div]}#{@tokens[:m]})?\)?
            (#{@tokens[:div]}#{@tokens[:sup]})?$
          }xi,

          # V. 27, NO. 13 (SEPTEMBER 21 - SEPTEMBER 28, 2012)
          %r{
            ^#{@tokens[:v]}#{@tokens[:div]}
            #{@tokens[:n]}#{@tokens[:div]}
            \((?<start_month>#{@tokens[:m]})\s?(?<start_day>\d{1,2})
            #{@tokens[:div]}
            (?<end_month>#{@tokens[:m]})\s?(?<end_day>\d{1,2})
            #{@tokens[:div]}
            #{@tokens[:y]}\)$
          }xi,

          # V. 30NO. 6 2015 [sic]
          %r{
            ^#{@tokens[:v]}
            #{@tokens[:n]}(#{@tokens[:div]}
            #{@tokens[:y]})?$
          }xi,

          # V. 8:NO. 19-22 1993
          %r{
            ^#{@tokens[:v]}#{@tokens[:div]}
            #{@tokens[:ns]}\s?
            (#{@tokens[:div]}|\()
            #{@tokens[:y]}\)?$
          }xi,

          %r{
            ^#{@tokens[:v]}#{@tokens[:div]}
            #{@tokens[:n]}\s?
            \(#{@tokens[:y]}#{@tokens[:div]}
              #{@tokens[:m]}\s#{@tokens[:day]}\)$
          }xi,

          # V. 16, NO. 12 (APR. 2001)
          # V. 12, NO. 29, (OCT. 1997)
          %r{
            ^#{@tokens[:v]}#{@tokens[:div]}
            #{@tokens[:n]}(#{@tokens[:div]})?
            \(#{@tokens[:m]}\s#{@tokens[:y]}\)$
          }xi,

          # V. 2, NO. 25-26 (DEC. 1987)
          %r{
            ^#{@tokens[:v]}#{@tokens[:div]}
            #{@tokens[:ns]}\s?
            \(#{@tokens[:m]}\s#{@tokens[:y]}\)?$
          }xi,

          # V. 2, NO. 25-26 (JUL. -AUG. 1995)
          %r{
            ^#{@tokens[:v]}#{@tokens[:div]}
            #{@tokens[:ns]}\s?
            \((?<start_month>#{@tokens[:m]})#{@tokens[:div]}
            (?<end_month>#{@tokens[:m]})
            #{@tokens[:div]}
            #{@tokens[:y]}\)?$
          }xi,

          %r{
            ^#{@tokens[:y]}#{@tokens[:div]}
            #{@tokens[:v]}#{@tokens[:div]}
            #{@tokens[:pt]}$
          }xi,

          /^#{@tokens[:y]}#{@tokens[:div]}#{@tokens[:m]}$/xi,

          /^#{@tokens[:m]}#{@tokens[:div]}#{@tokens[:y]}$/xi,

          %r{
            ^#{@tokens[:n]}#{@tokens[:div]}
            #{@tokens[:m]}#{@tokens[:div]}
            #{@tokens[:y]}$
          }xi,

          %r{
            ^#{@tokens[:n]}#{@tokens[:div]}
            [\(\s]\s?#{@tokens[:y]}\)$
          }xi,

          %r{
            ^#{@tokens[:y]}#{@tokens[:div]}
            #{@tokens[:m]}#{@tokens[:div]}
            #{@tokens[:n]}$
          }xi,

          %r{
            ^#{@tokens[:n]}#{@tokens[:div]}
            #{@tokens[:pt]}$
          }xi,

          %r{
            ^#{@tokens[:y]}#{@tokens[:div]}
            (START\sMONTH:)?(?<start_month>#{@tokens[:m]})#{@tokens[:div]}
            (END\sMONTH:)?(?<end_month>#{@tokens[:m]})$
          }xi,

          # V. 9 PG. 1535-2248 1994
          %r{
            ^#{@tokens[:v]}#{@tokens[:div]}
            #{@tokens[:pgs]}
            (\(?#{@tokens[:div]}#{@tokens[:y]}\)?)?$
          }xi,

          # V. 5 1990 PP. 4783-5463
          %r{
            ^#{@tokens[:v]}#{@tokens[:div]}
            #{@tokens[:y]}#{@tokens[:div]}
            #{@tokens[:pgs]}$
          }xi,

          # 2013 FEB. 1-26
          # 2012 FEB. 21-MAR. 16
          %r{
            ^#{@tokens[:y]}#{@tokens[:div]}
            (?<start_month>#{@tokens[:m]})#{@tokens[:div]}
            (?<start_day>\d{1,2})#{@tokens[:div]}
            ((?<end_month>#{@tokens[:m]})#{@tokens[:div]})?
            (?<end_day>\d{1,2})
          }xi
        ]
      end

      def preprocess(ec_string)
        # fix 3 digit years, this is more restrictive than most series specific
        # work.
        ec_string = '1' + ec_string if ec_string.match?(/^9\d\d$/)
        ec_string.sub(/^C\. [1-2] /, '').sub(/\(\s/, '(').sub(/\s\)/, ')')
      end

      def parse_ec(ec_string)
        matchdata = nil

        ec_string = preprocess(ec_string).chomp

        @patterns.each do |p|
          break unless matchdata.nil?

          matchdata ||= p.match(ec_string)
        end

        # some cleanup
        unless matchdata.nil?
          ec = matchdata.named_captures
          # Fix months
          ec = Series.fix_months(ec)

          # Remove nils
          ec.delete_if { |_k, value| value.nil? }

          # supplement
          ec['supplement'] = 'Supplement' if ec['supplement'] =~ /^sup/i

          # year unlikely. Probably don't know what we think we know.
          # From the regex, year can't be < 1800
          ec = nil if ec['year'].to_i > (Time.now.year + 5)
        end
        ec
      end

      def canonicalize(ec)
        # default order is:
        t_order = %w[year month start_month end_month volume part number start_number end_number book sheet start_page end_page supplement]
        canon = t_order.reject { |t| ec[t].nil? }
                       .collect { |t| t.to_s.tr('_', ' ').capitalize + ':' + ec[t] }
                       .join(', ')
        canon = nil if canon == ''
        canon
      end

      def explode(ec, _src = nil)
        # we would need to know something about the title to do this
        # accurately, so we're not really doing anything here
        enum_chrons = {}
        return {} if ec.nil?

        ecs = [ec]
        ecs.each do |enum|
          if (canon = canonicalize(enum))
            enum['canon'] = canon
            enum_chrons[enum['canon']] = enum.clone
          end
        end
        enum_chrons
      end
    end
  end
end
