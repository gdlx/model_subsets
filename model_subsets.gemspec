# -*- encoding: utf-8 -*-
require File.expand_path('../lib/model_subsets/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Gauthier Delacroix"]
  gem.email         = ["gauthier.delacroix@gmail.com"]
  gem.description   = %q{ModelSubsets provides ability to split a single model into fields and properties subsets}
  gem.summary       = %q{Subsets management for Rails models}
  gem.homepage      = "https://github.com/porecreat/model_subsets"

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "model_subsets"
  gem.require_paths = ["lib"]
  gem.version       = ModelSubsets::VERSION

  gem.add_dependency("mongoid", ["~> 3.0.0"])
  
end
