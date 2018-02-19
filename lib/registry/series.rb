module Registry
  # Methods common to Series handling
  module Series
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
                       ((m_abbrev.length == 2) &&
                       /^#{m_abbrev[0]}.*#{m_abbrev[1]}/i =~ month)
      end
    end
  end
end
