# frozen_string_literal: true
require 'pp'
require 'registry/series/default_series_handler'

module Registry
  module Series
    # Processing for Department of Agriculture Leaflet series
    class DepartmentOfAgricultureLeaflet < DefaultSeriesHandler
      

      def self.oclcs
        [1_432_804, 34_452_947, 567_905_741, 608_882_398]
      end

      def initialize
        super
        @title = 'Department of Agriculture Leaflet'
        @tokens = {
          v: 'V(\.|olume)[:\s](?<volume>\d{1,3})',
          n: 'N(O\.|umber)[:|\s](?<number>\d{1,3})',
          y: '\(?(Year:)?(?<year>\d{4})\)?',
          r: '(?<rev>Rev(\.|ision))([:\s](?<rev_num>\d{1,2}))?',
          ns: 'N(O\.\s|umbers:)(?<start_number>\d{1,3})-(?<end_number>\d{1,3})',
          mon: 'Month:(?<month>[A-z]+)',
          div: '[\s:,;\/-]+\s?\(?',
          pages: 'P?P\.\s(?<start_page>\d{1,4})-(?<end_page>\d{1,4})'
        }

        @patterns = [
          # canonical
          # Number:407, Year:1976, Revision
          # Number:219, Year:1970, Revision:7
          # NO. 533
          # Number:219
          # NO. 226 (1942)
          # NO. 268/5 (1969)
          %r{
            ^#{@tokens[:n]}
            (\/(?<rev_num>\d{1,2}))?
            (,?\s#{@tokens[:y]})?
            (,?\s#{@tokens[:r]})?$
          }xi,

          # NO. 130 REV. 3 (1940)
          %r{
            ^#{@tokens[:n]}
            \s#{@tokens[:r]}
            \s#{@tokens[:y]}$
          }xi,

          # NO. 187 (1977 REV. )
          # NO. 244 (1959:REV. )
          %r{
            ^#{@tokens[:n]}
            \s\(#{@tokens[:y]}
            [\s:]#{@tokens[:r]}\s?\)$
          }xi,

          # NO. 547/2 (REV. 1970)
          # NO. 407REV 1976
          # NO. 437REV
          # NO. 527:REV. (1972)
          %r{
            ^#{@tokens[:n]}
            :?(\/(?<rev_num>\d{1,2}))?
            \s?\(?(?<rev>REV\.?)
            (\s#{@tokens[:y]})?$
          }xi,

          # NO. 201-250
          # NO. 201-250 (1940-49)
          # NO. 201-250 (1949)
          # NO. 201-250 1940-49
          %r{
            ^#{@tokens[:ns]}
            (\s\(?\d{4}(-\d{2,4})?\)?)?$
          }xi,

          # 550 1969
          %r{
            ^(?<number>\d{3})
            \s(?<year>\d{4})$
          }xi,

          # simple year
          %r{
            ^#{@tokens[:y]}$
          }x
        ] # patterns
      end

      def parse_ec(ec_string)
        # our match
        matchdata = nil

        ec_string.chomp!

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
        canon << "Number:#{ec['number']}" if ec['number']
        canon << "Year:#{ec['year']}" if ec['year']
        canon << 'Revision' if ec['rev'] && !ec['rev_num']
        canon << "Revision:#{ec['rev_num']}" if ec['rev_num']
        canon.join(', ') unless canon.empty?
      end

      def self.load_context; end
      load_context
    end
  end
end
