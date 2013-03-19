# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'binary/protocol/version'

Gem::Specification.new do |spec|
  spec.name          = "binary-protocol"
  spec.version       = Binary::Protocol::VERSION
  spec.authors       = ["Andrew Bennett"]
  spec.email         = ["andrew@pagodabox.com"]
  spec.description   = %q{Helpful DSL for reading and writing binary protocols}
  spec.summary       = %q{Helpful DSL for reading and writing binary protocols}
  spec.homepage      = "https://github.com/potatosalad/binary-protocol"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "rake"
end
