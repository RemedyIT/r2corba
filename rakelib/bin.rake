#--------------------------------------------------------------------
# bin.rake - build file
#
# Author: Martin Corino
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the R2CORBA LICENSE which is
# included with this program.
#
# Copyright (c) Remedy IT Expertise BV
#--------------------------------------------------------------------

require File.join(File.dirname(__FILE__), 'bin.rb')

directory 'bin'

file File.join('bin', 'ridlc') => ['bin'] do |t|
  File.open(t.name, 'w') { |f| f.puts R2CORBA::Bin.ridlc }
  File.chmod(0755, t.name)
end

CLOBBER.include File.join('bin', 'ridlc')

file File.join('bin', 'rins') => ['bin'] do |t|
  File.open(t.name, 'w') { |f| f.puts R2CORBA::Bin.rins }
  File.chmod(0755, t.name)
end

CLOBBER.include File.join('bin', 'rins')

file File.join('bin', 'r2corba') => ['bin'] do |t|
  File.open(t.name, 'w') { |f| f.puts R2CORBA::Bin.r2corba }
  File.chmod(0755, t.name)
end

CLOBBER.include File.join('bin', 'r2corba')

namespace :r2corba do
  #desc 'Generate R2CORBA executor scripts'
  namespace :bin do
    task :build => ['r2corba:bin:check', 'r2corba:bin:files']

    task :check do
      R2CORBA::Bin.binaries.each do |bin|
        if File.exist?(File.join('bin', bin))
          content = IO.read(File.join('bin', bin))
          rm_f(File.join('bin', bin)) unless content == R2CORBA::Bin.__send__(bin.gsub('.', '_').to_sym)
        end
      end
    end

    task :files => [File.join('bin', 'ridlc'), File.join('bin', 'rins'), File.join('bin', 'r2corba')]
  end
end

if R2CORBA::Config.is_win32 || defined?(JRUBY_VERSION)

  file File.join('bin', 'ridlc.bat') => ['bin'] do |t|
    File.open(t.name, 'w') { |f| f.puts R2CORBA::Bin.ridlc_bat }
  end
  Rake::Task['r2corba:bin:files'].enhance [File.join('bin', 'ridlc.bat')]

  CLOBBER.include File.join('bin', 'ridlc.bat')

  file File.join('bin', 'rins.bat') => ['bin'] do |t|
    File.open(t.name, 'w') { |f| f.puts R2CORBA::Bin.rins_bat }
  end
  Rake::Task['r2corba:bin:files'].enhance [File.join('bin', 'rins.bat')]

  CLOBBER.include File.join('bin', 'rins.bat')

  file File.join('bin', 'r2corba.bat') => ['bin'] do |t|
    File.open(t.name, 'w') { |f| f.puts R2CORBA::Bin.r2corba_bat }
  end
  Rake::Task['r2corba:bin:files'].enhance [File.join('bin', 'r2corba.bat')]

  CLOBBER.include File.join('bin', 'r2corba.bat')

end
