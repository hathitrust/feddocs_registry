def calc_end_year start_year, end_year
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
