# coding: utf-8
# lib = File.expand_path('../lib', __FILE__)
# $LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
# require 'ftg/version'

Gem::Specification.new do |spec|
  spec.name          = 'ftg'
  spec.version       = '2.1.3'#Ftg::VERSION
  spec.authors       = ['pinouchon']
  spec.email         = ['pinouchon@gmail.com']

  spec.summary       = %q{Toggl replacement}
  spec.description   = %q{Toggl replacement. Time tracking based on git branches}
  spec.homepage      = 'https://github.com/pinouchon/.ftg'
  spec.license       = 'MIT'

  # Prevent pushing this gem to RubyGems.org by setting 'allowed_push_host', or
  # delete this section to allow pushing this gem to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = 'https://rubygems.org'
  else
    raise 'RubyGems 2.0 or newer is required to protect against public gem pushes.'
  end

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = 'bin'
  spec.executables   = ['ftg']  #spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib/ftg']

  spec.add_development_dependency 'bundler', '~> 1.10'
  spec.add_development_dependency 'rake', '~> 10.0'

  spec.add_runtime_dependency 'httparty', '>= 0.13.7'
  spec.add_runtime_dependency 'pry', '>= 0.10.2'
  spec.add_runtime_dependency 'activerecord', '>= 4.0.13'
  spec.add_runtime_dependency 'sqlite3', '>= 1.3.11'
  spec.add_runtime_dependency 'json', '>= 1.8.3'
  spec.add_runtime_dependency 'awesome_print', '>= 1.3.11'
end
