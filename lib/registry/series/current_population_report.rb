# frozen_string_literal: true
require 'registry/series/default_series_handler'

module Registry
  module Series
    # Processing for Current Population Report series
    class CurrentPopulationReport < DefaultSeriesHandler
      def initialize
        super
        @title = 'Current Population Report'
        @patterns << /^#{@tokens[:y]}#{@tokens[:div]}(?<month>\d{1,2})$/xi
        @patterns << /^#{@tokens[:y]}\(?#{@tokens[:m]}\s\)?$/xi
        @patterns << %r{^#{@tokens[:y]}#{@tokens[:div]}
          (?<start_month>\d{1,2})#{@tokens[:div]}
          (?<end_month>\d{1,2})$}xi
        @patterns << %r{^#{@tokens[:y]}#{@tokens[:div]}\d{1,2}#{@tokens[:div]}
          \(?#{@tokens[:m]}\s?\)?$}xi
        @patterns << %r{^#{@tokens[:y]}
          \(?\s?(?<start_month>#{@tokens[:m]})#{@tokens[:div]}{1,2}
          (?<end_month>#{@tokens[:m]})\s?\)?
          (\s?#{@tokens[:y]})?$}xi
        @patterns << %r{^(?<start_month>#{@tokens[:m]})#{@tokens[:div]}{1,2}
          (?<end_month>#{@tokens[:m]})#{@tokens[:div]}
          #{@tokens[:y]}
          (\s#{@tokens[:pt]})?$}xi
        @patterns << /^(?<number>[1-9]\d{3})$/
        @patterns << /^(NO\.\s)?(?<start_number>\d{1,4})-(?<end_number>\d{3,4})$/
      end

      def self.sudoc_stem; end

      def self.oclcs
        [6_432_855, 623_448_621]
      end

      def preprocess(ec_string)
        ec_string.sub!(/^C. 1 /, '')
        ec_string.sub!(/ C. 1$/, '')
        ec_string.sub!(/^.*P-28[\/\s]/, '')
        ec_string.sub!(/#{@tokens[:div]}C. [12]$/, '')
        ec_string = '1' + ec_string if ec_string =~ /^9\d\d/
        # V. 1977:MAY-JUNE
        ec_string.sub!(/^V. ([12]\d{3})/, '\1')
        ec_string
      end

      def parse_ec(ec_string)
        # our match
        matchdata = nil

        ec_string = preprocess(ec_string).chomp

        @patterns.each do |p|
          break unless matchdata.nil?

          matchdata ||= p.match(ec_string)
        end

        unless matchdata.nil?
          ec = matchdata.named_captures
          ec = Series.fix_months(ec)
        end
      end

      def explode(ec, _src = nil)
        enum_chrons = {}
        return {} if ec.nil?

        ecs = []
        if ec['start_number']
          (ec['start_number']..ec['end_number']).each do |num|
            copy = ec.clone
            copy['number'] = num
            ecs << copy
          end
        else
          ecs << ec
        end

        ecs.each do |ec|
          if (canon = canonicalize(ec))
            ec['canon'] = canon
            enum_chrons[ec['canon']] = ec.clone
          end
        end
        enum_chrons
      end

      def canonicalize(ec)
        # default order is:
        t_order = %w[year month start_month end_month volume part number book sheet]
        canon = t_order.reject { |t| ec[t].nil? }
                       .collect { |t| t.to_s.tr('_', ' ').capitalize + ':' + ec[t] }
                       .join(', ')
        canon = nil if canon == ''
        canon
      end
    end
  end
end
