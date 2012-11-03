# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "elibri_watermarking/version"

Gem::Specification.new do |s|
  s.name        = "elibri_watermarking"
  s.version     = ElibriWatermarking::VERSION
  s.authors     = ["Piotr Szmielew", "Tomasz Meka"]
  s.email       = ["p.szmielew@ava.waw.pl", "tomek@elibri.com.pl"]
  s.homepage    = "http://elibri.com.pl"
  s.summary     = %q{Gem designed to help in use of Elibri watermarking API.}
  s.description = %q{Gem designed to help in use of Elibri watermarking API.}

  s.rubyforge_project = "elibri_watermarking"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # specify any dependencies here; for example:
  s.add_development_dependency "rake"
  s.add_runtime_dependency "net-dns"
end
