lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'registry/version'

Gem::Specification.new do |spec|
  spec.name          = "registry"
  spec.version       = "0.1"
  spec.authors       = ["Josh Steverman"]
  spec.email         = ["jstever@umich.edu"]
  spec.description   = "Registry Mongoid classes."
  spec.summary       = ""
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")

end
