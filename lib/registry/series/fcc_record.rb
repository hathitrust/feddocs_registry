# frozen_string_literal: true
require 'json'
require 'pp'
require 'registry/series/default_series_handler'

module Registry
  module Series
    # Processing for FCC Record series
    class FCCRecord < DefaultSeriesHandler
      @pages_to_numbers = {}

      def initialize 
        super
        @title = 'FCC Record'
        # be real loose with the months
        @tokens[:m] = '(MONTH:)?(?<month>(JAN?(UARY)?|F(EB)?(RUARY)?|MA?R(CH)?|APR?(IL)?|MA?Y|J(E|UN|UNE)|J(Y|L|UL|ULY)|AU?G(UST)?|S(EPT?)?(EMBER)?|O(CT)?(OBER)?|N(OV)?(EMBER)?|D(EC)?(EMBER)?)\.?)'

        @patterns << /^(?<volume>\d{1,2})\/(?<number>\d{1,2})$/xi
        # V. 11 NO. 32 SUP. 1996
        @patterns << %r{
                       ^#{@tokens[:v]}#{@tokens[:div]}
                        #{@tokens[:n]}#{@tokens[:div]}
                        #{@tokens[:sup]}
                        (#{@tokens[:div]}#{@tokens[:y]})?$
                      }xi
        @patterns << %r{
                        ^(?<volume>\d{1,2})\/
                        #{@tokens[:ns]}$
                      }xi

        # V. V. 17:17 JUN 21 - JUN 28 2002
        # V. 15:34 (NOV 13/24, 2000)
        # V. 15:36 (NOV 27/DEC 2000)
        @patterns << %r{
                        ^#{@tokens[:v]}#{@tokens[:div]}
                        (NO\.\s)?(?<number>\d{1,2})#{@tokens[:div]}
                        \(?(?<start_month>#{@tokens[:m]})\s?((?<start_day>\d{1,2}))?
                        #{@tokens[:div]}
                        (?<end_month>#{@tokens[:m]})?\s?(?<end_day>\d{1,2})?
                        #{@tokens[:div]}
                        #{@tokens[:y]}\)?$
                      }xi
        # V. V. 12:35 1997
        # V. 16:20(2001)
        # V. 13:21 SUP. (1998)
        @patterns << %r{
                       ^#{@tokens[:v]}#{@tokens[:div]}
                       (?<number>\d{1,2})
                       (\s#{@tokens[:sup]}\s)?
                       ([\s\(]+#{@tokens[:y]}\)?)?$
                     }xi
        @patterns << %r{
                       ^((V\.\s)+)?(?<volume>\d{1,2})#{@tokens[:div]}
                        (?<number>\d{1,2})
                        (#{@tokens[:div]}#{@tokens[:sup]})?$
                     }xi

        # 3/18-20 (AUG. 29-OCT. 7, 1988)
        # 8/21-22 (OCT 4-29, 1993)
        # V. 9:7-10 (MAR 21-MAY 13, 1994)
        @patterns << %r{
                        ^((V\.\s)+)?(?<volume>\d{1,2})#{@tokens[:div]}
                        (?<start_number>\d{1,2})-(?<end_number>\d{1,2})
                        (\s?\(
                          (?<start_month>#{@tokens[:m]})\s(?<start_day>\d{1,2})
                          #{@tokens[:div]}
                          ((?<end_month>#{@tokens[:m]})\s)?
                          (?<end_day>\d{1,2})
                          #{@tokens[:div]}
                          #{@tokens[:y]}\)
                        )?$
                     }xi
        # 11/32-33 1996
        # V. 12:23-24 1997
        # V. 5:22-23 (OCT-NOV 1990)
        @patterns << %r{
                        ^(((V\.\s)+))?(?<volume>\d{1,2})#{@tokens[:div]}
                        (?<start_number>\d{1,2})-(?<end_number>\d{1,2})
                        \s?\(?((?<start_month>#{@tokens[:m]})-(?<end_month>#{@tokens[:m]}))?
                        \s(?<year>\d{4})\)?$
                     }xi

        # V. 6:10-11 (MAY 1991)
        @patterns << %r{
          ^#{@tokens[:v]}#{@tokens[:div]}
          (?<start_number>\d{1,2})-(?<end_number>\d{1,2})\s?
          \(?#{@tokens[:m]}\s?#{@tokens[:y]}\)?$
        }xi

        # V. 12 NO. 17 P. 9617-10204 1997
        # V. 9 NO. 15-16 P. 3239-3956 1994
        @patterns << %r{
                        ^#{@tokens[:v]}#{@tokens[:div]}
                        (#{@tokens[:n]}|#{@tokens[:ns]})#{@tokens[:div]}
                        P\.\s(?<start_page>\d{1,5})-(?<end_page>\d{1,5})
                        (\s#{@tokens[:y]})?$
                     }xi

        # V. 7:P. 3755/4833(1992)
        # V. 13:P. 19401/20049(1997/1998)
        @patterns << %r{
                        ^#{@tokens[:v]}#{@tokens[:div]}
                        P\.\s(?<start_page>\d{1,5})#{@tokens[:div]}
                        (?<end_page>\d{1,5})
                        (\((#{@tokens[:y]}|(?<start_year>\d{4})\/(?<end_year>\d{2,4}))\))?$
                     }xi

        # V9NO11-12 1994
        # V. 12NO. 7-8 1997
        @patterns << %r{
                      ^V(\.\s)?(?<volume>\d+)
                      NO(\.\s)?(?<start_number>\d+)-(?<end_number>\d+)
                      (\s#{@tokens[:y]})?$
                     }xi

        # V. 6:NO. 19-22 1991:SEPT. 9-NOV. 1
        # V. 6:NO. 21-22(1991:OCT. 7-NOV. 1) <P. 5732-6472>
        # V. 21:NO. 1 2006:JAN. 3-31
        #  V. 15:8(2000:MARCH 6-17)
        # V. 21:NO. 1(2006:JAN. 3/31)
        # V. 21:NO. 1(2006:JAN. 3/JAN. 31) <P. 1-945>
        @patterns << %r{
                      ^#{@tokens[:v]}#{@tokens[:div]}
                      (#{@tokens[:ns]}|#{@tokens[:n]}|(?<number>\d{1,2}))[\s\(]+
                      #{@tokens[:y]}#{@tokens[:div]}
                      (?<start_month>#{@tokens[:m]})\s?(?<start_day>\d{1,2})[-\/]
                      ((?<end_month>#{@tokens[:m]})\s?)?(?<end_day>\d{1,2})\)?
                      (\s<?P\.\s(?<start_page>\d{1,5})-(?<end_page>\d{1,5})>?)?
                      $
                    }xi

        # V. 23(2008) P. 8153-9023
        # V. 18:NO. 12(2003) P. 9282-10332
        @patterns << %r{
                      ^#{@tokens[:v]}
                      (#{@tokens[:div]}#{@tokens[:n]})?
                      \(#{@tokens[:y]}\)
                      \sP.\s(?<start_page>\d{1,5})[-\/](?<end_page>\d{1,5})$
                     }xi

        # V. 16,NO. 20 2001 JULY-AUG.
        @patterns << %r{
                      ^#{@tokens[:v]}#{@tokens[:div]}
                      #{@tokens[:n]}#{@tokens[:div]}
                      #{@tokens[:y]}#{@tokens[:div]}
                      (?<start_month>#{@tokens[:m]})#{@tokens[:div]}
                      (?<end_month>#{@tokens[:m]})$
                     }xi

        # V. 17:NO. 27(2001/02):P. 20086-20779
        # V. 22:NO. 13(2007)P. 9864-10683
        @patterns << %r{
          ^#{@tokens[:v]}#{@tokens[:div]}
          #{@tokens[:n]}
          \(((?<start_year>\d{4})\/(?<end_year>\d{2,4})|#{@tokens[:y]})\)
          ((#{@tokens[:div]})?P\.\s(?<start_page>\d{1,5})[-\/](?<end_page>\d{1,5}))?$
        }xi

        # V. 14,NO. 1 1998-1999
        # V. 14 NO. 1 1998/99
        @patterns << %r{
          ^#{@tokens[:v]}#{@tokens[:div]}
          #{@tokens[:n]}#{@tokens[:div]}
          (?<start_year>\d{4})[-\/]
          (?<end_year>\d{2,4})$
        }xi

        # V. V. 25:21,P. 17467-18163,DEC 20-31 2010
        # V. V. 25:2, P. 830-1765, JAN 22-FEB 19 2010
        @patterns << %r{
          ^#{@tokens[:v]}#{@tokens[:div]}
          (NO\.\s)?(?<number>\d{1,2})#{@tokens[:div]}
          P\.\s(?<start_page>\d{1,5})[-\/]
          (?<end_page>\d{1,5})#{@tokens[:div]}
          ((?<supplement>SUP\.\s))?
          (?<start_month>#{@tokens[:m]})\s?
          (?<start_day>\d{1,2})?-
          (?<end_month>#{@tokens[:m]})?\s?
          (?<end_day>\d{1,2})?\s
          #{@tokens[:y]}$
        }xi

        # V. 2 NO. 1-4 PG. 1-1358 1987
        @patterns << %r{
          ^#{@tokens[:v]}#{@tokens[:div]}
          #{@tokens[:ns]}#{@tokens[:div]}
          #{@tokens[:pgs]}#{@tokens[:div]}
          (#{@tokens[:y]})?$
        }xi

        # V. 8:25-26 N29-D23(1993)
        # V. 12:20 JY28-AG8(1997)
        # 12/13-14 JE. 2-13 1997
        @patterns << %r{
        ^((V\.\s)+)?(?<volume>\d{1,2})#{@tokens[:div]}
          ((?<start_number>\d{1,2})-(?<end_number>\d{1,2})|(?<number>\d{1,2}))\s
          (?<start_month>#{@tokens[:m]})\s?(?<start_day>\d{1,2})-
          (?<end_month>#{@tokens[:m]})?(?<end_day>\d{1,2})
          ([\(\s]#{@tokens[:y]}\)?)?$
        }xi

        # V. 2:20-22 S-N(1987)
        @patterns << %r{
          ^#{@tokens[:v]}#{@tokens[:div]}
          (?<start_number>\d{1,2})-
          (?<end_number>\d{1,2})#{@tokens[:div]}
          (?<start_month>#{@tokens[:m]})-(?<end_month>#{@tokens[:m]})
          (\(#{@tokens[:y]}\))?$
        }xi

        # 13/NO. 13
        @patterns << %r{
          ^(?<volume>\d{1,2})#{@tokens[:div]}
          #{@tokens[:n]}$
        }xi

        # 13/17-18 JE. 15-JL. 10 1998
        # V. 15 NO. 15-16 MY. 15-JE. 9 2000
        @patterns << %r{
        ^((V\.\s)+)?(?<volume>\d{1,2})#{@tokens[:div]}
          (NO\.\s)?(?<start_number>\d{1,2})-(?<end_number>\d{1,2})\s
          (?<start_month>#{@tokens[:m]})\s?(?<start_day>\d{1,2})-
          (?<end_month>#{@tokens[:m]})\s?(?<end_day>\d{1,2})\s
          #{@tokens[:y]}$
        }xi
      end

      def self.oclcs
        [14_964_165,
         25_705_333,
         31_506_723,
         52_110_163,
         58_055_590,
         70_896_877]
      end

      def parse_ec(ec_string)
        matchdata = nil
        ec_string = preprocess(ec_string).chomp

        # fix 3 digit years, this is more restrictive than most series specific
        # work.
        ec_string = '1' + ec_string if ec_string.match?(/^9\d\d$/)

        @patterns.each do |p|
          break unless matchdata.nil?

          matchdata ||= p.match(ec_string)
        end

        # some cleanup
        unless matchdata.nil?
          ec = matchdata.named_captures
          # Fix months
          ec = Series.fix_months(ec)

          # Remove nils
          ec.delete_if { |_k, value| value.nil? }

          # year unlikely. Probably don't know what we think we know.
          # From the regex, year can't be < 1800
          ec = nil if ec['year'].to_i > (Time.now.year + 5)
          if ec.key? 'end_year'
            ec['start_year'] ||= ec['year']
            ec['end_year'] = Series.calc_end_year(ec['start_year'], ec['end_year'])
          end

        end
        ec
      end

      # Take a parsed enumchron and expand it into its individual numbers
      def explode(ec, _src = nil)
        enum_chrons = {}
        return {} if ec.nil?

        if !(ec.key?('number') || ec.key?('start_number')) &&
           ec.key?('start_page')
          ec = numbers_from_pages(ec)
        end

        if !ec.key?('start_number')
          if (canon = canonicalize(ec))
            ec['canon'] = canon
            enum_chrons[ec['canon']] = ec.clone
          end
        else
          (ec['start_number'].to_i..ec['end_number'].to_i).each do |num|
            single_enum = ec.clone
            single_enum['number'] = num.to_s
            if (canon = canonicalize(single_enum))
              single_enum['canon'] = canon
              enum_chrons[single_enum['canon']] = single_enum
            end
          end
        end
        enum_chrons
      end

      def canonicalize(ec)
        t_order = []
        # shorten it if we have good data
        if ec['volume'] && ec['number']
          t_order = %w[volume number]
        # throw it all in
        else
          t_order = %w[volume number start_number end_number year start_year end_year start_page end_page month day start_month start_day end_month end_day]
        end
        canon = t_order.reject { |t| ec[t].nil? }
                       .collect { |t| t.to_s.tr('_', ' ').capitalize + ':' + ec[t] }
                       .join(', ')
        canon = nil if canon == ''
        canon
      end

      def self.pages_to_numbers
        @pages_to_numbers
      end

      def self.load_context
        # Be able to look up numbers based on pages
        @pages_to_numbers = JSON.parse(File.open(File.dirname(__FILE__) +
                                      '/data/fcc_record_p_to_n.json').read)
      end
      load_context

      def numbers_from_pages(ec)
        ec['start_number'] = self.class.pages_to_numbers[
          [ec['volume'], ec['start_page']].to_s
        ]
        ec['end_number'] = (self.class.pages_to_numbers[
          [
            ec['volume'],
            (ec['end_page'].to_i + 1).to_s
          ].to_s
        ].to_i - 1).to_s
        if ec['end_number'].nil? && ec['start_number'].nil?
          ec.delete('end_number')
          ec.delete('start_number')
        end
        ec.delete('end_number') if ec['end_number'].to_i < 1
        ec['start_number'] ||= ec['end_number']
        ec['end_number'] ||= ec['start_number']
        ec
      end

    end
  end
end
