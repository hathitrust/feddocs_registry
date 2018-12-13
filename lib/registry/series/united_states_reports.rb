require 'pp'
require 'registry/series/default_series_handler'

module Registry
  module Series
    class UnitedStatesReports < DefaultSeriesHandler
      class << self; attr_accessor :volumes end
      @volumes = {}

      def self.sudoc_stem
        'JU 6.8'
      end

      def self.oclcs
        [10_648_533, 1_768_670]
      end

      def initialize
        super
        reporters = %w[DALLAS CRANCH WHEATON PETERS HOWARD BLACK WALLACE]
        v = 'V\.\s?(?<volume>\d+)'
        ot = '(?<october>OCT\.?\s(TERM)?)'
        y = '(YR\.\s)?(?<year>\d{4})'
        ys = '(?<start_year>\d{4})[/-](?<end_year>\d{2,4})'
        rpt = '(?<reporter>(' + reporters.join('|') + '))\s(?<number>\d{1,2})'

        @patterns = [
          # canonical
          # Volume: 1, Year:1982-1983, WALLACE 5, October Term
          %r{
            ^Volume:(?<volume>\d+)(,\sYears?:(#{ys}|(?<year>\d{4})))?
              (,\s#{rpt})?(,\s(?<october>October\sTerm))?$
            }x,
          %r{
            ^Volume:(?<volume>\d+),\sPart:(?<part>\d+)$
            }x,

          %r{
            ^#{v}\s?\(?(#{ot})?\s?(#{y}|#{ys})\)?$
            }x,
          %r{
            ^#{v}$
            }x,
          # V. 65 (HOWARD 24)
          %r{
            ^#{v}\s\(#{rpt}\)$
            }x,

          # just a number
          %r{
            ^(?<volume>\d+)$
            }x,

          # V. 203-214
          %r{
            ^V\.\s (?<start_volume>\d+)-(?<end_volume>\d+)\s?
            }x,

          # V. 556PT. 2
          %r{
            ^#{v}PT\.\s(?<part>\d)$
            }x,

          # V496PT1
          %r{
            ^V(?<volume>\d+)(PT(?<part>\d))?$
            }x,

          # V. 546:1
          %r{
            ^#{v}:(?<part>\d)$
            }x,

          # we'll just take the volume number
          %r{
            ^#{v}[,\s\(]
            }x
        ]
      end

      def parse_ec(ec_string)
        matchdata = nil

        @patterns.each do |p|
          break unless matchdata.nil?

          matchdata ||= p.match(ec_string)
        end

        unless matchdata.nil?
          ec = matchdata.named_captures
          ec.delete_if { |_k, v| v.nil? }
          if ec.key? 'end_year'
            ec['end_year'] = Series.calc_end_year(ec['start_year'], ec['end_year'])
          end

          # kill the zero fills
          if ec['volume']
            ec['volume'].sub!(/^0+/, '')
          elsif ec['start_volume']
            ec['start_volume'].sub!(/^0+/, '')
            ec['end_volume'].sub!(/^0+/, '')
          end
        end
        ec
      end

      def explode(ec, _src = nil)
        enum_chrons = {}
        return {} if ec.nil?

        ecs = []
        if ec['start_volume']
          (ec['start_volume']..ec['end_volume']).each { |v| ecs << { 'volume' => v } }
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
        if self.class.volumes.include? ec['volume']
          canon = self.class.volumes[ec['volume']]
        elsif ec['volume']
          canon = "Volume:#{ec['volume']}"
          canon += ", Part:#{ec['part']}" if ec['part']
          if ec['year']
            canon += ", Year:#{ec['year']}"
          elsif ec['start_year']
            canon += ", Years:#{ec['start_year']}-#{ec['end_year']}"
          end
          canon += ", #{ec['reporter']} #{ec['number']}" if ec['reporter']
        end
        canon
      end

      def self.load_context
        pairs = File.dirname(__FILE__) + '/data/usr_volumes.tsv'
        File.open(pairs).each do |line|
          volume, canon = line.chomp.split(/\t/)
          self.volumes[volume] = canon
        end
      end
      load_context
    end
  end
end
