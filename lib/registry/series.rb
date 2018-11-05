module Registry
  # Methods common to Series handling
  module Series
    class << self
      attr_accessor :patterns
      attr_accessor :tokens
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

    @tokens = {
      # divider
      div: '[\s:,;\/-]+\s?',

      # volume
      v: '(V\.\s?)?V(OLUME:)?\.?\s?(0+)?(?<volume>\d+)',

      # number
      n: 'N(O|UMBER:)\.?\s?(0+)?(?<number>\d+)',

      # part
      # have to be careful with this due to frequent use of pages in enumchrons
      pt: '\[?P(AR)?T:?\.?\s?(0+)?(?<part>\d+)\]?',

      # year
      y: '(YEAR:)?\[?(?<year>(1[8-9]|20)\d{2})\.?\]?',

      # book
      b: 'B(OO)?K:?\.?\s?(?<book>\d+)',

      # sheet
      sh: 'SHEET:?\.?\s?(?<sheet>\d+)',

      # month
      m: '(MONTH:)?(?<month>(JAN(UARY)?|FEB(RUARY)?|MAR(CH)?|APR(IL)?|MAY|JUNE?|JULY?|AUG(UST)?|SEPT?(EMBER)?|OCT(OBER)?|NOV(EMBER)?|DEC(EMBER)?)\.?)'

    }

    @patterns = [
      /^#{@tokens[:v]}$/xi,

      # risky business
      /^(0+)?(?<volume>[1-9])$/xi,

      /^#{@tokens[:n]}$/xi,

      /^#{@tokens[:pt]}$/xi,

      /^#{@tokens[:y]}$/xi,

      /^#{@tokens[:b]}$/xi,

      /^#{@tokens[:sh]}$/xi,

      /^#{@tokens[:m]}$/xi,

      # compound patterns
      /^#{@tokens[:v]}#{@tokens[:div]}#{@tokens[:pt]}$/xi,

      /^#{@tokens[:y]}#{@tokens[:div]}#{@tokens[:pt]}$/xi,

      /^#{@tokens[:y]}#{@tokens[:div]}#{@tokens[:v]}$/xi,

      /^#{@tokens[:v]}[\(\s]\s?#{@tokens[:y]}\)?$/xi,

      /^#{@tokens[:v]}#{@tokens[:div]}#{@tokens[:n]}$/xi,

      %r{
        ^#{@tokens[:v]}#{@tokens[:div]}
        #{@tokens[:pt]}#{@tokens[:div]}
        #{@tokens[:y]}$
      }xi,

      %r{
        ^#{@tokens[:y]}#{@tokens[:div]}
        #{@tokens[:v]}#{@tokens[:div]}
        #{@tokens[:pt]}$
      }xi,

      /^#{@tokens[:y]}#{@tokens[:div]}#{@tokens[:m]}$/xi,

      /^#{@tokens[:m]}#{@tokens[:div]}#{@tokens[:y]}$/xi,

      %r{
        ^#{@tokens[:n]}#{@tokens[:div]}
        #{@tokens[:m]}#{@tokens[:div]}
        #{@tokens[:y]}$
      }xi,

      %r{
        ^#{@tokens[:n]}#{@tokens[:div]}
        [\(\s]\s?#{@tokens[:y]}\)$
      }xi,

      %r{
        ^#{@tokens[:y]}#{@tokens[:div]}
        #{@tokens[:m]}#{@tokens[:div]}
        #{@tokens[:n]}$
      }xi,

      %r{
        ^#{@tokens[:y]}#{@tokens[:div]}
        (START\sMONTH:)?(?<start_month>#{@tokens[:m]})#{@tokens[:div]}
        (END\sMONTH:)?(?<end_month>#{@tokens[:m]})$
      }xi
    ]

    def parse_ec(ec_string)
      matchdata = nil

      # fix 3 digit years, this is more restrictive than most series specific
      # work.
      ec_string = '1' + ec_string if ec_string.match?(/^9\d\d$/)

      Series.patterns.each do |p|
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
      end
      ec
    end

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

    def explode(ec, _src = nil)
      # we would need to know something about the title to do this
      # accurately, so we're not really doing anything here
      enum_chrons = {}
      return {} if ec.nil?

      ecs = [ec]
      ecs.each do |enum|
        if (canon = canonicalize(enum))
          enum['canon'] = canon
          enum_chrons[enum['canon']] = enum.clone
        end
      end
      enum_chrons
    end

    def canonicalize(ec)
      # default order is:
      t_order = %w[year month start_month end_month volume part number book sheet]
      canon = t_order.reject { |t| ec[t].nil? }
                     .collect { |t| t.to_s.tr('_', ' ').capitalize + ':' + ec[t] }
                     .join(', ')
      canon = nil if canon == ''
      canon
    end

    def load_context; end

    # Uses oclc_resolved to identify a series title (and appropriate module)
    def series
      @series ||= []
      # try to set it
      if (oclc_resolved.map(&:to_i) &
          Series::FederalRegister.oclcs).any?
        @series << 'FederalRegister'
      end
      if (oclc_resolved.map(&:to_i) &
          Series::StatutesAtLarge.oclcs).any?
        @series << 'StatutesAtLarge'
      end
      if (oclc_resolved.map(&:to_i) &
          Series::AgriculturalStatistics.oclcs).any?
        @series << 'AgriculturalStatistics'
      end
      if (oclc_resolved.map(&:to_i) &
          Series::MonthlyLaborReview.oclcs).any?
        @series << 'MonthlyLaborReview'
      end
      if (oclc_resolved.map(&:to_i) &
          Series::MineralsYearbook.oclcs).any?
        @series << 'MineralsYearbook'
      end
      if (oclc_resolved.map(&:to_i) &
          Series::StatisticalAbstract.oclcs).any?
        @series << 'StatisticalAbstract'
      end
      if (oclc_resolved.map(&:to_i) &
         Series::UnitedStatesReports.oclcs).any? ||
         sudocs
         .grep(%r{^#{::Regexp
                        .escape(Series::UnitedStatesReports.sudoc_stem)}}).any?
        @series << 'UnitedStatesReports'
      end
      if sudocs
         .grep(%r{^#{::Regexp
                        .escape(Series::CivilRightsCommission.sudoc_stem)}})
         .any?
        @series << 'CivilRightsCommission'
      end
      if (oclc_resolved.map(&:to_i) &
          Series::CongressionalRecord.oclcs).any?
        @series << 'CongressionalRecord'
      end
      if sudocs
         .grep(/^#{::Regexp.escape(Series::ForeignRelations.sudoc_stem)}/)
         .any?
        @series << 'ForeignRelations'
      end
      if (oclc_resolved.map(&:to_i) &
          Series::CongressionalSerialSet.oclcs).any? ||
         sudocs
         .grep(%r{^#{::Regexp
                        .escape(Series::CongressionalSerialSet.sudoc_stem)}})
         .any?
        @series << 'CongressionalSerialSet'
      end
      if (oclc_resolved.map(&:to_i) &
          Series::EconomicReportOfThePresident.oclcs).any? ||
         sudocs
         .grep(%r{^#{::Regexp
                        .escape(Series::EconomicReportOfThePresident
                                .sudoc_stem)}}).any?
        @series << 'EconomicReportOfThePresident'
      end
      if (oclc_resolved.map(&:to_i) &
          Series::ReportsOfInvestigations.oclcs).any?
        @series << 'ReportsOfInvestigations'
      end
      if (oclc_resolved.map(&:to_i) &
          Series::DecisionsOfTheCourtOfVeteransAppeals.oclcs).any?
        @series << 'DecisionsOfTheCourtOfVeteransAppeals'
      end
      if (oclc_resolved.map(&:to_i) &
          Series::JournalOfTheNationalCancerInstitute.oclcs).any?
        @series << 'JournalOfTheNationalCancerInstitute'
      end
      if (oclc_resolved.map(&:to_i) &
          Series::CancerTreatmentReport.oclcs).any?
        @series << 'CancerTreatmentReport'
      end
      if (oclc_resolved.map(&:to_i) &
          Series::VitalStatistics.oclcs).any?
        @series << 'VitalStatistics'
      end
      if (oclc_resolved.map(&:to_i) &
          Series::PublicPapersOfThePresidents.oclcs).any?
        @series << 'PublicPapersOfThePresidents'
      end
      if (oclc_resolved.map(&:to_i) &
          Series::DepartmentOfAgricultureLeaflet.oclcs).any?
        @series << 'DepartmentOfAgricultureLeaflet'
      end
      if (oclc_resolved.map(&:to_i) &
          Series::PublicHealthReports.oclcs).any?
        @series << 'PublicHealthReports'
      end
      if (oclc_resolved.map(&:to_i) &
          Series::WarOfTheRebellion.oclcs).any?
        @series << 'WarOfTheRebellion'
      end
      if (oclc_resolved.map(&:to_i) &
          Series::CensusOfManufactures.oclcs).any?
        @series << 'CensusOfManufactures'
      end
      if (oclc_resolved.map(&:to_i) &
          Series::USExports.oclcs).any?
        @series << 'USExports'
      end
      if (oclc_resolved.map(&:to_i) &
          Series::CurrentPopulationReport.oclcs).any?
        @series << 'CurrentPopulationReport'
      end

      if @series&.any?
        @series.uniq!
        extend(Module.const_get('Registry::Series::' + @series.first))
        load_context
      end
      # get whatever we got
      super
      @series
    end
  end
end
