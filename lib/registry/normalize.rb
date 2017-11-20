module Normalize
  def self.normalize_title str
    str.sub(/\)\.\Z/, ')').gsub(/ {2,}/, ' ')
  end
end
