#--------------------------------------------------------------------
# gem.rb - build file
#
# Author: Martin Corino
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the R2CORBA LICENSE which is
# included with this program.
#
# Copyright (c) Remedy IT Expertise BV
#--------------------------------------------------------------------

require 'rubygems'
require 'rubygems/package'
begin
  require 'rubygems/builder'
rescue LoadError
end

require File.join(File.dirname(__FILE__), 'config.rb')
unless defined?(JRUBY_VERSION)
  require File.join(File.dirname(__FILE__), 'ext.rb')
end

module R2CORBA

  module Gem

    unless defined?(JRUBY_VERSION)

      @@ace_dlls = nil

      def self.ace_dlls
        unless @@ace_dlls
          @@ace_dlls = []
          # collect required dll paths
          if R2CORBA::Config.is_win32
            @@ace_dlls.concat(R2CORBA::Ext.ace_shlibs(R2CORBA::Ext.so_ext, 'ext'))
            @@ace_dlls.concat(R2CORBA::Ext.sys_dlls.collect {|sysdll| File.join('ext', File.basename(sysdll))})
          elsif R2CORBA::Config.is_linux
            @@ace_dlls.concat(R2CORBA::Ext.ace_shlibs('.so.*').collect {|acelib| File.join('ext', File.basename(Dir.glob(acelib).first)) })
          else
            @@ace_dlls.concat(R2CORBA::Ext.ace_shlibs(R2CORBA::Ext.so_ext, 'ext'))
          end
        end
        @@ace_dlls
      end
    end

    def self.manifest(gemtype = :src, exclude_ace_dll = false)
      # create MANIFEST list with included files
      manifest = []
      if gemtype == :bin
        manifest.concat %w{bin/ridlc bin/rins bin/r2corba}
        manifest.concat %w{bin/ridlc.bat bin/rins.bat bin/r2corba.bat} if R2CORBA::Config.is_win32 || defined?(JRUBY_VERSION)
        if defined?(JRUBY_VERSION)
          manifest.concat(Dir['jacorb/lib/*.jar'].select do |fnm|
            !%w{idl jacorb-sources picocontainer wrapper}.any? {|nm| /^#{nm}/ =~ File.basename(fnm) }
          end)
        elsif ENV['FULL_BINGEM']
          manifest.concat(R2CORBA::Gem.ace_dlls) unless exclude_ace_dll
          manifest.concat(Dir['ext/*.so'])
        end
        manifest.concat Dir['lib/corba/**/*']
        manifest.concat Dir['lib/ridlbe/**/*']
        manifest << 'lib/corba.rb'
        manifest.concat Dir['test/**/*']
        manifest.concat %w{LICENSE README.rdoc THANKS CHANGES mkrf_conf_bingem.rb}
        manifest << 'LICENSE.jacorb' if defined?(JRUBY_VERSION)
      elsif gemtype == :extbin
        unless defined?(JRUBY_VERSION)
          manifest.concat(R2CORBA::Gem.ace_dlls) unless exclude_ace_dll
          manifest.concat(Dir['ext/*.so'])
        end
      else
        manifest.concat %w{bin/ridlc bin/rins bin/r2corba}
        manifest.concat Dir['ext/**/*.{rb,c,cpp,h,mwc}']
        manifest.concat Dir['lib/corba/**/*[^CS].*'].select {|path| File.basename(path) != 'r2c_orb.rb'}
        manifest.concat Dir['lib/ridlbe/**/*.[^p]*']
        manifest << 'lib/corba.rb'
        manifest.concat Dir['test/**/*']
        manifest.concat %w{LICENSE README.rdoc THANKS CHANGES mkrf_conf_srcgem.rb}
      end
      unless gemtype == :extbin
        if defined?(JRUBY_VERSION)
          manifest.concat(Dir['rakelib/**/*'].select {|fnm| /install|help|ext/ =~ fnm ? false : true })
        else
          manifest.concat(Dir['rakelib/**/*'].select {|fnm| /install|help/ =~ fnm ? false : true })
        end
      end
      manifest
    end

    def self.define_spec(name, version, gemtype = :src, &block)
      name += '_ext' if gemtype == :extbin && !defined?(JRUBY_VERSION)
      name = "#{name}#{R2CORBA::Config.rb_ver_major}#{R2CORBA::Config.rb_ver_minor}" if (gemtype == :extbin || (gemtype == :bin && ENV['FULL_BINGEM'])) && !defined?(JRUBY_VERSION)
      gemspec = ::Gem::Specification.new(name,version.dup)
      if gemtype == :bin || gemtype == :extbin
        gemspec.platform = defined?(JRUBY_VERSION) ? ::Gem::Platform.new('universal-java') : ::Gem::Platform::CURRENT
      end
      gemspec.required_rubygems_version = ::Gem::Requirement.new(">= 0") if gemspec.respond_to? :required_rubygems_version=
      block.call(gemspec) if block_given?
      gemspec
    end

    def self.gem_name(name, version, gemtype = :src)
      name += '_ext' if gemtype == :extbin &&  !defined?(JRUBY_VERSION)
      name = "#{name}#{R2CORBA::Config.rb_ver_major}#{R2CORBA::Config.rb_ver_minor}" if (gemtype == :extbin || (gemtype == :bin && ENV['FULL_BINGEM'])) && !defined?(JRUBY_VERSION)
      gemspec = ::Gem::Specification.new(name,version.dup)
      if gemtype == :bin || gemtype == :extbin
        gemspec.platform = defined?(JRUBY_VERSION) ? ::Gem::Platform.new('universal-java') : ::Gem::Platform::CURRENT
      end
      gemspec.full_name
    end

    def self.build_gem(gemspec)
      if defined?(::Gem::Package) && ::Gem::Package.respond_to?(:build)
        gem_file_name = ::Gem::Package.build(gemspec)
      else
        gem_file_name = ::Gem::Builder.new(gemspec).build
      end

      FileUtils.mkdir_p('pkg')

      FileUtils.mv(gem_file_name, 'pkg')
    end

    unless defined?(JRUBY_VERSION) || R2CORBA::Config.is_win32
      def self.patch_extlib_rpath
        if R2CORBA::Config.is_osx
          # TODO
        else
          rpath = "#{File.expand_path('ext')}:#{get_config('libdir')}"
          Dir['ext/*.so'].each do |extlib|
            unless Rake.sh("#{R2CORBA::Config.rpath_patch} '#{rpath}' #{extlib}")
              raise 'Failed to patch RPATH for #{extlib}'
            end
          end
        end
      end
    end

  end

end
