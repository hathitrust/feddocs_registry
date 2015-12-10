lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'registry/version'

Gem::Specification.new do |spec|
  spec.name          = "registry"
  spec.version       = Registry::VERSION 
  spec.authors       = ["Josh Steverman"]
  spec.email         = ["jstever@umich.edu"]
  spec.description   = "Registry Mongoid classes."
  spec.summary       = ""
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split($/)

  spec.add_dependency 'multi_json'
  spec.add_dependency 'mongoid'
  spec.add_dependency 'rspec'
  spec.add_dependency 'dotenv'
  spec.add_dependency 'marc'
  spec.add_dependency 'traject'
  spec.add_dependency 'normalize'
  spec.add_dependency 'viaf'
  spec.add_dependency 'library_stdnums', '~> 1.0.2'
  spec.add_dependency 'mysql2'

end
