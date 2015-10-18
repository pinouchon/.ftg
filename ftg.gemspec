# coding: utf-8
# lib = File.expand_path('../lib', __FILE__)
# $LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
# require 'ftg/version'

Gem::Specification.new do |spec|
  spec.name          = "ftg"
  spec.version       = '2.0'#Ftg::VERSION
  spec.authors       = ["pinouchon"]
  spec.email         = ["pinouchon@gmail.com"]

  spec.summary       = %q{Toggl replacement}
  spec.description   = %q{Toggl replacement. Time tracking based on git branches}
  spec.homepage      = "https://github.com/pinouchon/.ftg"
  spec.license       = "MIT"

  # Prevent pushing this gem to RubyGems.org by setting 'allowed_push_host', or
  # delete this section to allow pushing this gem to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = "https://rubygems.org"
  else
    raise "RubyGems 2.0 or newer is required to protect against public gem pushes."
  end

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "bin"
  spec.executables   = ["ftg"]  #spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.10"
  spec.add_development_dependency "rake", "~> 10.0"
end
