# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'toy/dynamo/version'

Gem::Specification.new do |spec|
  spec.name          = "toy-dynamo"
  spec.version       = Toy::Dynamo::VERSION
  spec.authors       = ["Cary Dunn"]
  spec.email         = ["cary.dunn@gmail.com"]
  spec.description   = %q{DynamoDB ORM - extension to toystore}
  spec.summary       = %q{DynamoDB ORM - extension to toystore}
  spec.homepage      = "https://github.com/cdunn/toy-dynamo"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"

  spec.add_dependency 'adapter', '~> 0.7.0'
  spec.add_dependency 'aws-sdk', '~> 1.9'
end
