# frozen_string_literal: true
require 'pp'
require 'registry/series/default_series_handler'

module Registry
  module Series
    # Processing for Census of Manufactures series
    class CensusOfManufactures < DefaultSeriesHandler

      def self.sudoc_stem; end

      def self.oclcs
        [2_842_584, 623_028_861]
      end

      def self.title
        'Census of Manufactures'
      end

      def initialize 
        super
      end

      def preprocess(ec_string)
        ec_string = '1' + ec_string if ec_string =~ /^9\d\d/
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

        matchdata&.named_captures
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

        ecs = [ec]

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
        canon << "Volume:#{ec['volume']}" if ec['volume']
        canon << "Part:#{ec['part']}" if ec['part']
        canon << "Number:#{ec['number']}" if ec['number']
        if ec['start_number'] && !ec['number']
          start_num = ec['start_number'].to_i.to_s
          end_num = ec['end_number'].to_i.to_s
          canon << "Numbers:#{start_num}-#{end_num}"
        end
        canon << "Year:#{ec['year']}" if ec['year']
        canon << "Month:#{ec['month']}" if ec['month']
        if ec['start_month'] && !ec['month']
          canon << "Months:#{ec['start_month']}-#{ec['end_month']}"
        end
        canon.join(', ') unless canon.empty?
      end
    end
  end
end
