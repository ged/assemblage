# -*- encoding: utf-8 -*-
# stub: assemblage 0.1.pre20180430162426 ruby lib

Gem::Specification.new do |s|
  s.name = "assemblage".freeze
  s.version = "0.1.pre20180430162426"

  s.required_rubygems_version = Gem::Requirement.new("> 1.3.1".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Michael Granger".freeze]
  s.cert_chain = ["certs/ged.pem".freeze]
  s.date = "2018-04-30"
  s.description = "Assemblage is a continuous integration library. It's intended to provide you\nwith a minimal toolkit for distributing and performing automated tasks\nfor one or more version control repositories. It makes as few assumptions as\npossible as to what those tasks might be.\n\nA task in Assemblage is called an Assembly. Assemblage has three primary parts for manipulating Assemblies: the **Assembly Server**, **Assembly\nWorkers**, and **Repositories**.\n\n<dl>\n  <dt>Assembly Server</dt>\n  <dd>Aggregates and distributes events from <em>repositories</em> to\n  <em>workers</em> via one or more \"assemblies\".</dd>\n\n  <dt>Assembly Workers</dt>\n  <dd>Listens for events published by the <em>assembly server</em>, checks out\n  a <em>repository</em>, and runs an assembly script in that repository.</dd>\n\n  <dt>Repository</dt>\n  <dd>A distributed version control repository. Assemblage currently supports\n  Mercurial and Git.</dd>\n</dl>".freeze
  s.email = ["ged@FaerieMUD.org".freeze]
  s.executables = ["assemblage".freeze]
  s.extra_rdoc_files = ["History.md".freeze, "LICENSE.txt".freeze, "Manifest.txt".freeze, "README.md".freeze, "History.md".freeze, "Protocol.md".freeze, "README.md".freeze]
  s.files = [".document".freeze, ".editorconfig".freeze, ".rdoc_options".freeze, ".simplecov".freeze, "ChangeLog".freeze, "History.md".freeze, "LICENSE.txt".freeze, "Manifest.txt".freeze, "Protocol.md".freeze, "README.md".freeze, "Rakefile".freeze, "bin/assemblage".freeze, "data/assemblage/migrations/20180314_initial.rb".freeze, "lib/assemblage.rb".freeze, "lib/assemblage/auth.rb".freeze, "lib/assemblage/cli.rb".freeze, "lib/assemblage/client.rb".freeze, "lib/assemblage/command/add.rb".freeze, "lib/assemblage/command/create.rb".freeze, "lib/assemblage/command/start.rb".freeze, "lib/assemblage/db_object.rb".freeze, "lib/assemblage/mixins.rb".freeze, "lib/assemblage/protocol.rb".freeze, "lib/assemblage/server.rb".freeze, "lib/assemblage/worker.rb".freeze, "spec/.status".freeze, "spec/assemblage/auth_spec.rb".freeze, "spec/assemblage/mixins_spec.rb".freeze, "spec/assemblage/server_spec.rb".freeze, "spec/assemblage/worker_spec.rb".freeze, "spec/assemblage_spec.rb".freeze, "spec/spec_helper.rb".freeze]
  s.homepage = "https://assembla.ge/".freeze
  s.licenses = ["BSD-3-Clause".freeze]
  s.rdoc_options = ["--main".freeze, "README.md".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 2.3.4".freeze)
  s.rubygems_version = "2.7.4".freeze
  s.summary = "Assemblage is a continuous integration library".freeze

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<loggability>.freeze, ["~> 0.11"])
      s.add_runtime_dependency(%q<configurability>.freeze, ["~> 3.2"])
      s.add_runtime_dependency(%q<hglib>.freeze, ["~> 0"])
      s.add_runtime_dependency(%q<git>.freeze, ["~> 1.3"])
      s.add_runtime_dependency(%q<gli>.freeze, ["~> 2.17"])
      s.add_runtime_dependency(%q<tty>.freeze, ["~> 0.7"])
      s.add_runtime_dependency(%q<sequel>.freeze, ["~> 5.6"])
      s.add_runtime_dependency(%q<msgpack>.freeze, ["~> 1.2"])
      s.add_runtime_dependency(%q<state_machines>.freeze, ["~> 0.5"])
      s.add_runtime_dependency(%q<cztop-reactor>.freeze, ["~> 0.3"])
      s.add_development_dependency(%q<hoe-mercurial>.freeze, ["~> 1.4"])
      s.add_development_dependency(%q<hoe-deveiate>.freeze, ["~> 0.10"])
      s.add_development_dependency(%q<hoe-highline>.freeze, ["~> 0.2"])
      s.add_development_dependency(%q<simplecov>.freeze, ["~> 0.7"])
      s.add_development_dependency(%q<rdoc-generator-fivefish>.freeze, ["~> 0.4"])
      s.add_development_dependency(%q<rdoc>.freeze, ["~> 6.0"])
      s.add_development_dependency(%q<sqlite3>.freeze, ["~> 1.3"])
      s.add_development_dependency(%q<rspec-wait>.freeze, ["~> 0.0"])
      s.add_development_dependency(%q<hoe>.freeze, ["~> 3.17"])
    else
      s.add_dependency(%q<loggability>.freeze, ["~> 0.11"])
      s.add_dependency(%q<configurability>.freeze, ["~> 3.2"])
      s.add_dependency(%q<hglib>.freeze, ["~> 0"])
      s.add_dependency(%q<git>.freeze, ["~> 1.3"])
      s.add_dependency(%q<gli>.freeze, ["~> 2.17"])
      s.add_dependency(%q<tty>.freeze, ["~> 0.7"])
      s.add_dependency(%q<sequel>.freeze, ["~> 5.6"])
      s.add_dependency(%q<msgpack>.freeze, ["~> 1.2"])
      s.add_dependency(%q<state_machines>.freeze, ["~> 0.5"])
      s.add_dependency(%q<cztop-reactor>.freeze, ["~> 0.3"])
      s.add_dependency(%q<hoe-mercurial>.freeze, ["~> 1.4"])
      s.add_dependency(%q<hoe-deveiate>.freeze, ["~> 0.10"])
      s.add_dependency(%q<hoe-highline>.freeze, ["~> 0.2"])
      s.add_dependency(%q<simplecov>.freeze, ["~> 0.7"])
      s.add_dependency(%q<rdoc-generator-fivefish>.freeze, ["~> 0.4"])
      s.add_dependency(%q<rdoc>.freeze, ["~> 6.0"])
      s.add_dependency(%q<sqlite3>.freeze, ["~> 1.3"])
      s.add_dependency(%q<rspec-wait>.freeze, ["~> 0.0"])
      s.add_dependency(%q<hoe>.freeze, ["~> 3.17"])
    end
  else
    s.add_dependency(%q<loggability>.freeze, ["~> 0.11"])
    s.add_dependency(%q<configurability>.freeze, ["~> 3.2"])
    s.add_dependency(%q<hglib>.freeze, ["~> 0"])
    s.add_dependency(%q<git>.freeze, ["~> 1.3"])
    s.add_dependency(%q<gli>.freeze, ["~> 2.17"])
    s.add_dependency(%q<tty>.freeze, ["~> 0.7"])
    s.add_dependency(%q<sequel>.freeze, ["~> 5.6"])
    s.add_dependency(%q<msgpack>.freeze, ["~> 1.2"])
    s.add_dependency(%q<state_machines>.freeze, ["~> 0.5"])
    s.add_dependency(%q<cztop-reactor>.freeze, ["~> 0.3"])
    s.add_dependency(%q<hoe-mercurial>.freeze, ["~> 1.4"])
    s.add_dependency(%q<hoe-deveiate>.freeze, ["~> 0.10"])
    s.add_dependency(%q<hoe-highline>.freeze, ["~> 0.2"])
    s.add_dependency(%q<simplecov>.freeze, ["~> 0.7"])
    s.add_dependency(%q<rdoc-generator-fivefish>.freeze, ["~> 0.4"])
    s.add_dependency(%q<rdoc>.freeze, ["~> 6.0"])
    s.add_dependency(%q<sqlite3>.freeze, ["~> 1.3"])
    s.add_dependency(%q<rspec-wait>.freeze, ["~> 0.0"])
    s.add_dependency(%q<hoe>.freeze, ["~> 3.17"])
  end
end
