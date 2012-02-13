# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "ant_hill/version"

Gem::Specification.new do |s|
  s.name        = "ant_hill"
  s.version     = AntHill::VERSION
  s.authors     = ["Ivan Neverov"]
  s.email       = ["ineverov@sphereconsultinginc.com"]
  s.homepage    = ""
  s.summary     = %q{Run tests in grip}
  s.description = %q{Run tests in grid}

  s.rubyforge_project = "ant_hill"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # specify any dependencies here; for example:
  # s.add_development_dependency "rspec"
  # s.add_runtime_dependency "rest-client"
end
