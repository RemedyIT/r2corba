#--------------------------------------------------------------------
# config.rake - build file
#
# Author: Martin Corino
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the R2CORBA LICENSE which is
# included with this program.
#
# Copyright (c) Remedy IT Expertise BV
# Chamber of commerce Rotterdam nr.276339, The Netherlands
#--------------------------------------------------------------------

require File.join(File.dirname(__FILE__), 'config.rb')

namespace :r2corba do
  task :configure  do
    R2CORBA::Config.define
    R2CORBA::Config.check
    R2CORBA::Config.save
    # find out if more tasks were specified to run after configure
    while ARGV.shift.to_s =~ /^(r2corba:)?configure$/ do; end
    # if so start a new rake process to run these
    unless ARGV.empty?
      # restarting ensures correct loading of config and the tasks that depend on that
      exec('rake', *ARGV)
    end
  end

  namespace :config do
    task :show do
      R2CORBA::CFGKEYS.each do |ck|
        puts "%20s => %s" % [ck, get_config(ck)]
      end
    end
  end
end

desc 'Configure R2CORBA build settings (calling with "-- --help" provides usage information).'
task :configure => 'r2corba:configure'

desc 'Show current R2CORBA build settings'
task :show => 'r2corba:config:show'

file R2CORBA::BUILD_CFG do
  unless File.file?(R2CORBA::BUILD_CFG)
    STDERR.puts "Build configuration missing! First run 'rake r2corba::configure'."
    exit(1)
  end
end

CLOBBER.include R2CORBA::BUILD_CFG