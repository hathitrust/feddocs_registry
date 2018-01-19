# frozen_string_literal: true

require 'pp'

module Registry
  module Series
    module UnitedStatesReports
      include Registry::Series
      @@volumes = {}

      def self.sudoc_stem
        'JU 6.8'
      end

      def self.oclcs
        [10_648_533, 1_768_670]
      end

      def parse_ec(ec_string)
        reporters = %w[DALLAS CRANCH WHEATON PETERS HOWARD BLACK WALLACE]
        v = 'V\.\s?(?<volume>\d+)'
        ot = '(?<october>OCT\.? (TERM)?)'
        y = '(YR\.\s)?(?<year>\d{4})'
        ys = '(?<start_year>\d{4})[/-](?<end_year>\d{2,4})'
        rpt = '(?<reporter>(' + reporters.join('|') + ')) (?<number>\d{1,2})'

        # canonical
        # Volume: 1, Year:1982-1983, WALLACE 5, October Term
        m ||= /^Volume:(?<volume>\d+)(, Years?:(#{ys}|(?<year>\d{4})))?(, #{rpt})?(, (?<october>October Term))?$/.match(ec_string)
        m ||= /^Volume:(?<volume>\d+), Part:(?<part>\d+)$/.match(ec_string)

        m ||= /^#{v} ?\(?(#{ot})? ?(#{y}|#{ys})\)?$/.match(ec_string)
        m ||= /^#{v}$/.match(ec_string)
        # V. 65 (HOWARD 24)
        m ||= /^#{v} \(#{rpt}\)$/.match(ec_string)

        # just a number
        m ||= /^(?<volume>\d+)$/.match(ec_string)

        # V. 203-214
        m ||= /^V\. (?<start_volume>\d+)-(?<end_volume>\d+) ?/.match(ec_string)

        # V. 556PT. 2
        m ||= /^#{v}PT\. (?<part>\d)$/.match(ec_string)

        # V496PT1
        m ||= /^V(?<volume>\d+)(PT(?<part>\d))?$/.match(ec_string)

        # V. 546:1
        m ||= /^#{v}:(?<part>\d)$/.match(ec_string)

        # we'll just take the volume number
        m ||= /^#{v}[, \(]/.match(ec_string)

        unless m.nil?
          ec = Hash[m.names.zip(m.captures)]
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
          if canon = canonicalize(ec)
            ec['canon'] = canon
            enum_chrons[ec['canon']] = ec.clone
          end
        end

        enum_chrons
      end

      def canonicalize(ec)
        if @@volumes.include? ec['volume']
          canon = @@volumes[ec['volume']]
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
        open(pairs).each do |line|
          volume, canon = line.chomp.split(/\t/)
          @@volumes[volume] = canon
        end
      end
      load_context
    end
  end
end
