# frozen_string_literal: true
require 'registry/series/default_series_handler'

module Registry
  module Series
    # Processing for Calendar of Business series
    class CalendarOfBusiness < DefaultSeriesHandler
      
      def initialize
        super
        @patterns << /^#{@tokens[:y]}\/(?<number>\d{1,3})$/xi
        @title = 'Calendar of Business'
      end

      

      def self.oclcs
        [30_003_375,
         1_768_284,
         41_867_070]
      end

      def parse_ec(ec_string)
        matchdata = nil

        # fix 3 digit years, this is more restrictive than most series specific
        # work.
        ec_string = '1' + ec_string if ec_string.match?(/^9\d\d$/)

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

          # year unlikely. Probably don't know what we think we know.
          # From the regex, year can't be < 1800
          ec = nil if ec['year'].to_i > (Time.now.year + 5)
        end
        ec
      end

      def explode(ec, _src = nil)
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

      def canonicalize(ec)
        t_order = %w[year number month day]
        canon = t_order.reject { |t| ec[t].nil? }
                       .collect { |t| t.to_s.tr('_', ' ').capitalize + ':' + ec[t] }
                       .join(', ')
        canon = nil if canon == ''
        canon
      end
    end
  end
end
