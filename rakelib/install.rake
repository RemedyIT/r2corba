#--------------------------------------------------------------------
# install.rake - build file
#
# Author: Martin Corino
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the R2CORBA LICENSE which is
# included with this program.
#
# Copyright (c) Remedy IT Expertise BV
#--------------------------------------------------------------------

require File.join(File.dirname(__FILE__), 'install.rb')

namespace :r2corba do
  task :install => [R2CORBA::BUILD_CFG, 'r2corba:build'] do
    R2CORBA::Install.define('install')
    R2CORBA::Install.nowrite(ENV['NO_HARM'] ? true : false) do
      R2CORBA::Install.install
    end
  end
  task :uninstall => [R2CORBA::BUILD_CFG] do
    R2CORBA::Install.define('uninstall')
    R2CORBA::Install.nowrite(ENV['NO_HARM'] ? true : false) do
      R2CORBA::Install.uninstall
    end
  end
end

desc 'Install R2CORBA (calling with "-- --help" provides usage information).'
task :install => 'r2corba:install'

desc 'Uninstall R2CORBA (calling with "-- --help" provides usage information).'
task :uninstall => 'r2corba:uninstall'
