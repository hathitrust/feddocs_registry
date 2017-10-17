require 'pp'
=begin
=end

module Registry
  module Series
    module JournalOfTheNationalCancerInstitute
      #class << self; attr_accessor :volumes end
      #@volumes = {}


      def self.sudoc_stem
      end

      def self.oclcs 
        [1064763, 36542869, 173847259, 21986096]
      end
      
      def parse_ec ec_string
        # our match
        m = nil

        ec_string.chomp!

        ec_string = self.remove_dupe_years ec_string
        ec_string.gsub!(/^C\. \d /,'')

        #tokens
        v = 'V(\.|olume)[:\s](?<volume>\d{1,3})'
        n = 'Number:(?<number>\d{1,2})'
        ns = 'Numbers:(?<start_number>\d{1,2})-(?<end_number>\d{1,2})'
        y = 'Year:(?<year>\d{4})'
        mon = 'Month:(?<month>[A-z]+)'
        div = '[\s:,;\/-]+\s?\(?'
        month = '(?<month>(JAN|FEB|MAR(CH)?|APR(IL)?|MAY|JUNE?|JULY?|AUG|SEPT?|OCT|NOV|DEC)\.?)'
        months = '(?<start_month>[A-z]+\.?)\s?(\d{1,2}\s?)?(-|/)(?<end_month>[A-z]+\.?)(\s\d{1,2})?'
        pages = 'P?P\.\s(?<start_page>\d{1,4})-(?<end_page>\d{1,4})'


        patterns = [
        #canonical
        # Volume:99, Number:7, Year:1997
        # V. 1
        # Volume:32, Numbers:4-6, Year:1964
        # Volume:10, Years:1964-1965
        %r{
          ^#{v}
          (,\s#{n})?
          (,\s#{ns})?
          (,\s#{y})?
          (,\sYears:(?<start_year>\d{4})-(?<end_year>\d{4}))?
          (,\s#{mon})?
          (,\sMonths:#{months})?$
        }x,

        #NO. 10 1990
        %r{^NO\.\s(?<number>\d{1,2})
          \s(?<year>\d{4})$
        }x,

        #V. 32 NO. 4-6 1964
        #V. 87NO. 1-8 1995
        #V. 71:NO. 4-6
        #V. 92 NO. 17-24 2000 SEP-DEC
        %r{^#{v}
          (\s|:|,)?\s?NOS?\.\s(?<start_number>\d+)-(?<end_number>\d+)
          (\s\(?(?<year>\d{4})
          (\s#{months})?\)?)?$
        }x,

        #V. 92:1-4 (JAN-FEB 2000)
        %r{^#{v}
           :(?<start_number>\d{1,2})-
             (?<end_number>\d{1,2})
           \s\(#{months}\s(?<year>\d{4})\)$
        }x,

        #V. 19 JULY-SEPT. 1957
        #V. 93,OCT-DEC 2001
        #V. 64 (JAN. -MAR. 1986)
        #V. 90:JULY-SEPT. (1998)
        %r{^#{v}
           (\s|,|:)\(?#{months}
           (\s\(?(?<year>\d{4}))?\)?$
        }x,

        # V. 88:NO. 13-18<P. 853-1328> (1996:JULY-SEPT. )
        %r{^#{v}
          ((\s|:|,)?\s?NOS?\.\s(?<start_number>\d+)-
            (?<end_number>\d+))?
          \s?<?#{pages}>?\s?
          \((?<year>\d{4}):
          #{months}\s?\)$
        }x,

        #V. 91:NO. 9/16=P. 739-1436 1999:MAY/AUG.
        #V. 83:NO. 13/18 1991:JULY/SEPT.
        #V. 94:NO. 13/18=P. 957-1418 2002:JULY/SEPT. (2002)
        %r{^#{v}
           :NO\.\s(?<start_number>\d{1,2})
           \/(?<end_number>\d{1,2})
           (=#{pages})?
           \s(?<year>\d{4}):#{months}
           (\s\(\d{4}\))?$
        }x,

        #V. 76:1986:JAN. -FEB. P. 1-362
        %r{^#{v}
          :(?<year>\d{4})
          :#{months}
          \s#{pages}$
        }x,

        #V. 3 (1942/43:AUG. /JUNE)
        %r{^#{v}
            \s\((?<start_year>\d{4})/(?<end_year>\d{2,4})
            :#{months}\)$
        }x,

        #V. 1,AUG-JUN 1940-41
        %r{^#{v}
          ,#{months}
          \s(?<start_year>\d{4})-(?<end_year>\d{2,4})$
        }x,

        # V. 7 (AUG. 1946-JUNE 1947)
        %r{^#{v}
            \s\((?<start_month>[A-z]+)\.?\s
            (?<start_year>\d{4})-
            (?<end_month>[A-z]+)\.?\s
            (?<end_year>\d{4})\)$
        }x,

        #V. 91 1999 PP. 1599-2168
        %r{^#{v}
           \s(?<year>\d{4})
           \s#{pages}$
        }x,

        #V. 59 1977 JUL-SEP
        %r{^#{v}
           \s(?<year>\d{4})
           \s#{months}$
        }x,

        #V. 76 (1986:APR. -JUNE)
        #V. 97(2005:APR. -JUNE)
        #V. 81 NO. 1-6 (1989:JAN-MAR)
        #V. 81 NO. 13-19 (1989:JULY 5-OCT 4)
        #V. 100:NO. 13-18(2008)
        %r{^#{v}
          ((\s|:)?\s?NO.\s(?<start_number>\d{1,2})-
            (?<end_number>\d{1,2}))?
           \s?\((?<year>\d{4})
           (:#{months}\s?)?\)$
        }x,

        #V. 85:NO. 13-24 (1993:JULY-1993:DEC)
        #V. 81 NO. 20-24 (1989:OCT-1989:DEC)
        %r{^#{v}
          (\s|:|,)?\s?NO\.\s(?<start_number>\d{1,2})-(?<end_number>\d{1,2})
          \s\((?<start_year>\d{4})
          :(?<start_month>[A-z]{3,4})\.?\s?
          -(?<end_year>\d{4})
          :(?<end_month>[A-z]{3,4})\)$
        }x,
        #V. 95:NO. 5(2003:MAR. 01)
        #V. 93:NO. 19 (2001:OCT. 03)
        #V. 76:NO. 5 1986
        %r{^#{v}
          (\s|:|,)?\s?NO\.\s(?<number>\d{1,2})
          \s?\(?(?<year>\d{4})
          (:(?<month>[A-Z]{3,4})\.?\s?\d{1,2})?
          \)?$
        }x,

        #V. 70 JAN-MAR 1983 PP. 1-580
        #V. 84 MAY-AUG 1992 (PP. 657-1304)
        #V. 12FEB-JUNE
        #V. 89:JAN. -JUNE(1997)
        %r{^#{v}
           (:|\s)?#{months}
           (\s?\(?(?<year>\d{4})\)?)?
           (\s\(?#{pages}\)?)?$
        }x,

        #V. 91 PP. 1263-1702 1999
        %r{^#{v}
           \s#{pages}
           \s(?<year>\d{4})$
        }x,

        #47/1-3 (1971:JULY-SEPT. )
        %r{^(?<volume>\d{1,3})
          \/(?<start_number>\d{1,2})
          -(?<end_number>\d{1,2})\s
          \((?<year>\d{4}):#{months}\s?\)$
        }x,

        #87:1-12 1995
        #87/13-24/1995
        #63 1979
        #V. 63 1979
        #V. 42 (1969)
        %r{^(V.\s)?(?<volume>\d{1,3})
          ((\s|:|,|\/)(?<start_number>\d{1,2})
             -(?<end_number>\d{1,2}))?
           (\s|:|\/)\(?(?<year>\d{4})\)?$
        }x,

        #NO. 23 (1998)
        %r{^NO\.\s(?<number>\d{1,2})
           \s\((?<year>\d{4})\)$
        }x,

        #NO. 27-28 (2000)
        %r{^NOS?\.\s(?<start_number>\d{1,2})
          -(?<end_number>\d{1,2})
          \s\((?<year>\d{4})\)$
        }x,

        # V. 3 1942-43
        #V. 9 1948-1949
        %r{^(V.\s)?(?<volume>\d{1,2})
           \s\(?(?<start_year>\d{4})(-|\/)
                (?<end_year>\d{2,4})\)?$
        }x,

        #V. 12 NOS. 1-3 (AUG. -DEC. 1951)
        #V. 94, NO. 17-24 (SEPT. -DEC. 2002)
        %r{^#{v}
           ,?\s?NOS?\.\s(?<start_number>\d{1,2})-
             (?<end_number>\d{1,2})\s?
           \(#{months}\s(?<year>\d{4})\)$
        }x,

        #simple year
        %r{
          ^#{y}$
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

          if ec['month'] and ec['month'] =~ /^[0-9]+$/
            ec['month'] = MONTHS[ec['month'].to_i-1]
          elsif ec['month']
            ec['month'] = Series.lookup_month ec['month']
          elsif ec['start_month']
            ec['start_month'] = Series.lookup_month ec['start_month']
            ec['end_month'] = Series.lookup_month ec['end_month']
          end
      
          if ec['end_year'] and ec['end_year'].length == 2
            ec['end_year'] = Series.calc_end_year ec['start_year'], ec['end_year']
          end

          #start and end year are the same
          if ec['start_year'] and ec['start_year'] == ec['end_year']
            ec['year'] = ec['start_year']
            ec.delete('start_year')
            ec.delete('end_year')
          end

          if ec['volume'] and !ec['year'] and ec['volume'].to_i >= 80
            ec['year'] = self.volume_to_year ec['volume']
          end
          if ec['year'] and !ec['volume'] and ec['year'].to_i >= 1988
            ec['volume'] = self.year_to_volume ec['year']
          end
          #ec = self.months_to_numbers ec
          #ec = self.months_to_numbers ec
        end
        ec
      end

      def explode(ec, src=nil)
        enum_chrons = {} 
        if ec.nil?
          return {}
        end

        ecs = []
=begin 
        #lost cause due to publication history
        if ec['start_number']
          for num in ec['start_number'] .. ec['end_number']
            copy = ec.clone
            copy['number'] = num
            ecs << copy
          end
        else
          ecs << ec
        end
=end
        ecs << ec
        ecs.each do | ec |
          if canon = self.canonicalize(ec)
            ec['canon'] = canon 
            enum_chrons[ec['canon']] = ec.clone
          end
        end
         
        enum_chrons
      end

      def canonicalize ec
        canon = []
        if ec['volume']
          canon << "Volume:#{ec['volume']}"
        end
        if ec['number']
          canon << "Number:#{ec['number']}"
          #ec['month'] = JournalOfTheNationalCancerInstitute.month_from_number(ec['number'])
        end
        if ec['start_number']
          canon << "Numbers:#{ec['start_number']}-#{ec['end_number']}"
        end
        if !ec['number'] and !ec['start_number'] and ec['start_page']
          canon << "Pages:#{ec['start_page']}-#{ec['end_page']}"
        end
        if ec['year']
          canon << "Year:#{ec['year']}"
        end
        if ec['start_year']
          canon << "Years:#{ec['start_year']}-#{ec['end_year']}"
        end
        if ec['month']
          canon << "Month:#{ec['month']}"
        end
        if ec['start_month']
          canon << "Months:#{ec['start_month']}-#{ec['end_month']}"
        end
        if canon.length > 0
          canon.join(", ")
        else 
          nil
        end
      end

      def year_to_volume year
        #starting with V. 80, 1988, year and volume have a one to one
        #correspondence
        if year.to_i >= 1988
          (80 + (year.to_i - 1988)).to_s
        else
          nil
        end
      end

      def volume_to_year volume
        #starting with V. 80, 1988, year and volume have a one to one
        #correspondence
        if volume.to_i >= 80
          (1988 + (volume.to_i - 80)).to_s
        else
          nil
        end
      end

      # only used after V.80 1988 due to ever changing publication schedule
      def month_from_number num
        month_num = (num.to_f / 2).ceil.to_i
        MONTHS[month_num-1]
      end

      # only used after V.80 1988 due to ever changing publication schedule
      def numbers_from_month month
        mindex = MONTHS.index(Series.lookup_month(month))+1
        nums = {start_number:mindex*2-1,
                end_number:mindex*2}
        nums
      end

      # only used after V80 1988 due to ever changing publication schedule
      def months_to_numbers ec
        if (ec['volume'] and ec['volume'].to_i >= 81) or
           (ec['year'] and ec['year'].to_i >= 1989)
          #can we derive number from month
          if !ec['number'] and !ec['start_number'] and 
            (ec['month'] or ec['start_month'])
            if ec['month']
              nums = self.numbers_from_month ec['month']
              ec['start_number'] = nums[:start_number].to_s
              ec['end_number'] = nums[:end_number].to_s
            elsif ec['start_month']
              nums = self.numbers_from_month ec['start_month']
              ec['start_number'] = nums[:start_number].to_s
              nums = self.numbers_from_month ec['end_month']
              ec['end_number'] = nums[:end_number].to_s
            end
          end
        end
        ec
      end

      # only used after V80 1988 due to ever changing publication schedule
      def numbers_to_months ec
        if (ec['volume'] and ec['volume'].to_i >= 81) or
           (ec['year'] and ec['year'].to_i >= 1989)
          if !ec['month'] and !ec['start_month'] and
            (ec['number'] or ec['start_number'])
            if ec['number']
              ec['month'] = self.month_from_number ec['number']
            elsif ec['start_number']
              sm = self.month_from_number ec['start_number']
              em = self.month_from_number ec['end_number']
              if sm == em
                ec['month'] = sm
              else
                ec['start_month'] = sm
                ec['end_month'] = em
              end
            end
          end
        end
        ec
      end

      def remove_dupe_years ec_string
        m = ec_string.match(/ (?<first>\d{4}) (?<second>\d{4})$/)
        if !m.nil? and m['first'] == m['second']
          ec_string.gsub(/ \d{4}$/,'')
        else
          ec_string
        end
      end

      def self.load_context 
      end
      self.load_context
    end
  end
end