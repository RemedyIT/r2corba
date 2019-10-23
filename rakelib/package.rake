#--------------------------------------------------------------------
# package.rake - build file
#
# Author: Martin Corino
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the R2CORBA LICENSE which is
# included with this program.
#
# Copyright (c) Remedy IT Expertise BV
#--------------------------------------------------------------------

require 'rake/packagetask'

require File.join(File.dirname(__FILE__), 'config.rb')

Rake::PackageTask.new("r2corba", R2CORBA::R2CORBA_VERSION) do |p|
  p.need_tar_gz = true
  p.need_zip = true
  p.package_files.include(%w{ext/**/*.{mwc,cpp,c,h}})
  p.package_files.include(%w{example/**/* lib/**/*[^C].* test/**/* rpmbuild/**/* rakelib/**/*})
  p.package_files.exclude(/GNUmakefile/)
  p.package_files.include(%w{CHANGES INSTALL* LICENSE* Gemfile Rakefile README.rdoc THANKS mkrf_conf*.rb})
  p.package_files.include(%w{ridl/lib/**/*}) if ENV['R2CORBA_PKG_RIDL']
end
