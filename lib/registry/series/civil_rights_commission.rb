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
      
      def self.parse_ec ec_string
        #our match
        m = nil
      end


      # Take a parsed enumchron and expand it into its constituent parts
      # enum_chrons - { <canonical ec string> : {<parsed features>}, }
      #
      # 
      def self.explode( ec, src=nil )
        enum_chrons = {} 
        enum_chrons
      end

      def self.canonicalize ec
        canon
      end

      def self.load_context 
      end
      self.load_context
    end
  end
end
