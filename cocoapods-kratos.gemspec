# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'cocoapods_kratos.rb'

Gem::Specification.new do |spec|
  spec.name          = 'cocoapods-kratos'
  spec.version       = Pod::Kratos::VERSION
  spec.authors       = ['JiangChencheng']
  spec.email         = ['jiangchencheng0409@gmail.com']
  spec.description   = %q{A short description of cocoapods-kratos.}
  spec.summary       = %q{A longer description of cocoapods-kratos.}
  spec.homepage      = 'https://github.com/EXAMPLE/cocoapods-kratos'
  spec.license       = 'MIT'

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_dependency "cocoapods", '>= 1.7.3', '< 2.0'

  spec.add_development_dependency 'bundler', '~> 1.3'
  spec.add_development_dependency 'rake'
end
