# frozen_string_literal: true
require 'pp'
require 'registry/series/default_series_handler'

module Registry
  module Series
    # Processing for Public Health Reports series
    class PublicHealthReports < DefaultSeriesHandler

      def self.sudoc_stem; end

      def self.oclcs
        [48_450_485, 1_007_653, 181_336_288, 1_799_423]
      end

      def self.title
        'Public Health Reports'
      end

      def initialize
        super
        @tokens = {
          v: 'V(\.|olume)[:\s]?(?<volume>\d{1,3})',
          n: 'N(O\.|umber)[:|\s](?<number>\d{1,3})',
          y: '\(?(Y(ea)?r[:\.]\s?)?(?<year>\d{4})(\s\(?\k<year>\)?)?\)?',
          ns: 'N(OS?\.\s|umbers:)(?<start_number>\d{1,3})-(?<end_number>\d{1,3})',
          month: '(Month:)?(?<month>[A-z]+\.?)',
          months: '(MO\.\s)?(?<start_month>[A-z]+\.?)\s?(\d{1,2}\s?)?(-|/)(?<end_month>[A-z]+\.?)(\s\d{1,2})?\s?',
          div: '[\s:,;\/-]+\s?\(?',
          pages: 'P?P\.\s(?<start_page>\d{1,4})-(?<end_page>\d{1,4})',
          pt: 'P(art|T\.?)?[:\s]?(?<part>\w{1,2})'
        }

        @patterns = [
          # canonical
          # Volume
          # Part
          # Number
          # Year
          # Month or Months
          %r{^(#{@tokens[:v]}|#{@tokens[:n]})
          (,?\s#{@tokens[:pt]})?
          (,?\s#{@tokens[:n]})?
          (,?\s#{@tokens[:y]})?
          (,?\s#{@tokens[:month]})?
          (,?\s#{@tokens[:months]})?
          $}xi,

          # V. 22:PT. 1(1907)
          %r{^#{@tokens[:v]}#{@tokens[:div]}
            #{@tokens[:pt]}(#{@tokens[:div]})?
            #{@tokens[:y]}
          $}xi,

          # 83/PT. 1
          %r{^(?<volume>\d{1,3})#{@tokens[:div]}
            #{@tokens[:pt]}
          $}xi,

          # V. 59 NO. 27-52 1944
          # V. 24,PT. 1,NO. 1-26 1909
          # V. 63:PT. 1:NO. 1-26(1948:JAN. -JUNE)
          # V. 60 PT. 1 NO. 01-26 YR. 1945
          # V. 13:NO. 46(1898:NOV. 18)
          # V. 54 PT. 1 NO. 01-26 YR. 1939 MO. JAN. -JUNE
          %r{^#{@tokens[:v]}#{@tokens[:div]}
              (#{@tokens[:pt]}#{@tokens[:div]})?
              ((#{@tokens[:ns]}|#{@tokens[:n]})(#{@tokens[:div]})?)?
              #{@tokens[:y]}
              (#{@tokens[:div]}
                (#{@tokens[:months]}|#{@tokens[:month]})
              \)?)?
              (#{@tokens[:div]}(?<day>\d{1,2})\)?)?
          $}xi,

          %r{^#{@tokens[:v]}#{@tokens[:div]}
              #{@tokens[:pt]}#{@tokens[:div]}
              #{@tokens[:ns]}#{@tokens[:div]}
              #{@tokens[:y]}
              #{@tokens[:div]}#{@tokens[:months]}
          $}xi,

          # V. 55/PT. 2
          %r{^#{@tokens[:v]}#{@tokens[:div]}
             #{@tokens[:pt]}
          $}xi,

          # V. 82 1967 JUL-DEC
          %r{^#{@tokens[:v]}#{@tokens[:div]}
              #{@tokens[:y]}#{@tokens[:div]}
              #{@tokens[:months]}
          $}xi,

          # V. 112 1997 NO. 1-3
          %r{^#{@tokens[:v]}#{@tokens[:div]}
              #{@tokens[:y]}#{@tokens[:div]}
              #{@tokens[:ns]}
          $}xi,

          # V. 104:NO. 3(1989:MAY/JUNE)
          %r{^#{@tokens[:v]}#{@tokens[:div]}
              #{@tokens[:n]}
              #{@tokens[:y]}#{@tokens[:div]}#{@tokens[:months]}\)
          $}xi,

          # V. 13:NO. 23(1898:JUNE 10)
          %r{^#{@tokens[:v]}#{@tokens[:div]}
              #{@tokens[:n]}
              #{@tokens[:y]}#{@tokens[:div]}
              #{@tokens[:month]}#{@tokens[:div]}
              (?<day>\d{1,2})\)
          $}xi,

          # V. 47:14-26 (APR-JUNE 1932)
          %r{^#{@tokens[:v]}#{@tokens[:div]}
              (?<start_number>\d+)-(?<end_number>\d+)
              #{@tokens[:div]}
              #{@tokens[:months]}#{@tokens[:div]}
              #{@tokens[:y]}
          $}xi,

          # V. 105(1990)
          %r{^#{@tokens[:v]}
             #{@tokens[:y]}
          $}xi,

          # V. 84 JUL-DEC 1969
          %r{^#{@tokens[:v]}#{@tokens[:div]}
              #{@tokens[:months]}#{@tokens[:div]}
              #{@tokens[:y]}
          $}xi,

          # V. 21:1(1906)
          %r{#{@tokens[:v]}#{@tokens[:div]}
             (?<part>[1-2])
             #{@tokens[:y]}
          $}xi,

          # V. 66 PT. 2 (JULY-DEC. 1951)
          %r{#{@tokens[:v]}#{@tokens[:div]}
             #{@tokens[:pt]}#{@tokens[:div]}
             \(#{@tokens[:months]}#{@tokens[:div]}
             #{@tokens[:y]}
          $}xi,

          # 119 2004
          %r{^(?<volume>\d{1,3})
              (#{@tokens[:div]}#{@tokens[:y]})?
          $}xi

        ] # patterns
      end

      def preprocess(ec_string)
        ec_string.sub(/^C\. 1 /, '')
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
        ec = Series.fix_months(ec)
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

      def self.load_context; end
      load_context
    end
  end
end
