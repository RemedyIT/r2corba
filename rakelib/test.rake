#--------------------------------------------------------------------
# test.rake - build file
#
# Author: Martin Corino
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the R2CORBA LICENSE which is
# included with this program.
#
# Copyright (c) Remedy IT Expertise BV
#--------------------------------------------------------------------

require File.join(File.dirname(__FILE__), 'config.rb')

namespace :r2corba do
  task :test => [R2CORBA::BUILD_CFG, 'r2corba:build'] do
    ruby(File.join('test', 'test_runner.rb'))
  end
end

desc 'Run R2CORBA tests'
task :test => 'r2corba:test'
