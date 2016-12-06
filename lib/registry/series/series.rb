# given a starting year with 4 digits and an ending year with 2 or 3 digits,
# figure out the century and millenium
def calc_end_year start_year, end_year
  start_year = start_year.to_str
  end_year = end_year.to_str
  if /^\d\d$/.match(end_year)
    if end_year.to_i < start_year[2,2].to_i
      # crosses century. e.g. 1998-01
      end_year = (start_year[0,2].to_i + 1).to_s + end_year
    else
      end_year = start_year[0,2]+end_year
    end
  elsif /^\d\d\d$/.match(end_year)
    if end_year.to_i < 700 #add a 2; 1699 and 2699 are both wrong, but...
      end_year = '2'+end_year
    else
      end_year = '1'+end_year
    end
  end
  end_year
end
