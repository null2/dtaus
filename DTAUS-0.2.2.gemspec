# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = "DTAUS"
  s.version = "0.2.2"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Knut Lickert"]
  s.date = "2010-05-22"
  s.description = "Build DTAUS-Files.\n\nDTAUS is a data medium exchange file for Banks in Germany. It can be used for Direct debit.\nThis version is ruby 1.9-enabled.\n\nDetails see http://ruby.lickert.net/dtaus/ (German)\n"
  s.email = "knut@lickert.net"
  s.homepage = "http://ruby.lickert.net/dtaus"
  s.require_paths = ["lib"]
  s.requirements = ["Optional: A (La)TeX-system if used as TeX-generator (in fact, you can create TeX-Files, but without a TeX-System you will have no fun with it ;-))"]
  s.rubyforge_project = "dtaus"
  s.rubygems_version = "1.8.10"
  s.summary = "Build DTAUS-Files."

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_development_dependency(%q<more_unit_test>, ["> 0.0.2"])
    else
      s.add_dependency(%q<more_unit_test>, ["> 0.0.2"])
    end
  else
    s.add_dependency(%q<more_unit_test>, ["> 0.0.2"])
  end
end
