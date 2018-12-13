# frozen_string_literal: true
require 'registry/series/default_series_handler'

module Registry
  module Series
    class ReportsOfInvestigations < DefaultSeriesHandler
      def initialize 
        super
        # tokens
        div = '[\s:,;\/-]+\s?\(?'
        n = 'N(umber|O)\.?' + div + '(?<number>\d{4})'
        y = 'Y(ear|R)\.?\s?(?<year>\d{4})'
        ns = 'NO\.?\s?(?<start_number>[2-9]\d{3})-(?<end_number>\d{4})'
        # volumes are really numbers
        v = 'V(olume:)?\.?\s?(?<number>\d+)'
        vs = 'V?\.?\s?(?<start_number>[2-9]\d{3})-(?<end_number>\d{4})'

        @patterns = [
          # canonical
          # Number:8551
          %r{
            ^(Year:(?<year>\d{4}))?
            ((,\s)?#{n})?$
          }x,

          %r{
            ^Year:(?<start_year>\d{4})-(?<end_year>\d{4})
            ((,\s)?#{n})?$
          }x,

          # simple year
          %r{
            ^#{y}$
          }x,

          # NO. 8828-8829
          %r{
            ^#{ns}$
          }x,

          %r{
            ^#{n}$
          }x,

          %r{
            ^#{vs}$
          }x,

          %r{
            ^#{v}$
          }x,

          # NO. 8897-8918 YR. 1984
          %r{
            ^(#{n}|#{ns})#{div}#{y}$
          }x,

          # NO. 4840-4859 1952
          %r{
            ^(#{n}|#{ns})\s
            (?<year>19\d\d)$
          }x,

          # 2575 (1924)
          %r{
            ^(?<number>[2-9]\d{3})\s
            \((?<year>19\d\d)\)$
          }x,

          # NO. 8653 (1982)
          # NO. 7936 YR. 1974
          %r{
            ^#{n}\s
            (YR\.\s)?
            \(?(?<year>19\d\d)\)?$
          }x,

          # 8510-8525 (1981)
          %r{
            ^(?<start_number>[2-9]\d{3})-
            (?<end_number>\d{4})\s
            \((?<year>19\d\d)\)$
          }x,

          # NO. 3471-3480 1939-1940
          # 7955-7964 (1974-75)
          # NO. 5377-5390 YR. 1957-58
          %r{
            ^(NO\.\s)?(?<start_number>[2-9]\d{3})-
            (?<end_number>\d{4})\s
            (YR\.\s)?
            \(?(?<start_year>19\d{2})-
            (?<end_year>\d{2,4})\)?$
          }x,

          # 1919-1921
          %r{
            ^(?<start_year>19\d\d)-(?<end_year>\d{2,4})$
          }x,

          # 6630
          %r{
            ^(?<number>[2-9]\d\d\d)$
          }x

        ] # patterns
      end

      def self.sudoc_stem; end

      def self.oclcs
        [1_728_640]
      end

      def parse_ec(ec_string)
        # our match
        matchdata = nil

        ec_string.chomp!

        # useless junk
        ec_string.sub!(/^TN23 \. U43 /, '')

        @patterns.each do |p|
          break unless matchdata.nil?
          matchdata ||= p.match(ec_string)
        end

        unless matchdata.nil?
          ec = matchdata.named_captures
          ec.delete_if { |_k, v| v.nil? }
          if ec.key? 'end_year'
            ec['end_year'] = Series.calc_end_year(ec['start_year'], ec['end_year'])
            # we don't explode years so just stick it together
            ec['year'] = ec['start_year'] + '-' + ec['end_year']
          end

        end
        ec
      end

      def explode(ec, _src = nil)
        enum_chrons = {}
        return {} if ec.nil?

        ecs = []
        if ec['start_number']
          (ec['start_number']..ec['end_number']).each do |n|
            ecn = ec.clone
            ecn['number'] = n
            ecs << ecn
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

      def canonicalize(ec)
        # Number:8560
        canon = "Number:#{ec['number']}" if ec['number']
        canon
      end

      def self.load_context; end
      load_context
    end
  end
end
