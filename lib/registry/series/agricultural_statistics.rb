require 'pp'
# require 'source_record'

module Registry
  module Series
    # Agricultural Statistics series
    module AgriculturalStatistics
      # include EC
      # attr_accessor :number_counts, :volume_year

      def self.oclcs
        [1_773_189,
         471_365_867,
         33_822_997,
         37_238_142]
      end

      def parse_ec(ec_string)
        m = nil

        # some junk in the front
        ec_string.gsub!(/^HD1751 . A43 /, '')
        ec_string.gsub!(/^V\. /, '')
        ec_string.gsub!(/ ?C\. \d+ ?/, '')
        # these are insignificant
        ec_string.gsub!(/[()]/, '')
        # some junk at the end
        ec_string.gsub!(/ P77-\d+$/, '')
        # we don't care if it's a cd
        # 2011/CD
        ec_string.gsub!(/\/CD$/, '')
        # 2002 1 CD WITH CASE IN BINDER.
        # 2009 1 CD + 1 CASE NO PAPER INSERT
        ec_string.gsub!(/ 1 CD .*$/, '')
        # 995-96 CD
        ec_string.gsub!(/ CD$/, '')

        # fix the three digit years
        ec_string = '1' + ec_string if ec_string.match?(/^9\d\d[^0-9]*/)

        patterns = [
          # simple year
          # 2008 /* 264 */
          %r{
          ^(?<year>\d{4})$
          }x,

          # year range /* 79 */
          # 989-990
          # 1961-1963
          %r{
          ^(?<start_year>\d{4})[-\/](?<end_year>\d{2,4})$
          }x,

          # multiple years
          # 1946, 1948
          # 1995/1996-1997
          # we'll leave this for explode ?
          # basically we know what they are but it doesn't make sense to handle
          # them here
          %r{
            ^(?<multi_year_comma>\d{4}(,\s\d{4})+)$
          }x,
          %r{
            ^(?<multi_year_ec>\d{4}\/\d{4}-\d{4})$
          }x
        ]

        patterns.each do |p|
          break unless m.nil?
          m ||= p.match(ec_string)
        end

        unless m.nil?
          ec = Hash[m.names.zip(m.captures)]
          if ec.key?('end_year') && /^\d\d$/.match(ec['end_year'])
            ec['end_year'] = ec['start_year'][0, 2] + ec['end_year']
          elsif ec.key?('end_year') && /^\d\d\d$/.match(ec['end_year'])
            ec['end_year'] = ec['start_year'][0, 1] + ec['end_year']
          end
        end
        ec # ec string parsed into hash
      end

      # take a parsed enumchron and expand it into its constituent parts
      # real simple for this series
      # enum_chrons - { <canonical ec string> : {<parsed features>}, }
      #
      def explode(ec, _src = nil)
        enum_chrons = {}
        return {} if ec.nil?

        if ec['year']
          enum_chrons[ec['year']] = ec
        elsif ec['start_year'] && ec['end_year']
          # special stupidity
          if (ec['start_year'] == '1995') && (ec['end_year'] == '1996')
            enum_chrons['1995-1996'] = ec
          else
            (ec['start_year']..ec['end_year']).each do |y|
              enum_chrons[y] = ec
            end
          end
        elsif ec['multi_year_comma']
          ec['multi_year_comma'].split(/, */).each do |y|
            enum_chrons[y] = ec
          end
        elsif ec['multi_year_ec'] == '1995/1996-1997' # so dumb
          enum_chrons['1995-1996'] = ec
          enum_chrons['1997'] = ec
        end

        enum_chrons
      end

      def canonicalize(ec); end

      def self.parse_file
        @no_match = 0
        @match = 0
        input = File.dirname(__FILE__) + '/data/agstats_enumchrons.txt'
        open(input, 'r').each do |line|
          line.chomp!

          ec = SourceRecord.new.extend(AgriculturalStatistics).parse_ec(line)
          if ec.nil?
            @no_match += 1
            # puts "no match: "+line
          else
            # puts "match: "+self.explode(ec).to_s
            @match += 1
          end
        end

        # puts "AgStats match: #{@match}"
        # puts "AgStats no match: #{@no_match}"
        [@match, @no_match]
      end

      def self.load_context; end
      load_context
    end
  end
end
