require 'pp'
=begin
  Does nothing. Just filler.
=end

module Registry
  module Series
    module CivilRightsCommission
      def self.sudoc_stem
        'CR'
      end

      def self.oclcs
      end

      def parse_ec(ec_string)
        # our match
        m = nil
      end

      # Take a parsed enumchron and expand it into its constituent parts
      # enum_chrons - { <canonical ec string> : {<parsed features>}, }
      #
      #
      def explode(ec, src = nil)
        enum_chrons = {}
        enum_chrons
      end

      def canonicalize(ec)
        nil
      end

      def self.load_context
      end
      load_context
    end
  end
end
