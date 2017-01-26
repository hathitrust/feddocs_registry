require 'pp'
=begin
=end

module Registry
  module Series
    module MonthlyLaborReview
      #include EC
      class << self; attr_accessor :volumes end
      @volumes = {}

      def self.sudoc_stem
      end

      def self.oclcs 
        [5345258]
      end
      
      def self.parse_ec ec_string
        # our match
        m = nil

        v = 'V\.\s?(?<volume>\d{1,3})'
        n = 'NO\.\s?(?<number>\d{1,2})'
        ns = '(NOS?\.\s?)?(?<start_number>\d{1,2})[-\/](?<end_number>\d{1,2})'
        month = '(?<month>(JAN|FEB|MAR(CH)?|APR(IL)?|MAY|JUNE?|JULY?|AUG|SEPT?|OCT|NOV|DEC)\.?)'
        months = '(?<start_month>[A-Z]+\.?)\s?-(?<end_month>[A-Z]+\.?)'
        y = '[\(\s]('+months+'\s)?(?<year>\d{4})(:+'+month+'\s?)?\)?'
        div = '[\s:,;\/-]+\s?'

        patterns = [
        #canonical
        # Volume: 1, Number:5
        %r{
          ^Volume:(?<volume>\d+)(,\sNumber:(?<number>\d{1,2}))?$
        }x,
        # We would like a number, but not always going to get it
        # Volume: 1
        # Volume: 1, Index
        %r{
          ^Volume:(?<volume>\d+)(,\s(?<index>Index))?$
        }x,
        %r{
          ^Volume:(?<volume>\d+),\sNumber:(?<number>\d{1,2}),
          \sYear:(?<year>\d{4}),\sMonth:(?<month>[a-zA-Z]+)$
        }x,
        # V. 114 NO. 5-8 1991
        # V. 128NO. 10-12
        # V. 123:5-8 (MAY-AUG 2000)
        %r{
          ^#{v}(#{div}|NOS?\.\s?)+#{ns}(\s?#{y})?$
        }x,
        
        # V. 64 1947
        # V. 61 NO. 10 1977
        # V. 73:NO. 5(1951)
        # V. 46:INDEX (1938)
        # V. 38 INDEX
        # V. 127:NO. 3(2004:MAR. )
        %r{
          ^#{v}
          ((#{div})?#{n})?
          (#{div}(?<index>INDEX))?
          \s?(#{y})?$
        }x,
        # V. 101:9 (SEP 1978)
        %r{
          ^#{v}#{div}(?<number>\d{1,2})\s?\(#{month}#{y}\)$
        }x,
        # V. 128:5 (2005:MAY)
        %r{
          ^#{v}#{div}(?<number>\d{1,2})\s?
          #{y}#{div}(?<month>[A-Z]+)\)?$
        }x,
        # V. 129:9 2006 SEPT.
        # V. 123, NO. 2 2000 FEB. 2000 #wut?
        %r{
          ^#{v}#{div}(NO\.\s)?(?<number>\d{1,2})\s
          (?<year>\d{4})\s(?<month>[A-Z]+\.?)
          (\s\d{4})?$
        }x,
        # V. 113 1990 SEP-DEC
        #V. 49 1939:JULY-DEC
        %r{
          ^#{v}\s(?<year>\d{4})[\s:]
          (?<start_month>[A-Z]+)-(?<end_month>[A-Z]+)$
        }x,
        # V. 80 (1957:JAN. -JUNE)
        %r{
          ^#{v}[\s\(]+(?<year>\d{4}):+
          (?<start_month>[A-Z]+\.?)\s?-
          (?<end_month>[A-Z]+\.?)\s?\)?
        }x,
        # V. 129:NO. 1-3(2006:JAN. -MAR. )
        # V. 128:NO. 5-8 (2005:MAY-AUG. )
        # V. 127 NO. 1-3 2004 JAN-MAR
        # V. 125:NO. 1/6 (2002:JAN. /JUNE)
        %r{
          ^#{v}#{div}#{ns}\s?
          \(?(?<year>\d{4})[\s:]+
          (?<start_month>[A-Z]+\.?)#{div}
          (?<end_month>[A-Z]+\.?)\s?\)?$
        }x,
        # V. 118JULY-DEC
        # V. 22 JA-JE(1926)
        # V. 115 JAN. -JUN. 1992
        # V. 113,JUL-DEC 1990
        %r{
          ^#{v},?\s?#{months}
          (\s?\(?(?<year>\d{4})\)?)?$
        }x,
        # 101/1-6 (JAN-JUN 1978)
        %r{
          ^(?<volume>\d{1,3})#{div}
          (?<start_number>\d{1,2})-
          (?<end_number>\d{1,2})\s?
          \(?#{months}
          #{y}\)?$
        }x,
        #V. 94(1971NO. 7-12
        %r{
          ^#{v}
          \((?<year>\d{4})
          NO\.\s(?<start_number>\d{1,2})-
            (?<end_number>\d{1,2})\)$
        }x,
        # V. 84-93/INDEX 1961/1970
        %r{
          ^V\.\s?(?<start_volume>\d{1,3})[-\/]
          (?<end_volume>\d{1,3})[\s\/:]
          (?<index>INDEX)\s?
          (\(?(?<start_year>\d{4})[-\/]
          (?<end_year>\d{2,4})\)?\s?)?$
        }x,
        # V. 77:SUBJ. INDEX (1954)
        %r{
          ^#{v}[:\/\s]\s?
          (?<index>SUBJ.\sINDEX)\s?
          \((?<year>\d{4})\)$
        }x, 
        # V. 62-63 (1946)'
        %r{
          ^V\.\s(?<start_volume>\d{1,3})-
          (?<end_volume>\d{1,3})\s
          \((?<year>\d{4})\)$
        }x,
        # V. 72-83(INDEX)
        # V. 84-93 1961-70 INDEX
        %r{
          ^V\.\s?(?<start_volume>\d{1,3})[-\/]
          (?<end_volume>\d{1,3})\s?
          ((?<start_year>\d{4})-
          (?<end_year>\d{2,4})\s?)?
          :?\(?(?<index>INDEX)\)?$
        }x,
        # V. 72(INDEX)
        %r{
          ^#{v}\((?<index>INDEX)\)$
        }x,
        # INDEX:V. 52-71
        # INDEX V. 94-98 1971-1975
        %r{
          ^(?<index>INDEX):?\s?
          V\.\s?(?<start_volume>\d{1,3})[-\/]
          (?<end_volume>\d{1,3})
          (\s\(?(?<start_year>\d{4})[-\/]
          (?<end_year>\d{2,4})\)?)?$
        }x,

        ##98 1987
        #96 1973:JAN. -JUNE
        #119:1-6 1996
        %r{
          ^(?<volume>\d{1,3})
          (:\s?(?<start_number>\d{1,2})-(?<end_number>\d{1,2}))?
          \s?#{y}
          (:#{months})?$
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
            ec['end_year'] = calc_end_year(ec['start_year'], ec['end_year'])
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
          sm = MONTHS.index(lookup_month(ec['start_month']))
          em = MONTHS.index(lookup_month(ec['end_month']))
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
        if ec['volume'] 
          canon = "Volume:#{ec['volume']}"
          if !ec['index'] and !ec['year'] and self.volumes[ec['volume']]
            ec['year'] ||= self.volumes[ec['volume']]
          end
          if ec['number']
            canon += ", Number:#{ec['number']}"
            ec['month'] ||= MONTHS[ec['number'].to_i-1]
          end
          if ec['year']
            canon += ", Year:#{ec['year']}"
          end
          if ec['month']
            canon += ", Month:#{lookup_month(ec['month'])}"
          end
          if ec['index']
            canon += ", Index"
          end
        elsif ec['start_volume']
          canon = "Volumes:#{ec['start_volume']}-#{ec['end_volume']}"
          if ec['start_year']
            canon += ", Years:#{ec['start_year']}-#{ec['end_year']}"
          end
          if ec['index']
            canon += ", #{ec['index']}"
          end
        end
        canon
      end
 
      def self.load_context 
        vs = File.dirname(__FILE__)+'/data/mlr_volumes.tsv'
        open(vs).each do |line|
          volume, canon = line.chomp.split(/\t/)
          @volumes[volume] = canon
        end
      end
      self.load_context
    end
  end
end
