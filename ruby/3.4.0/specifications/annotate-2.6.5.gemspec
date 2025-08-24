# -*- encoding: utf-8 -*-
# stub: annotate 2.6.5 ruby lib

Gem::Specification.new do |s|
  s.name = "annotate".freeze
  s.version = "2.6.5".freeze

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Cuong Tran".freeze, "Alex Chaffee".freeze, "Marcos Piccinini".freeze, "Turadg Aleahmad".freeze, "Jon Frisby".freeze]
  s.date = "2014-06-16"
  s.description = "Annotates Rails/ActiveRecord Models, routes, fixtures, and others based on the database schema.".freeze
  s.email = ["alex@stinky.com".freeze, "cuong.tran@gmail.com".freeze, "x@nofxx.com".freeze, "turadg@aleahmad.net".freeze, "jon@cloudability.com".freeze]
  s.executables = ["annotate".freeze]
  s.extra_rdoc_files = ["README.rdoc".freeze, "CHANGELOG.rdoc".freeze, "TODO.rdoc".freeze]
  s.files = ["CHANGELOG.rdoc".freeze, "README.rdoc".freeze, "TODO.rdoc".freeze, "bin/annotate".freeze]
  s.homepage = "http://github.com/ctran/annotate_models".freeze
  s.licenses = ["Ruby".freeze]
  s.rubygems_version = "2.3.0".freeze
  s.summary = "Annotates Rails Models, routes, fixtures, and others based on the database schema.".freeze

  s.installed_by_version = "3.6.3".freeze

  s.specification_version = 4

  s.add_runtime_dependency(%q<rake>.freeze, [">= 0.8.7".freeze])
  s.add_runtime_dependency(%q<activerecord>.freeze, [">= 2.3.0".freeze])
end
