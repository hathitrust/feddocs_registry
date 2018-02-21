require 'pp'

module Registry
  module Series
    # Vital Statistics series
    module VitalStatistics
      # class << self; attr_accessor :volumes end
      # @volumes = {}

      def self.sudoc_stem; end

      def self.oclcs
        [1_168_068, 48_062_652]
      end

      def parse_ec(ec_string)
        # our match
        m = nil

        ec_string.chomp!

        ec_string = remove_dupe_years ec_string
        # remove copy info
        ec_string.gsub!(/^C\. \d /, '')
        ec_string.gsub!(/ C\. \d$/, '')

        # remove withdrawn(?) info
        ec_string.gsub!(/ - WD$/, '')

        # remove useless
        # 1993:V. 2:PT. A = 993/V. 2/PT. A
        ec_string.gsub!(/ = .*$/, '')

        # fix the three digit years
        ec_string = '1' + ec_string if ec_string.match?(/^[89]\d\d[^0-9]*/)
        # seriously
        ec_string = '2' + ec_string if ec_string.match?(/^0\d\d[^0-9]*/)

        # tokens
        y = '(Y(ear|R\.)?[:\s])?(?<year>\d{4})'
        v = 'V(olume|\.)?[:\s]?(?<volume>\d{1,2})'
        p = 'P(art|T\.?)?[:\s]?(?<part>\w{1,2})'
        div = '[\s:,;\/-]+\s?\(?'
        app = '(?<appendix>(TECH\.?\s)?APP(EN)?D?I?X?\.?)'
        sec = 'SECT?(ION)?\.?[:\s]?(?<section>\d+)'
        sup = '(?<supplement>SUPP?(LEMENT)?\.?)'

        patterns = [
          # canonical
          # Year:1960, Volume:2, Part:A
          # Year:1961, Volume:3, Appendix
          # Year:1943, Section:1
          # Year:1943, Supplement
          # 1960,V. 2,PT. A
          # 1937 V. 2
          /
            ^#{y}
            (#{div}#{v})?
            (#{div}#{p})?
            (#{div}#{sec})?
            (#{div}#{sup})?
            (#{div}#{app})?$
          /xi,

          # 1971:V. 2A
          /
            ^#{y}
            #{div}#{v}(?<part>[A-Z])$
          /x,

          # 1966:3
          # 1963:2A
          # 1985:2:A
          # 1984:V. 2:B
          /
            ^#{y}
            #{div}
            (V\.\s)?(?<volume>\d)
            (:?(?<part>[A-Z]))?$
          /x,

          # 1943SEC1
          # 1960V1SEC3
          /
            ^#{y}
            (#{div})?
            (V(?<volume>\d))?
            (#{div})?
            #{sec}$
          /x,

          # 938/2, -1938
          # 963/2A, -1963
          # 982/V. 2B, -1982
          # 986/2/A, -1986
          /
            ^#{y}
            #{div}
            (V\.?\s?)?(?<volume>\d)
            (#{div})?
            (?<part>[A-Z])?
            ,\s-\d{4}$
          /x,

          # 1986V. 2PT. B 1986
          # 1988V. 3 1988
          # 1992:V. 2/APP.
          /
            ^#{y}
            (#{div})?
            #{v}
            ((#{div})?#{p})?
            (#{div}#{app})?
            ((#{div})?\d{4})?$
          /x,

          # 977/V. 2 PT. A, -1977
          # 989/V. 2/PT. A, -1989
          /
            ^#{y}
            #{div}
            #{v}
            (#{div}#{p})?
            ,\s-\d{4}$
          /x,

          # 1986:V. 2:SEC. 6:1986
          # 1990/V. 2/PT. A (1990)
          # 1991/V. 1/SEC. 4 (1991)
          # 1993:V. 2/PT. A/
          # 1993:V. 2/PT. B/
          # 1993 V. 2 SECT. 6 PT. A
          %r{
            ^#{y}
            #{div}
            #{v}
            (#{div}#{sec})?
            (#{div}#{p})?
            \/?(#{div}\d{4}\)?)?$
          }x,

          # 'V. 3 (1968)'
          # V1 1939
          # V. 1(1988)
          # V. 1 (1990:NATALITY)
          /
            ^#{v}
            (#{div})?\(?
            #{y}
            (:[A-Z]+)?\)?$
          /x,

          # V. 2B (1978)
          # V. 2:PT. A(1988)
          /
            ^#{v}
            (:PT\.\s)?(?<part>[A-Z])
            \s?\(#{y}\)$
          /x,

          # V. 1950:3
          # V. 1960:2B
          # V. 1963:2:B
          # V. 1985:2:APPENDIX
          /
            ^V\.\s(?<year>\d{4}):
            (?<volume>\d)
            (:?(?<part>[A-Z]))?
            (#{div}#{app})?$
          /x,

          # 1991:V. 1:SUP.

          # Don't really tell us anything, but might as well parse and merge
          # 1927 PT1
          # 1937PT1
          /
            ^#{y}
            (#{div})?
            #{p}$
          /x,
          # PT. 1 (1943)
          /
            ^#{p}
            #{div}
            #{y}\)?$
          /x,

          # 1953V2
          /
            ^#{y}
            V(?<volume>\d)$
          /x,

          # simple year
          /
            ^#{y}$
          /x
        ] # patterns

        patterns.each do |p|
          break unless m.nil?
          m ||= p.match(ec_string)
        end

        unless m.nil?
          ec = Hash[m.names.zip(m.captures)]
          ec.delete_if { |_k, v| v.nil? }
        end
        ec
      end

      def explode(ec, _src = nil)
        enum_chrons = {}
        return {} if ec.nil?

        ecs = []
        ecs << ec

        ecs.each do |ec|
          if (canon = canonicalize(ec))
            ec['canon'] = canon
            enum_chrons[ec['canon']] = ec.clone
          end
        end

        enum_chrons
      end

      def canonicalize(ec)
        canon = []
        canon << "Year:#{ec['year']}" if ec['year']
        canon << "Volume:#{ec['volume']}" if ec['volume']
        canon << "Part:#{ec['part']}" if ec['part']
        canon << "Section:#{ec['section']}" if ec['section']
        canon << 'Appendix' if ec['appendix']
        canon << 'Supplement' if ec['supplement']
        canon.join(', ') unless canon.empty?
      end

      def remove_dupe_years(ec_string)
        m = ec_string.match(/ (?<first>\d{4}) (?<second>\d{4})$/)
        if !m.nil? && (m['first'] == m['second'])
          ec_string.gsub(/ \d{4}$/, '')
        else
          ec_string
        end
      end

      def self.load_context; end
      load_context
    end
  end
end
