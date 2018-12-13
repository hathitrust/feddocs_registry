require 'forwardable'
module Registry
  # Methods common to Series handling
  module Series
    extend Forwardable
    def_delegators :ec_handler, :parse_ec, :explode

    def ec_handler
      @series ||= series
      if @series&.first
        series_class = Module.const_get('Registry::Series::'+ @series.first).new
      else
        series_class = DefaultSeriesHandler.new
      end
      @ec_handler ||= series_class 
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

    # Uses ocns to identify a series title (and appropriate module)
    def series
      @series ||= []
      # try to set it
      if (record_ocns.map(&:to_i) &
          Series::FederalRegister.oclcs).any?
        @series << 'FederalRegister'
      end
      if (record_ocns.map(&:to_i) &
          Series::StatutesAtLarge.oclcs).any?
        @series << 'StatutesAtLarge'
      end
      if (record_ocns.map(&:to_i) &
          Series::AgriculturalStatistics.oclcs).any?
        @series << 'AgriculturalStatistics'
      end
      if (record_ocns.map(&:to_i) &
          Series::MonthlyLaborReview.oclcs).any?
        @series << 'MonthlyLaborReview'
      end
      if (record_ocns.map(&:to_i) &
          Series::MineralsYearbook.oclcs).any?
        @series << 'MineralsYearbook'
      end
      if (record_ocns.map(&:to_i) &
          Series::StatisticalAbstract.oclcs).any?
        @series << 'StatisticalAbstract'
      end
      if (record_ocns.map(&:to_i) &
         Series::UnitedStatesReports.oclcs).any? ||
         record_sudocs
         .grep(%r{^#{::Regexp
                        .escape(Series::UnitedStatesReports.sudoc_stem)}}).any?
        @series << 'UnitedStatesReports'
      end
      if record_sudocs
         .grep(%r{^#{::Regexp
                        .escape(Series::CivilRightsCommission.sudoc_stem)}})
         .any?
        @series << 'CivilRightsCommission'
      end
      if (record_ocns.map(&:to_i) &
          Series::CongressionalRecord.oclcs).any?
        @series << 'CongressionalRecord'
      end
      if record_sudocs
         .grep(/^#{::Regexp.escape(Series::ForeignRelations.sudoc_stem)}/)
         .any?
        @series << 'ForeignRelations'
      end
      if (record_ocns.map(&:to_i) &
          Series::CongressionalSerialSet.oclcs).any? ||
         record_sudocs
         .grep(%r{^#{::Regexp
                        .escape(Series::CongressionalSerialSet.sudoc_stem)}})
         .any?
        @series << 'CongressionalSerialSet'
      end
      if (record_ocns.map(&:to_i) &
          Series::EconomicReportOfThePresident.oclcs).any? ||
         record_sudocs
         .grep(%r{^#{::Regexp
                        .escape(Series::EconomicReportOfThePresident
                                .sudoc_stem)}}).any?
        @series << 'EconomicReportOfThePresident'
      end
      if (record_ocns.map(&:to_i) &
          Series::ReportsOfInvestigations.oclcs).any?
        @series << 'ReportsOfInvestigations'
      end
      if (record_ocns.map(&:to_i) &
          Series::DecisionsOfTheCourtOfVeteransAppeals.oclcs).any?
        @series << 'DecisionsOfTheCourtOfVeteransAppeals'
      end
      if (record_ocns.map(&:to_i) &
          Series::JournalOfTheNationalCancerInstitute.oclcs).any?
        @series << 'JournalOfTheNationalCancerInstitute'
      end
      if (record_ocns.map(&:to_i) &
          Series::CancerTreatmentReport.oclcs).any?
        @series << 'CancerTreatmentReport'
      end
      if (record_ocns.map(&:to_i) &
          Series::VitalStatistics.oclcs).any?
        @series << 'VitalStatistics'
      end
      if (record_ocns.map(&:to_i) &
          Series::PublicPapersOfThePresidents.oclcs).any?
        @series << 'PublicPapersOfThePresidents'
      end
      if (record_ocns.map(&:to_i) &
          Series::DepartmentOfAgricultureLeaflet.oclcs).any?
        @series << 'DepartmentOfAgricultureLeaflet'
      end
      if (record_ocns.map(&:to_i) &
          Series::PublicHealthReports.oclcs).any?
        @series << 'PublicHealthReports'
      end
      if (record_ocns.map(&:to_i) &
          Series::WarOfTheRebellion.oclcs).any?
        @series << 'WarOfTheRebellion'
      end
      if (record_ocns.map(&:to_i) &
          Series::CensusOfManufactures.oclcs).any?
        @series << 'CensusOfManufactures'
      end
      if (record_ocns.map(&:to_i) &
          Series::USExports.oclcs).any?
        @series << 'USExports'
      end
      if (record_ocns.map(&:to_i) &
          Series::CurrentPopulationReport.oclcs).any?
        @series << 'CurrentPopulationReport'
      end
      if (record_ocns.map(&:to_i) &
          Series::PublicHealthReportSupplements.oclcs).any?
        @series << 'PublicHealthReportSupplements'
      end
      if (record_ocns.map(&:to_i) &
          Series::FCCRecord.oclcs).any?
        @series << 'FCCRecord'
      end
      if (record_ocns.map(&:to_i) &
          Series::CalendarOfBusiness.oclcs).any?
        @series << 'CalendarOfBusiness'
      end

      if @series&.any?
        @series.uniq!
        @ec_handler = Module.const_get('Registry::Series::' + @series.first).new
        load_context
      else
        @ec_handler = DefaultSeriesHandler.new
      end
      # get whatever we got
      @series
    end
  end
end
