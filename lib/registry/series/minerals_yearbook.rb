require 'pp'
=begin
=end

module Registry
  module Series
    module MineralsYearbook
      #class << self; attr_accessor :volumes end
      #@volumes = {}


      def self.sudoc_stem
      end

      def self.oclcs 
        [1847412, 228509857]
      end
      
      def self.parse_ec ec_string
        # our match
        m = nil

        # fix 3 digit years
        if ec_string =~ /^9\d\d[^0-9]*/
          ec_string = '1'+ec_string
        end

        # useless junk
        ec_string.sub!(/^TN23 \. U612 /, '') 

        #tokens
        y = '(YR\.\s)?(?<year>\d{4})'
        v = 'V\.?\s?(?<volume>\d)'
        vs = '(?<start_volume>\d)[-\/](?<end_volume>\d)'
        ps = '(?<start_part>\d)[-\/](?<end_part>\d)'
        div = '[\s:,;\/-]+\s?\(?'
        p = 'PT\.?\s?(?<part>\d{1})'
        ys = '(?<start_year>\d{4})[-\/](?<end_year>\d{2,4})'
        ar = '(AREA\sREPORTS:)?'
        area = '(\(?(?<description>(AREA\s?RE?PO?R?TS:)?([A-Z]|\/|\s|\.|,)+)(\s\d{4})?\)?)'
        app = '(?<appendix>APP(END)?I?X?\.?)'

        patterns = [
        #canonical
        # Volume: 1, Number:5
        %r{
          ^Volume:(?<volume>\d+)(,\sNumber:(?<number>\d{1,2}))?$
        }x,

        #simple year
        %r{
          ^#{y}$
        }x,

        # 1982 (V. 1)
        %r{
          ^#{y}(#{div})?\(#{v}
          (#{div}#{area})?\)$
        }x,

        # V. 3(1956) 
        %r{
          ^#{v}\(#{y}\)$
        }x,

        # V. 1-2(1968)
        %r{
          ^V\.\s#{vs}\(#{y}\)$
        }x,

        # 1934 APPENDIX
        %r{
          ^#{y}#{div}
          #{app}$
        }x,

        # 2009:3:1- AREA REPORTS: AFRICA AND THE MIDDLE EAST
        %r{
          ^#{y}:(?<volume>\d):(?<part>\d)\s?-\s?
          #{area}$
        }x,

        # 981/V. 2
        # 1908V. 1
        # 2006:V. 3:LATIN AMERICA/CANADA
        # 2006:V. 2(DOMESTIC)
        %r{
          ^#{y}(#{div})?#{v}
          ((#{div})?#{area}?)?$
        }x,

        # 1955:3 #assume volume
        # 2005:2 - AREA REPORTS: DOMESTIC
        %r{
          ^#{y}#{div}(?<volume>\d)
          (\s?-\s?#{area})?$
        }x,

        #989:V. 3:1
        %r{
          ^#{y}#{div}#{v}#{div}
          (?<part>\d)$
        }x,

        # 1968 V. 1-2
        # 1969 (V. 1-2)
        %r{
          ^#{y}#{div}
          \(?(V\.\s?)?#{vs}\)?$
        }x,

        # V. 3(2008:EUROPE/CENTRAL EURASIA)
        %r{
          ^#{v}\((?<year>\d{4}):
          #{area}\)$
        }x,
        
        # V. 32006:LATIN AMERICA/CANADA
        %r{
          ^#{v}(?<year>\d{4})
         (#{div}#{area})$
        }x,

        # MIDDLE EAST1989:V. 3
        %r{
          ^#{area}(?<year>\d{4})#{div}#{v}$
        }x,

        # 1910:PT. 1 
        %r{
          ^#{y}(#{div})?#{p}
          (#{div}#{area})?$
        }x,

        #993-94/V. 2 
        %r{
          ^#{ys}(#{div}#{v}
                 (#{div}#{area})?)?$
        }x,

        # 1996:V. 3:PT. 2/3
        %r{
          ^#{y}#{div}#{v}#{div}PT\.\s#{ps}$
        }x,

        # 995:V. 2 1995, V. 2
        %r{
          ^#{y}#{div}#{v}#{div}
          #{y}(, #{v})$
        }x,

        # 2007 V. 3 PT. 3  
        # 1989V. 3PT. 5
        %r{
          ^#{y}(#{div})?#{v}(#{div})?#{p}
          (#{div}#{area})?$
        }x
        ] # patterns

        patterns.each do |p|
          if !m.nil?
            break
          end
          m ||= p.match(ec_string)
        end 


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
        if ec['start_number']
          (ec['start_number']..ec['end_number']).each do | n |
            ecn = ec.clone
            ecn['number'] = n
            ecs << ecn
          end
        elsif ec['start_month']
          sm = MONTHS.index(Series.lookup_month(ec['start_month']))
          em = MONTHS.index(Series.lookup_month(ec['end_month']))
          (sm..em).each do |n|
            ecn = ec.clone
            ecn['number'] = n+1
            ecn['month'] = MONTHS[n]
            ecs << ecn
          end
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
        # don't think we actually want to do this
        #if self.volumes.include? ec['volume']
        #  canon = self.volumes[ec['volume']]
        nil
      end
 
      def self.load_context 
      end
      self.load_context
    end
  end
end
