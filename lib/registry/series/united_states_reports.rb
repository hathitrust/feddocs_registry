require 'pp'
=begin
=end

module Registry
  module Series
    module UnitedStatesReports
      include Registry::Series
      class << self; attr_accessor :volumes end
      @volumes = {}

      def self.sudoc_stem
        'JU 6.8'
      end

      def self.oclcs 
        [10648533, 1768670]
      end
      
      def self.parse_ec ec_string
        reporters = ['DALLAS','CRANCH','WHEATON','PETERS','HOWARD','BLACK','WALLACE']
        v = 'V\.\s?(?<volume>\d+)'
        ot = '(?<october>OCT\.? (TERM)?)'
        y = '(YR\.\s)?(?<year>\d{4})'
        ys = '(?<start_year>\d{4})[/-](?<end_year>\d{2,4})'
        rpt = '(?<reporter>('+reporters.join('|')+')) (?<number>\d{1,2})'

        #canonical
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

        #we'll just take the volume number
        m ||= /^#{v}[, \(]/.match(ec_string)

        if !m.nil?
          ec = Hash[ m.names.zip( m.captures ) ]
          ec.delete_if {|k, v| v.nil? }
          if ec.key? 'end_year'
            ec['end_year'] = Series.calc_end_year(ec['start_year'], ec['end_year'])
          end

          #kill the zero fills
          if ec['volume'] 
            ec['volume'].sub!(/^0+/, '')
          elsif ec['start_volume']
            ec['start_volume'].sub!(/^0+/, '')
            ec['end_volume'].sub!(/^0+/, '')
          end
        end
        ec
      end

      def self.explode(ec, src=nil)
        enum_chrons = {} 
        if ec.nil?
          return {}
        end

        ecs = []
        if ec['start_volume']
          (ec['start_volume']..ec['end_volume']).each {|v| ecs << {"volume"=>v}}
        else
          ecs << ec
        end

        ecs.each do | ec |
          if canon = self.canonicalize(ec)
            ec['canon'] = canon 
            enum_chrons[ec['canon']] = ec.clone
          end
        end
         
        enum_chrons
      end

      def self.canonicalize ec
        if self.volumes.include? ec['volume']
          canon = self.volumes[ec['volume']]
        elsif ec['volume'] 
          canon = "Volume:#{ec['volume']}"
          if ec['part']
            canon += ", Part:#{ec['part']}"
          end
          if ec['year']
            canon += ", Year:#{ec['year']}"
          elsif ec['start_year']
            canon += ", Years:#{ec['start_year']}-#{ec['end_year']}"
          end
          if ec['reporter']
            canon += ", #{ec['reporter']} #{ec['number']}"
          end
        end
        canon
      end
 
      def self.load_context 
        pairs = File.dirname(__FILE__)+'/data/usr_volumes.tsv'
        open(pairs).each do |line|
          volume, canon = line.chomp.split(/\t/)
          @volumes[volume] = canon
        end
      end
      self.load_context
    end
  end
end
