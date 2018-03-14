# -*- encoding: utf-8 -*-
# stub: assemblage 0.1.pre20180313164245 ruby lib

Gem::Specification.new do |s|
  s.name = "assemblage".freeze
  s.version = "0.1.pre20180313164245"

  s.required_rubygems_version = Gem::Requirement.new("> 1.3.1".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Michael Granger".freeze]
  s.cert_chain = ["certs/ged.pem".freeze]
  s.date = "2018-03-13"
  s.description = "Assemblage is a continuous integration toolkit. It's intended to provide you\nwith a minimal infrastructure for distributing and performing automated tasks\nfor one or more version control repositories. It makes as few assumptions as\npossible as to what those things might be.\n\nIt's still just a personal project, but if you want to use it I'm happy to\nanswer questions and entertain suggestions, especially in the form of\npatches/PRs.".freeze
  s.email = ["ged@FaerieMUD.org".freeze]
  s.extra_rdoc_files = ["README.md".freeze, "History.md".freeze, "README.md".freeze]
  s.files = [".simplecov".freeze, "ChangeLog".freeze, "History.md".freeze, "README.md".freeze, "Rakefile".freeze, "lib/assemblage.rb".freeze, "spec/assemblage_spec.rb".freeze, "spec/spec_helper.rb".freeze]
  s.homepage = "home".freeze
  s.licenses = ["BSD-3-Clause".freeze]
  s.rdoc_options = ["--main".freeze, "README.md".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 2.3.4".freeze)
  s.rubygems_version = "2.7.4".freeze
  s.summary = "Assemblage is a continuous integration toolkit".freeze

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<loggability>.freeze, ["~> 0.11"])
      s.add_runtime_dependency(%q<hglib>.freeze, ["~> 0.1"])
      s.add_runtime_dependency(%q<git>.freeze, ["~> 1.3"])
      s.add_runtime_dependency(%q<gli>.freeze, ["~> 2.17"])
      s.add_runtime_dependency(%q<tty>.freeze, ["~> 0.7"])
      s.add_runtime_dependency(%q<cztop-reactor>.freeze, ["~> 0.3"])
      s.add_development_dependency(%q<hoe-mercurial>.freeze, ["~> 1.4"])
      s.add_development_dependency(%q<hoe-deveiate>.freeze, ["~> 0.9"])
      s.add_development_dependency(%q<hoe-highline>.freeze, ["~> 0.2"])
      s.add_development_dependency(%q<simplecov>.freeze, ["~> 0.7"])
      s.add_development_dependency(%q<rdoc-generator-fivefish>.freeze, ["~> 0.1"])
      s.add_development_dependency(%q<rdoc>.freeze, ["~> 4.0"])
      s.add_development_dependency(%q<hoe>.freeze, ["~> 3.16"])
    else
      s.add_dependency(%q<loggability>.freeze, ["~> 0.11"])
      s.add_dependency(%q<hglib>.freeze, ["~> 0.1"])
      s.add_dependency(%q<git>.freeze, ["~> 1.3"])
      s.add_dependency(%q<gli>.freeze, ["~> 2.17"])
      s.add_dependency(%q<tty>.freeze, ["~> 0.7"])
      s.add_dependency(%q<cztop-reactor>.freeze, ["~> 0.3"])
      s.add_dependency(%q<hoe-mercurial>.freeze, ["~> 1.4"])
      s.add_dependency(%q<hoe-deveiate>.freeze, ["~> 0.9"])
      s.add_dependency(%q<hoe-highline>.freeze, ["~> 0.2"])
      s.add_dependency(%q<simplecov>.freeze, ["~> 0.7"])
      s.add_dependency(%q<rdoc-generator-fivefish>.freeze, ["~> 0.1"])
      s.add_dependency(%q<rdoc>.freeze, ["~> 4.0"])
      s.add_dependency(%q<hoe>.freeze, ["~> 3.16"])
    end
  else
    s.add_dependency(%q<loggability>.freeze, ["~> 0.11"])
    s.add_dependency(%q<hglib>.freeze, ["~> 0.1"])
    s.add_dependency(%q<git>.freeze, ["~> 1.3"])
    s.add_dependency(%q<gli>.freeze, ["~> 2.17"])
    s.add_dependency(%q<tty>.freeze, ["~> 0.7"])
    s.add_dependency(%q<cztop-reactor>.freeze, ["~> 0.3"])
    s.add_dependency(%q<hoe-mercurial>.freeze, ["~> 1.4"])
    s.add_dependency(%q<hoe-deveiate>.freeze, ["~> 0.9"])
    s.add_dependency(%q<hoe-highline>.freeze, ["~> 0.2"])
    s.add_dependency(%q<simplecov>.freeze, ["~> 0.7"])
    s.add_dependency(%q<rdoc-generator-fivefish>.freeze, ["~> 0.1"])
    s.add_dependency(%q<rdoc>.freeze, ["~> 4.0"])
    s.add_dependency(%q<hoe>.freeze, ["~> 3.16"])
  end
end