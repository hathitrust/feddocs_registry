require 'normalize'
require 'spec_helper'

N = Normalize
RSpec.describe N, '#normalize_title' do
  it 'replaces duplicated whitespace with one whitespace' do
    expect(N.normalize_title('Instructions and  Definitions')).to\
      eq('Instructions and Definitions')
  end

  it 'trims punctuation for the title field' do
    expect(N.normalize_title('July 2003, (CD-ROM).')).to\
      eq('July 2003, (CD-ROM)')
  end
end
