# frozen_string_literal: true
require 'registry/series/default_series_handler'

module Registry
  module Series
    class MineralsYearbook < DefaultSeriesHandler
      def initialize
        super
        @title = 'Minerals Yearbook'
        # tokens
        y = '(YR\.\s)?(?<year>\d{4})'
        v = 'V\.?\s?(?<volume>\d)'
        vs = '(?<start_volume>\d)[-\/](?<end_volume>\d)'
        ps = '(?<start_part>\d)[-\/](?<end_part>\d)'
        div = '[\s:,;\/-]+\s?\(?'
        p = 'PT[\.:]?\s?(?<part>\d{1})'
        ys = '(?<start_year>\d{4})[-\/](?<end_year>\d{2,4})'
        ar = '(AREA\sREPORTS:)?'
        area = '(\(?(?<description>(AREA\s?RE?PO?R?TS:)?[A-Z]{3,}.*[A-Z]\.?(\s\d{4})?)\)?)'
        app = '(?<appendix>APP(END)?I?X?\.?)'
        stapp = '(?<statistical_appendix>STAT(ISTICAL)?\.?\sAPP(END)?I?X?\.?)'

        @patterns = [
          # canonical
          # Year:1995, Volume:1, Part:3
          # Year:1995-1996, Volume:1, Part:3
          %r{
            ^Year:(#{y}|(?<start_year>\d{4})-(?<end_year>\d{4}))
            (,\sVolume:(?<volume>\d))?
            (,\sPart:(?<part>\d))?
            (,\sDescription:(?<description>.*))?$
          }x,

          # simple year
          %r{
            ^#{y}$
          }x,

          # the area regex is broad enough to eat appendixes if not careful
          # 1934 APPENDIX
          %r{
            ^#{y}#{div}
            #{app}$
          }x,

          # 1935/STAT. APP.
          %r{
            ^#{y}#{div}#{stapp}$
          }x,
          %r{
            ^#{ys}#{div}#{stapp}$
          }x,

          # 932-33/app.
          %r{
            ^#{ys}#{div}#{app}$
          }x,

          # 1982 (V. 1)
          %r{
            ^#{y}(#{div})?\(#{v}
            (#{div}#{area})?\)$
          }x,

          # V. 3(1956)
          %r{
            ^#{v}\(#{y}\)$
          }x,

          # V. 1-2(1968)
          %r{
            ^V\.\s#{vs}\(#{y}\)$
          }x,

          # 2009:3:1- AREA REPORTS: AFRICA AND THE MIDDLE EAST
          %r{
            ^#{y}:(?<volume>\d):(?<part>\d)\s?(-\s?)?
            #{area}$
          }x,

          # 981/V. 2
          # 1908V. 1
          # 2006:V. 3:LATIN AMERICA/CANADA
          # 2006:V. 2(DOMESTIC)
          %r{
            ^#{y}(#{div})?#{v}
            ((#{div})?#{area})?$
          }x,

          # 1955:3 #assume volume
          # 2005:2 - AREA REPORTS: DOMESTIC
          # 2007:3 PT. 3 (INTL:EUROPE AND CENTRAL EURASIA)
          %r{
            ^#{y}#{div}(?<volume>\d)
            (#{div}#{p})?
            (\s?-?\s?#{area})?$
          }x,

          # 1978-79:1
          %r{
            ^#{ys}:(?<volume>\d)$
          }x,

          # 989:V. 3:1
          %r{
            ^#{y}#{div}#{v}#{div}
            (?<part>\d)$
          }x,

          # 1968 V. 1-2
          # 1969 (V. 1-2)
          %r{
            ^#{y}(#{div})?
            \(?(V\.\s?)?#{vs}\)?$
          }x,

          # V. 3(2008:EUROPE/CENTRAL EURASIA)
          %r{
            ^#{v}\((?<year>\d{4}):
            #{area}\)$
          }x,

          # V. 32006:LATIN AMERICA/CANADA
          %r{
            ^#{v}(?<year>\d{4})
           (#{div}#{area})$
          }x,

          # MIDDLE EAST1989:V. 3
          %r{
            ^#{area}(?<year>\d{4})#{div}#{v}$
          }x,

          # 1910:PT. 1
          %r{
            ^#{y}#{div}#{p}
            (#{div}#{area})?$
          }x,

          # 993-94/V. 2
          %r{
            ^#{ys}((#{div})?#{v}
                   (#{div}#{area})?)?$
          }x,

          # 2003/V. 3/NO. 4 EUROPE AND CENTRAL EURASIA
          %r{
            ^#{y}#{div}#{v}#{div}
            NO\.\s(?<number>\d)
            (#{div}#{area})?$
          }x,

          # 1978/79 (V. 3)
          %r{
            ^#{ys}#{div}
            \(?#{v}\)?
              (#{div}#{p})?$
          }x,

          # 1996:V. 3:PT. 2/3
          %r{
            ^#{y}#{div}#{v}#{div}PT\.\s#{ps}$
          }x,

          # 995:V. 2 1995, V. 2
          %r{
            ^#{y}#{div}#{v}#{div}
            #{y}(,\s#{v})?$
          }x,

          # 2007 V. 3 PT. 3
          # 1989V. 3PT. 5
          %r{
            ^#{y}(#{div})?#{v}(#{div})?#{p}
            (#{div}#{area})?$
          }x
        ] # patterns
      end

      

      def self.oclcs
        [1_847_412, 228_509_857, 48_997_937]
      end

      def parse_ec(ec_string)
        # our match
        matchdata = nil

        # fix 3 digit years
        ec_string = '1' + ec_string if ec_string.match?(/^9\d\d[^0-9]*/)

        # useless junk
        ec_string.sub!(/^TN23 \. U612 /, '')

        @patterns.each do |p|
          break unless matchdata.nil?
          matchdata ||= p.match(ec_string)
        end

        unless matchdata.nil?
          ec = matchdata.named_captures
          ec.delete_if { |_k, v| v.nil? }
          if ec.key? 'end_year'
            ec['end_year'] = Series.calc_end_year(ec['start_year'], ec['end_year'])
          end

          # kill the zero fills
          if ec['volume']
            ec['volume'].sub!(/^0+/, '')
          elsif ec['start_volume']
            ec['start_volume'].sub!(/^0+/, '')
            ec['end_volume'].sub!(/^0+/, '')
          end

          # fix area descriptions
          if ec['description']
            ec['description'] = normalize_description(ec['description'])
          end
        end
        ec
      end

      def explode(ec, _src = nil)
        enum_chrons = {}
        return {} if ec.nil?

        ecs = []
        if ec['start_volume']
          (ec['start_volume']..ec['end_volume']).each do |v|
            ecv = ec.clone
            ecv['volume'] = v
            ecs << ecv
          end
        # should never be both multi-volume and multi-part ranges
        elsif ec['start_part']
          (ec['start_part']..ec['end_part']).each do |p|
            ecp = ec.clone
            ecp['part'] = p
            ecs << ecp
          end
        else
          ecs << ec
        end

        ecs.each do |ec|
          if canon = canonicalize(ec)
            ec['canon'] = canon
            enum_chrons[ec['canon']] = ec.clone
          end
        end

        enum_chrons
      end

      # free text is terrible. the solution is just as bad
      def normalize_description(desc)
        # remove "AREA REPORTS" if it's not the only thing
        desc.sub!(/^AREA\s?RE?P(OR)?TS:?\s?/, '') if desc !~ /^AREA REPORTS$/
        desc.sub!(/^INTL:/, '')

        desc.sub!(/U\.?\s?S\.?\s?S\.?\s?R\.?\s?/, 'USSR')
        desc.sub!(/AFRICA\/\s?(THE\s)?MID/, 'AFRICA AND THE MID')
        desc.sub!(/ASIA[\/:]\s?(THE\s)?PAC.*/, 'ASIA AND THE PACIFIC')
        desc.sub!(/^ASIA[^\/]*/, 'ASIA AND THE PACIFIC')
        desc.sub!(/EUROPE[\/:]\s?CEN/, 'EUROPE AND CEN')
        desc.sub!(/EUROPE\sCEN/, 'EUROPE AND CEN')
        desc.sub!(/EUROPE[\/:]\s?USSR/, 'EUROPE AND THE USSR')
        desc.sub!(/LATIN\sAMERICA[\/:]\s?CANADA/, 'LATIN AMERICA AND CANADA')
        desc.sub!(/EUROPE AND CE?N?(TRA)?\.? EUR/, 'EUROPE AND CENTRAL EURASIA')
        desc.sub!(/METALS[\/:]\s?MI/, 'METALS AND MI')
        desc.sub!(/MID\.?\s/, 'MIDDLE ')
        desc.sub!(/AND\sMIDDLE/, 'AND THE MIDDLE')
        desc.sub!(/MIDDLE$/, 'MIDDLE EAST')
        desc.sub!(/MIN[\.\s]\s? IND/, 'MINERAL IND')
        desc.sub!(/INDUST\./, 'INDUSTRIES')
        desc.sub!(/^AFRICA MIDDLE EAST$/, 'AFRICA AND THE MIDDLE EAST')
        # seriously people
        desc.sub!(/^LATIN$/, 'LATIN AMERICA AND CANADA')
        desc.sub!(/^WORLD ECONO$/, 'WORLD ECONOMY')
        desc.sub!(/^EUROPE AND( CE(NTRAL?)?)?$/, 'EUROPE AND CENTRAL EURASIA')
        desc.sub!(/^EUROPE AND CENTRAL E$/, 'EUROPE AND CENTRAL EURASIA')
        desc
      end

      def canonicalize(ec)
        # Year:,Volume:,Part:, Description
        if ec['year'] || ec['start_year']
          if ec['year']
            canon = "Year:#{ec['year']}"
          elsif ec['start_year']
            canon = "Year:#{ec['start_year']}-#{ec['end_year']}"
          end
          canon += ", Volume:#{ec['volume']}" if ec['volume']
          canon += ", Part:#{ec['part']}" if ec['part']
          canon += ", Description:#{ec['description']}" if ec['description']
        end
        canon
      end

      def self.load_context; end
      load_context
    end
  end
end
