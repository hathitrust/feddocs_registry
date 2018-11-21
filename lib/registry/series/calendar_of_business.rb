# frozen_string_literal: true

require 'pp'

module Registry
  module Series
    # Processing for Calendar of Business series
    module CalendarOfBusiness
      class << self
        attr_accessor :patterns
        attr_accessor :tokens
      end
      # @volumes = {}

      @tokens = Series.tokens
      @patterns = Series.patterns.clone
      @patterns << /^#{@tokens[:y]}\/(?<number>\d{1,3})$/xi

      def self.sudoc_stem; end

      def self.oclcs
        [30_003_375,
         1_768_284,
         41_867_070]
      end

      def self.title
        'Calendar of Business'
      end

      #       def preprocess(ec_string)
      #         ec_string.sub!(/^C. 1 /, '')
      #         ec_string.sub!(/ C. 1$/, '')
      #         ec_string.sub!(/^.*P-28[\/\s]/, '')
      #         ec_string.sub!(/#{Series.tokens[:div]}C. [12]$/, '')
      #         ec_string = '1' + ec_string if ec_string =~ /^9\d\d/
      #         # V. 1977:MAY-JUNE
      #         ec_string.sub!(/^V. ([12]\d{3})/, '\1')
      #         ec_string
      #       end

      def parse_ec(ec_string)
        matchdata = nil

        # fix 3 digit years, this is more restrictive than most series specific
        # work.
        ec_string = '1' + ec_string if ec_string.match?(/^9\d\d$/)

        CalendarOfBusiness.patterns.each do |p|
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
