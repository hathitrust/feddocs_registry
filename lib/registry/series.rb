require 'forwardable'
Dir[File.dirname(__FILE__) + "/series/*.rb"].each {|file| require file }
require 'registry/series'
require 'registry/series/default_series_handler'
module Registry
  # Methods common to Series handling
  module Series
    extend Forwardable
    class << self
      attr_accessor :available_ec_handlers
      attr_accessor :default_ec_handler
    end
    def_delegators :ec_handler, :parse_ec, :explode

    @available_ec_handlers = {} 
    def self.get_available_ec_handlers 
      self.constants.each do |c|
        next unless eval(c.to_s).class == Class and 
          eval(c.to_s).superclass == Registry::Series::DefaultSeriesHandler 
        new_handler = eval(c.to_s).new
        Series.available_ec_handlers[new_handler.title] = new_handler 
      end
      Series.default_ec_handler = Registry::Series::DefaultSeriesHandler.new
    end
    get_available_ec_handlers
    
    def ec_handler
      return @ec_handler if @ec_handler
      @series ||= series
      if @series&.any?
        @ec_handler = Series.available_ec_handlers[@series.first] 
      else
        @ec_handler = Series.default_ec_handler
      end
    end

    # given a starting year with 4 digits and an ending year with 2 or 3 digits,
    # figure out the century and millenium
    def self.calc_end_year(start_year, end_year)
      start_year = start_year.to_str
      end_year = end_year.to_str
      if /^\d\d$/.match?(end_year)
        end_year = if end_year.to_i < start_year[2, 2].to_i
                     # crosses century. e.g. 1998-01
                     (start_year[0, 2].to_i + 1).to_s + end_year
                   else
                     start_year[0, 2] + end_year
                   end
      elsif /^\d\d\d$/.match?(end_year)
        end_year = correct_year(end_year)
      end
      end_year
    end

    def remove_dupe_years(ec_string)
      m = ec_string.match(/ (?<first>\d{4}) (?<second>\d{4})$/)
      if !m.nil? && (m['first'] == m['second'])
        ec_string.gsub(/ \d{4}$/, '')
      else
        ec_string
      end
    end
    module_function :remove_dupe_years

    def self.correct_year(year)
      year = year.to_s
      # add a 2; 1699 and 2699 are both wrong, but...
      if year.to_i < 700
        year = '2' + year
      elsif year.to_i < 1000
        year = '1' + year
      end
      year
    end

    # a lot of terrible abbreviations for months
    MONTHS = %w[January February March April May
                June July August September October
                November December].freeze
    def self.lookup_month(m_abbrev)
      m_abbrev.chomp!('.')
      MONTHS.each do |month|
        return month if /^#{m_abbrev}/i.match?(month) ||
                        m_abbrev.to_i == (MONTHS.index(month) + 1) ||
                        ((m_abbrev.length == 2) &&
                        /^#{m_abbrev[0]}.*#{m_abbrev[1]}/i =~ month)
      end
      nil
    end

    def preprocess(ec_string)
      # fix 3 digit years, this is more restrictive than most series specific
      # work.
      ec_string = '1' + ec_string if ec_string.match?(/^9\d\d$/)
      ec_string.sub(/^C\. [1-2] /, '').sub(/\(\s/, '(').sub(/\s\)/, ')')
    end
    module_function :preprocess


    def fix_months(match_hash)
      match_hash.delete('month') if match_hash['start_month']
      %w[month start_month end_month].each do |capture|
        if match_hash[capture]
          match_hash[capture] = Series.lookup_month(match_hash[capture])
        end
      end
      match_hash
    end
    module_function :fix_months

    def canonicalize(ec)
      # default order is:
      t_order = %w[year month start_month end_month volume part number start_number end_number book sheet start_page end_page supplement]
      canon = t_order.reject { |t| ec[t].nil? }
                     .collect { |t| t.to_s.tr('_', ' ').capitalize + ':' + ec[t] }
                     .join(', ')
      canon = nil if canon == ''
      canon
    end

    def load_context; end

    def record_ocns
      if defined? ocns and ocns 
        ocns
      else
        []
      end
    end

    def record_sudocs
      if defined? sudocs and sudocs
        sudocs
      else
        []
      end
    end

    # Uses ocns and sudocs to identify a series title 
    # (and appropriate ultimately handler)
    def series
      @series ||= []
      Series.available_ec_handlers.each do |_k, handler|
        if (record_ocns.map(&:to_i) & 
            handler.class.oclcs).any? ||
           (defined?(handler.class.sudoc_stem) &&
             record_sudocs.grep(%r{^#{::Regexp
                        .escape(handler.class.sudoc_stem)}}).any?
           )
          @series << handler.title
        end
      end
      @series.uniq!
      @series
    end
  end
end
