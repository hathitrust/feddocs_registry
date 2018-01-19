# frozen_string_literal: true

module Normalize
  def self.normalize_title(str)
    # trims punctuation after a closing paren and removes duplicate spaces
    str.sub(/\)\.\Z/, ')').gsub(/ {2,}/, ' ')
  end
end
