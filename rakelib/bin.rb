#--------------------------------------------------------------------
# bin.rb - build file
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

module R2CORBA

  module Bin

    def self.ridlc
      <<_SH_TXT
#!#{Config.is_win32 ? '/bin/' : (`which env`).strip+' '}#{R2CORBA::RB_CONFIG['ruby_install_name']}
#---------------------------------
# This file is generated
#---------------------------------
ENV['RIDL_BE_SELECT'] = 'ruby'
unless defined? Gem
  require 'rubygems' rescue nil
end
require 'ridl/ridl'

IDL.run
_SH_TXT
    end

    def self.ridlc_bat
      <<_BAT_TXT
@echo off
if not "%~f0" == "~f0" goto WinNT
#{R2CORBA::RB_CONFIG['ruby_install_name']} -Sx "%0" %1 %2 %3 %4 %5 %6 %7 %8 %9
goto endofruby
:WinNT
if not exist "%~d0%~p0#{R2CORBA::RB_CONFIG['ruby_install_name']}" goto rubyfrompath
if exist "%~d0%~p0#{R2CORBA::RB_CONFIG['ruby_install_name']}" "%~d0%~p0#{R2CORBA::RB_CONFIG['ruby_install_name']}" -x "%~f0" %*
goto endofruby
:rubyfrompath
#{R2CORBA::RB_CONFIG['ruby_install_name']} -x "%~f0" %*
goto endofruby
#!/bin/#{R2CORBA::RB_CONFIG['ruby_install_name']}
#
ENV['RIDL_BE_SELECT'] = 'ruby'
unless defined? Gem
  require 'rubygems' rescue nil
end
require 'ridl/ridl'

IDL.run

__END__
:endofruby
_BAT_TXT
    end

    def self.rins_bat
      <<_BAT_TXT
@echo off
if not "%~f0" == "~f0" goto WinNT
#{R2CORBA::RB_CONFIG['ruby_install_name']} -Sx "%0" %1 %2 %3 %4 %5 %6 %7 %8 %9
goto endofruby
:WinNT
if not exist "%~d0%~p0#{R2CORBA::RB_CONFIG['ruby_install_name']}" goto rubyfrompath
if exist "%~d0%~p0#{R2CORBA::RB_CONFIG['ruby_install_name']}" "%~d0%~p0#{R2CORBA::RB_CONFIG['ruby_install_name']}" -x "%~f0" %*
goto endofruby
:rubyfrompath
#{R2CORBA::RB_CONFIG['ruby_install_name']} -x "%~f0" %*
goto endofruby
#!/bin/#{R2CORBA::RB_CONFIG['ruby_install_name']}
#
require 'corba/svcs/ins/ins'

INS.run

__END__
:endofruby
_BAT_TXT
    end

    def self.rins
      <<_SH_TXT
#!#{Config.is_win32 ? '/bin/' : (`which env`).strip+' '}#{R2CORBA::RB_CONFIG['ruby_install_name']}
#---------------------------------
# This file is generated
#---------------------------------
require 'corba/svcs/ins/ins'

INS.run
_SH_TXT
    end

    def self.r2corba
      <<_SH_TXT
#!#{Config.is_win32 ? '/bin/' : (`which env`).strip+' '}#{R2CORBA::RB_CONFIG['ruby_install_name']}
#---------------------------------
# This file is generated
#---------------------------------
unless defined? Gem
  require 'rubygems' rescue nil
end
require 'corba/cmds/base'
_SH_TXT
    end

    def self.r2corba_bat
      <<_BAT_TXT
@echo off
if not "%~f0" == "~f0" goto WinNT
#{R2CORBA::RB_CONFIG['ruby_install_name']} -Sx "%0" %1 %2 %3 %4 %5 %6 %7 %8 %9
goto endofruby
:WinNT
if not exist "%~d0%~p0#{R2CORBA::RB_CONFIG['ruby_install_name']}" goto rubyfrompath
if exist "%~d0%~p0#{R2CORBA::RB_CONFIG['ruby_install_name']}" "%~d0%~p0#{R2CORBA::RB_CONFIG['ruby_install_name']}" -x "%~f0" %*
goto endofruby
:rubyfrompath
#{R2CORBA::RB_CONFIG['ruby_install_name']} -x "%~f0" %*
goto endofruby
#!/bin/#{R2CORBA::RB_CONFIG['ruby_install_name']}
#
unless defined? Gem
  require 'rubygems' rescue nil
end
require 'corba/cmds/base'

__END__
:endofruby
_BAT_TXT
    end

    def self.binaries
      l = %w{ridlc rins r2corba}
      l.concat %w{ridlc.bat rins.bat r2corba.bat} if R2CORBA::Config.is_win32 || defined?(JRUBY_VERSION)
      l
    end

  end # Bin

end # R2CORBA