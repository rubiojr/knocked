Gem::Specification.new do |s|
  s.name = %q{knocked}
  s.version = "0.3.1"

  s.specification_version = 2 if s.respond_to? :specification_version=

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Sergio Rubio <sergio@rubio.name"]
  s.date = %q{2008-09-12}
  #s.default_executable = %q{foo}
  s.description = %q{Apache Logs Toolkit}
  s.summary = %q{Library and utilities to interface with Satec Gestion DNS  webapp}
  s.email = %q{sergio@rubio.name}
  s.executables = [ "knocked" ]
  #s.extra_rdoc_files = ["README", "COPYING"]
  #s.has_rdoc = true
  s.homepage = %q{http://www.github.com/rubiojr/knocked}
  s.require_paths = ["lib"]
  s.required_ruby_version = Gem::Requirement.new(">= 1.8.4")
  s.add_dependency(%q<hpricot>, [">= 0.6"])
  s.add_dependency(%q<mechanize>, [">= 0.8"])
  s.add_dependency(%q<cmdparse>, [">= 2"])
  s.add_dependency(%q<highline>, [">= 1.4.0"])
  s.files = Dir["lib/*.rb"] 
end
