# frozen_string_literal: true

require 'pp'

module Registry
  module Series
    # Processing for War of the Rebellion series
    module WarOfTheRebellion
      class << self
        attr_accessor :patterns
        attr_accessor :tokens
      end
      # @volumes = {}

      def self.sudoc_stem; end

      def self.oclcs
        [427_057, 471_419_901]
      end

      def self.title
        'War Of The Rebellion'
      end

      # TODO: move into Series and make it less stupid
      def deromanize(num)
        if num == 'I'
          '1'
        elsif num == 'II'
          '2'
        elsif num == 'III'
          '3'
        elsif num == 'IV'
          '4'
        else
          num
        end
      end

      @tokens = {
        div: '[\s:,;\/-]+\s?\(?',
        n: 'N(O\.|umber)[:|\s](?<number>\d{1,3})',
        v: 'V(\.|olume)[:\s]?(?<volume>\d{1,3})',
        pt: '(P(art|T\.?)|SECTION)?[:\s]?(?<part>\w{1,2})',
        s: 'SER(IES|\.)?[:\s](?<series>\d+)',
        y: '\(?(Y(ea)?r[:\.]\s?)?(?<year>\d{4})(\s\(?\k<year>\)?)?\)?',
        r_or_s: '(?<r_or_s>(REPORTS|CORRESPONDENC))'
      }

      @patterns = [
        # canonical
        # also V. SERIES 1/V. 34/PT. 3/1891
        %r{^
          #{@tokens[:s]}
          (#{@tokens[:div]}#{@tokens[:v]})?
          (#{@tokens[:div]}#{@tokens[:pt]})?
          (#{@tokens[:div]}#{@tokens[:n]})?
          (#{@tokens[:div]}(?<year>1[8-9]\d\d))?
          (#{@tokens[:div]}#{@tokens[:r_or_s]}.*)?
        $}xi,

        # 99 (SERIES 1 V. 47 PT. 1)
        # 122 (SERIES 3 V. 1)
        # numbers should be in the 1 to 130ish range.
        %r{^
          (?<number>1?[0-9]{1,2})#{@tokens[:div]}
          #{@tokens[:s]}#{@tokens[:div]}
          #{@tokens[:v]}
          (#{@tokens[:div]}#{@tokens[:pt]})?
          \)?
        $}xi,

        # 1/46/ PT. 1
        # 1/17
        # we will accept series 1 or 2 and a 1 or 2 digit volume number
        %r{^
          (?<series>[1-2])\/
          (?<volume>[0-9]{1,2})
          (#{@tokens[:div]}#{@tokens[:pt]})?
        $}xi,

        # 3004 (SERIES 1 V. 40 PT. 1)
        # Fairly certain 3004 is a serial set number which we don't care about
        # right now
        %r{^
          (?<serial_set>[2-3][0-9]{3})#{@tokens[:div]}
          #{@tokens[:s]}#{@tokens[:div]}
          #{@tokens[:v]}
          (#{@tokens[:div]}#{@tokens[:pt]})?
          \)?
        $}xi,

        # I/26-1
        %r{^
          (?<series>I+V?)\/
          (?<volume>[0-9]{1,2})
          (-(?<part>\d))?
        $}xi,

        # V. 40,PT. 2 (SERIES 1)
        # V. 27,PT. 1
        %r{^
          #{@tokens[:v]}
          (#{@tokens[:div]}#{@tokens[:pt]})?
          (#{@tokens[:div]}#{@tokens[:s]}\))?
        $}xi,

        # SERIES 1 (V. 17,PT. 1)
        # SERIES 1 (V. 18)
        %r{^
          #{@tokens[:s]}#{@tokens[:div]}
          #{@tokens[:v]}
          (#{@tokens[:div]}#{@tokens[:pt]})?\)
        $}xi,

        # Might as well guess if it's just a one to three digit number
        %r{^
          (?<number>1?[0-9]{1,2})
        $}xi
      ]

      def parse_ec(ec_string)
        # our match
        m = nil

        ec_string = preprocess(ec_string)

        WarOfTheRebellion.patterns.each do |p|
          break unless m.nil?

          m ||= p.match(ec_string)
        end

        m&.named_captures
      end

      def preprocess(ec_string)
        ec_string.chomp
                 .sub(/^C\.\s\d+\s/, '')
                 .sub(/\sC\.\s\d+$/, '')
                 .sub(/^V\. ([^0-9])/, '\1')
      end

      def explode(ec, _rec = nil)
        enum_chrons = {}
        return {} if ec.nil?

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
        canon << "Series:#{deromanize(ec['series']).to_i}" if ec['series']
        canon << "Volume:#{ec['volume'].to_i}" if ec['volume']
        canon << "Part:#{ec['part'].to_i}" if ec['part']
        canon.join(', ') unless canon.empty?
      end
    end
  end
end
