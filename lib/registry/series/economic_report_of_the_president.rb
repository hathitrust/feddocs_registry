# frozen_string_literal: true
require 'registry/series/default_series_handler'

# Yearly, sometimes in multiple parts. We need to look at pub_date for
# monographs.
module Registry
  module Series
    # Economic Report of the President, a small series.
    class EconomicReportOfThePresident < DefaultSeriesHandler
      class << self; attr_accessor :parts end
      @parts = Hash.new { |hash, key| hash[key] = [] }

      def initialize
        super
        @title = 'Economic Report Of The President'
        @patterns = [

          # own canonical format
          %r{
            ^Year:(?<year>\d{4})(,\sPart:(?<part>\d{1}))?
            }x,

          # simple sudoc
          %r{
            ^Y\s?4\.?\sEC\s?7:EC\s?7\/2\/(?<year>\d{3,4})$
            }x,

          # stupid sudoc
          # Y 4. EC 7:EC 7/2/993/PT. 1-
          %r{
            ^Y\s?4\.?\sEC\s?7:EC\s?7\/2\/(?<year>\d{3,4})\s?\/PT.\s
            (?<part>\d{1})(\D|$)
            }x,

          # 1972/PT. 1
          %r{
            ^(?<year>\d{3,4})\/PT.\s(?<part>\d{1})$
            }x,
          # 1972/PT. 1-5
          %r{
            ^(?<year>\d{3,4})\/PT.\s(?<start_part>\d{1})-(?<end_part>\d{1})$
            }x,

          # simple year
          # 2008  /* 28 */
          # (2008)
          # 2008.
          %r{
            ^\(?(?<year>\d{4})\.?\)?$
            }x,

          # year with part  /* 33 */
          # 1973 PT. 1
          %r{
            ^(?<year>\d{4})\sPT\.\s(?<part>\d{1})$
            }x,
          # year with parts
          # 1973 PT. 1-3
          %r{
            ^(?<year>\d{4})\sPT\.\s(?<start_part>\d{1})-(?<end_part>\d{1})$
            }x,

          # multiple years /* 2 */
          %r{
            ^(?<start_year>\d{4})-(?<end_year>\d{4})$
            }x,

          # only part /* 11 */
          # PT. 1-5
          # PT. 2
          %r{
            ^PT\.\s(?<start_part>\d{1})-(?<end_part>\d{1})$
            }x,
          %r{
            ^P(AR)?T\.?\s(?<part>\d{1})$
            }x
        ]
      end

      def self.sudoc_stem
        'Y 4.EC 7:EC 7/2/'
      end

      def self.oclcs
        [3_160_302, 8_762_269, 8_762_232]
      end

      def parse_ec(ec_string)
        m = nil

        # C. 1 crap from beginning and end
        ec_string.sub!(/ ?C\. 1 ?/, '')

        # occassionally a '-' at the end. not much we can do with that
        ec_string.sub!(/-$/, '')


        @patterns.each do |p|
          break unless m.nil?

          m ||= p.match(ec_string)
        end

        unless m.nil?
          ec = Hash[m.names.zip(m.captures)]
          # remove nils
          ec.delete_if { |_k, v| v.nil? }
          if ec.key?('year') && (ec['year'].length == 3)
            ec['year'] = if (ec['year'][0] == '8') || (ec['year'][0] == '9')
                           '1' + ec['year']
                         else
                           '2' + ec['year']
                         end
          end

          if ec.key?('start_year') && (ec['start_year'].length == 3)
            if (ec['start_year'][0] == '8') || (ec['start_year'][0] == '9')
              ec['start_year'] = '1' + ec['start_year']
            else
              ec['start_year'] = '2' + ec['start_year']
            end
          end

          if ec.key?('end_year') && /^\d\d$/.match(ec['end_year'])
            ec['end_year'] = if ec['end_year'].to_i < ec['start_year'][2, 2].to_i
                               # crosses century. e.g. 1998-01
                               (ec['start_year'][0, 2].to_i + 1).to_s +
                                 ec['end_year']
                             else
                               ec['start_year'][0, 2] + ec['end_year']
                             end
          elsif ec.key?('end_year') && /^\d\d\d$/.match(ec['end_year'])
            if ec['end_year'].to_i < 700 # 1699 and 2699 are both wrong, but...
              ec['end_year'] = '2' + ec['end_year']
            else
              ec['end_year'] = '1' + ec['end_year']
            end
          end
        end
        ec # ec string parsed into hash
      end

      # Take a parsed enumchron and expand it into its constituent parts
      # enum_chrons - { <canonical ec string> : {<parsed features>}, }
      #
      # Canonical string format: Year:<year>, Part:<part>
      def explode(ec, src = {})
        ec ||= {}

        # some of these are monographs with the year info in pub_date or sudocs
        if ec['year'].nil? && ec['start_year'].nil?
          # try sudocs first
          if !src[:sudocs].nil? &&
             !src[:sudocs].select { |s| s =~ /Y 4\.EC 7:EC 7\/2\/\d{3}/ }[0].nil?
            sudoc = src[:sudocs].select { |s| s =~ /Y 4\.EC 7:EC 7\/2\/\d{3}/ }[0]
            unless sudoc.nil?
              m = /EC 7\/2\/(?<year>\d{3,4})(\/.*)?$/.match(sudoc)
              if !m.nil? && (m[:year][0] == '9')
                ec['year'] = '1' + m[:year]
              elsif !m.nil?
                ec['year'] = m[:year]
              end
            end
          elsif !src[:pub_date].nil? && (src[:pub_date].count == 1)
            ec['year'] = src[:pub_date][0]
          end
        end

        enum_chrons = {}
        return {} if ec.keys.count.zero?

        canon = ''
        if ec['year'] && !ec['part'].nil?
          canon = canonicalize(ec)
          enum_chrons[canon] = ec.clone
          self.class.parts[ec['year']] << ec['part']
          self.class.parts[ec['year']].uniq!
        elsif ec['year'] && ec['start_part']
          (ec['start_part']..ec['end_part']).each do |pt|
            canon = canonicalize('year' => ec['year'], 'part' => pt)
            enum_chrons[canon] = ec.clone
            self.class.parts[ec['year']] << pt
          end
          self.class.parts[ec['year']].uniq!
        elsif ec['year'] # but no parts.
          # we can't assume all of them, horrible marc
          # if @parts[ec['year']].count > 0
          #  for pt in @parts[ec['year']]
          #    canon = "Year: #{ec['year']}, Part: #{pt}"
          #    enum_chrons[canon] = ec
          #  end
          # else
          canon = canonicalize(ec)
          enum_chrons[canon] = ec.clone
          # end
        elsif ec['start_year']
          (ec['start_year']..ec['end_year']).each do |y|
            # if @parts[y].count > 0
            #  for pt in @parts[y]
            #    canon = "Year: #{y}, Part: #{pt}"
            #    enum_chrons[canon] = ec
            #  end
            # else
            canon = canonicalize('year' => y)
            enum_chrons[canon] = ec.clone
            # end
          end
        end

        enum_chrons
      end

      def canonicalize(ec)
        canon = []
        canon << "Year:#{ec['year']}" if ec['year']
        canon << "Part:#{ec['part']}" if ec['part']
        canon.join(', ') unless canon.empty?
      end

      def self.load_context
        ps = File.open(File.dirname(__FILE__) + '/data/econreport_parts.json',
                       'r')
        # copy individually so we don't clobber the @parts definition
        # i.e. no @parts = JSON.parse(ps.read)
        JSON.parse(ps.read).each do |key, pts|
          @parts[key] = pts
        end
      end
      load_context
    end
  end
end
