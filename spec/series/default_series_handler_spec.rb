DSH = Registry::Series::DefaultSeriesHandler

describe 'tokens' do
  it 'matches "OCT."' do
    expect(/#{DSH.new.tokens[:m]}/xi.match('OCT.')['month']).to eq('OCT.')
  end

  it 'matches "NO. 12-13"' do
    expect(/#{DSH.new.tokens[:ns]}/xi.match('NO. 12-13')['start_number']).to eq('12')
  end

  it 'matches "SUP."' do
    expect(/#{DSH.new.tokens[:sup]}/xi.match('SUP.')['supplement']).to eq('SUP.')
  end

  it 'y matches "YR. 1993"' do
    expect(/#{DSH.new.tokens[:y]}/xi.match('YR. 1993')['year']).to eq('1993')
  end
end


