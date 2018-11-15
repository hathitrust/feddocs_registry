# frozen_string_literal: true

require 'pp'

module Registry
  module Series
    # Processing for Public Health Report Supplements series
    module PublicHealthReportSupplements
      class << self
        attr_accessor :patterns
        attr_accessor :tokens
      end
      # @volumes = {}

      puts Series.tokens
      @tokens = Series.tokens
      #       @patterns = Series.patterns.clone
      #       @patterns.delete(/^(YEAR:)?\[?(?<year>(1[8-9]|20)\d{2})\.?\]?$/ix)
      #       @patterns << /^#{@tokens[:y]}#{@tokens[:div]}(?<month>\d{1,2})$/xi
      #       @patterns << /^#{@tokens[:y]}\(?#{@tokens[:m]}\s\)?$/xi
      #       @patterns << %r{^#{@tokens[:y]}#{@tokens[:div]}
      #         (?<start_month>\d{1,2})#{@tokens[:div]}
      #         (?<end_month>\d{1,2})$}xi
      #       @patterns << %r{^#{@tokens[:y]}#{@tokens[:div]}\d{1,2}#{@tokens[:div]}
      #         \(?#{@tokens[:m]}\s?\)?$}xi
      #       @patterns << %r{^#{@tokens[:y]}
      #         \(?\s?(?<start_month>#{@tokens[:m]})#{@tokens[:div]}{1,2}
      #         (?<end_month>#{@tokens[:m]})\s?\)?
      #         (\s?#{@tokens[:y]})?$}xi
      #       @patterns << %r{^(?<start_month>#{@tokens[:m]})#{@tokens[:div]}{1,2}
      #         (?<end_month>#{@tokens[:m]})#{@tokens[:div]}
      #         #{@tokens[:y]}
      #         (\s#{@tokens[:pt]})?$}xi
      #       @patterns << /^(?<number>[1-9]\d{3})$/
      #       @patterns << /^(NO\.\s)?(?<start_number>\d{1,4})-(?<end_number>\d{3,4})$/
      def self.sudoc_stem; end

      def self.oclcs
        [29_651_249, 491_280_576]
      end

      def self.title
        'Public Health Report Supplements'
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
        Series.parse_ec(ec_string)
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
        t_order = %w[volume number part year]
        canon = t_order.reject { |t| ec[t].nil? }
                       .collect { |t| t.to_s.tr('_', ' ').capitalize + ':' + ec[t] }
                       .join(', ')
        canon = nil if canon == ''
        canon
      end
    end
  end
end
