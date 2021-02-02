#--------------------------------------------------------------------
# ext.rb - build file
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
require File.join(File.dirname(__FILE__), 'ext_r2tao.rb')

module R2CORBA

  module Ext
    ACE_FILES = [
        'ACE',
        'TAO',
        'TAO_TypeCodeFactory',
        'TAO_IFR_Client',
        'TAO_DynamicInterface',
        'TAO_Messaging',
        'TAO_PI',
        'TAO_CodecFactory',
        'TAO_Codeset',
        'TAO_DynamicAny',
        'TAO_Valuetype',
        'TAO_PortableServer',
        'TAO_AnyTypeCode',
        'TAO_BiDirGIOP',
        'TAO_IORTable',
        'TAO_ImR_Client'
    ]

    if get_config('with-ssl')
      ACE_FILES << 'ACE_SSL'
      ACE_FILES << 'TAO_Security'
      ACE_FILES << 'TAO_SSLIOP'
    end

    def self.platform_error
      raise "Unsupported platform: #{RUBY_PLATFORM}."
    end

    def self.is_win32
      R2CORBA::Config.is_win32
    end
    def self.is_win64
      R2CORBA::Config.is_win64
    end

    if is_win32
      def self.sys_dlls
        sysdlls = []
        except_dll = R2CORBA::Config.is_win64 ? 'libgcc_s_seh-1.dll' : 'libgcc_s_dw2-1.dll'
        ENV['PATH'].split(';').each do |p|
          if File.exist?(File.join(p, except_dll)) && File.exist?(File.join(p, 'libstdc++-6.dll'))
            sysdlls << File.join(p, except_dll)
            sysdlls << File.join(p, 'libstdc++-6.dll')
            break
          end
        end
        sysdlls
      end
    end

    def self.so_ext
      if R2CORBA::Config.is_win32
        '.dll'
      elsif R2CORBA::Config.is_osx
        '.dylib'
      else
        '.so'
      end
    end

    def self.ace_shlibs(so_ext_ = nil, libdir = File.join(get_config('aceroot'), 'lib'))
      so_ext_ ||= self.so_ext
      ACE_FILES.collect { |fn| File.join(libdir, "lib#{fn}#{so_ext_}") }
    end

    def self.ace_config
      case RUBY_PLATFORM
        when /mingw32/
          %Q{
#define ACE_DISABLE_WIN32_ERROR_WINDOWS
#include "ace/config-win32.h"
}
        when /linux/
          %Q{
#include "ace/config-linux.h"
}
        when /sparc-solaris/
          %Q{
#define ACE_USES_STD_NAMESPACE_FOR_STDCPP_LIB 1
#include "ace/config-sunos5.10.h"
#undef ACE_HAS_NEW_NOTHROW
}
        when /darwin/
          %Q{
#include "ace/config-macosx.h"
}
        else
          platform_error
      end
    end

    def self.platform_macros
      case RUBY_PLATFORM
        when /mingw32/
          (is_win64 ? %Q{
TCPU:=generic
buildbits=64
} : '') + %Q{
threads=1
ssl=#{get_config('with-ssl') ? 1 : 0}
optimize=1
debug=#{get_config('with-debug') ? 1 : 0}
fl_reactor=0
tk_reactor=0
boost=0
include $(ACE_ROOT)/include/makeinclude/platform_mingw32.GNU
      }
        when /linux/
          %Q{
versioned_so=1
ssl=#{get_config('with-ssl') ? 1 : 0}
optimize=1
debug=#{get_config('with-debug') ? 1 : 0}
include $(ACE_ROOT)/include/makeinclude/platform_linux.GNU
LDFLAGS += -Wl,-rpath,#{get_config('aceinstdir')}
      }
        when /sparc-solaris/
          %Q{
threads=1
ssl=#{get_config('with-ssl') ? 1 : 0}
inline=0
optimize=0
debug=#{get_config('with-debug') ? 1 : 0}
fl_reactor=0
tk_reactor=0
no_hidden_visibility=1
#{ /^cc/i =~ RB_CONFIG['CC'] ? 'include $(ACE_ROOT)/include/makeinclude/platform_sunos5_sunc++.GNU' : 'include $(ACE_ROOT)/include/makeinclude/platform_sunos5_g++.GNU' }
LDFLAGS += #{RB_CONFIG['SOLIBS']} #{ /^cc/i =~ RB_CONFIG['CC'] ? '-lCrun -lCstd' : ''}
      }
        when /darwin/
          %Q{
threads=1
ssl=#{get_config('with-ssl') ? 1 : 0}
optimize=1
debug=#{get_config('with-debug') ? 1 : 0}
fl_reactor=0
tk_reactor=0
boost=0
include $(ACE_ROOT)/include/makeinclude/platform_macosx.GNU
LDFLAGS += -Wl,-headerpad_max_install_names
FLAGS_C_CC += #{RB_CONFIG['ARCH_FLAG']}
LDFLAGS    += #{RB_CONFIG['ARCH_FLAG']}
      }
        else
          platform_error
      end
    end

    def self.tao_mwc
      %Q{
workspace {
  $(ACE_ROOT)/ace
  $(ACE_ROOT)/apps/gperf/src
  $(TAO_ROOT)/TAO_IDL
  $(TAO_ROOT)/tao
  #{get_config('with-ssl') ? '$(TAO_ROOT)/orbsvcs/orbsvcs/Security.mpc' : ''}
  #{get_config('with-ssl') ? '$(TAO_ROOT)/orbsvcs/orbsvcs/SSLIOP.mpc' : ''}
  exclude {
    bin
    docs
    etc
    html
    include
    lib
    m4
    man
    contrib
    netsvcs
    websvcs
    protocols
    tests
    performance-tests
    examples
    Kokyu
    ASNMP
    ACEXML
  }
}
      }
    end

    def self.default_features
      %Q{
qos=0
ssl=#{get_config('with-ssl') ? 1 : 0}
ipv6=#{get_config('with-ipv6') ? 1 : 0}
       }
    end

    def self.ace_config_path
      File.join(get_config('aceroot'),'ace','config.h')
    end

    def self.platform_macros_path
      File.join(get_config('aceroot'),'include','makeinclude','platform_macros.GNU')
    end

    def self.default_features_path
      File.join(get_config('aceroot'),'bin','MakeProjectCreator','config','default.features')
    end

    def self.tao_mwc_path
      File.join(get_config('aceroot'),'TAO4Ruby.mwc')
    end

    def self.tao_makefile
      File.join(get_config('aceroot'),'GNUmakefile')
    end

    def self.ext_makefile
      File.join('ext', 'GNUmakefile')
    end

    def self.post_build
      # Do we handle ACE+TAO here?
      if get_config('without-tao')
        if R2CORBA::Config.is_osx
          # configure dynamic library dependencies for Mac OSX
          so_ext = '.dylib'

          inst_extlibs = Dir.glob(File.join('ext', '*.bundle'))
          inst_dylibs = inst_extlibs + ACE_FILES.collect {|dep| File.join(get_config('aceroot'),'lib', 'lib' + dep + so_ext)}
          # cross dependencies of ext dynamic libs on each other
          # make sure they refer to *.bundle NOT *.dylib
          inst_extlibs.each do |extlib|
            inst_extlibs.each do |dep|
              dep_org = File.basename(dep, '.bundle') + so_ext
              sh("install_name_tool -change #{dep_org} @rpath/#{File.basename(dep)} #{extlib}")
            end
            # add install directory as rpath; first delete rpath ignoring errors, next add the rpath
            sh("install_name_tool -delete_rpath #{get_config('siterubyverarch')} #{extlib} >/dev/null 2>&1")
            sh("install_name_tool -add_rpath #{get_config('siterubyverarch')} #{extlib}")
          end
          # dependencies on ACE+TAO libs
          inst_dylibs.each do |dylib|
            ACE_FILES.each do |dep|
              command("install_name_tool -change lib#{dep + so_ext} @rpath/lib#{dep + so_ext} #{dylib}")
            end
            # add current dir and install dir as rpath entries; first delete rpath ignoring errors, next add the rpath
            sh("install_name_tool -delete_rpath . #{dylib} >/dev/null 2>&1")
            sh("install_name_tool -add_rpath . #{dylib}")
            sh("install_name_tool -delete_rpath #{get_config('aceinstdir')} #{dylib} >/dev/null 2>&1")
            sh("install_name_tool -add_rpath #{get_config('aceinstdir')} #{dylib}")
          end
        elsif !is_win32
          # create unversioned ACE+TAO lib symlinks

          ACE_FILES.collect {|dep| File.join(get_config('aceroot'),'lib', 'lib' + dep + '.so')}.each do |lib|
            Dir.glob(lib + '.*').each {|verlib| File.symlink(verlib, lib) unless File.exist?(lib)}
          end
        end
      end
    end

  end # Ext

end # R2CORBA
