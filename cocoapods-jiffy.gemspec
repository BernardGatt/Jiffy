# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'cocoapods-jiffy/gem_version.rb'

Gem::Specification.new do |spec|
  spec.name          = "cocoapods-jiffy"
  spec.version       = CocoapodsJiffy::VERSION
  spec.authors       = ["Krunoslav Zaher"]
  spec.email         = ["krunoslav.zaher@gmail.com"]
  spec.summary       = "Builds your CocoaPods dependencies in a jiffy by building them as dynamic frameworks and caches them locally per xcode version, git commit, platform and configuration."
  spec.homepage      = "https://github.com/kzaher/Jiffy"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "cocoapods", ">= 1.1.0.beta.1", "< 2.0"
  spec.add_dependency "fourflusher", "~> 1.0.0"

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
end
