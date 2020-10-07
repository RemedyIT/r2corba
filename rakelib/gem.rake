#--------------------------------------------------------------------
# gem.rake - build file
#
# Author: Martin Corino
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the R2CORBA LICENSE which is
# included with this program.
#
# Copyright (c) Remedy IT Expertise BV
#--------------------------------------------------------------------

require File.join(File.dirname(__FILE__), 'gem.rb')

namespace :r2corba do
  namespace :gem do
    task :srcgem => ['r2corba:bin:build', File.join('pkg', "#{R2CORBA::Gem.gem_name('r2corba', R2CORBA::R2CORBA_VERSION)}.gem")]

    task :bingem => ['r2corba:build', File.join('pkg', "#{R2CORBA::Gem.gem_name('r2corba', R2CORBA::R2CORBA_VERSION, :bin)}.gem")]

    task :extbingem => ['r2corba:build', File.join('pkg', "#{R2CORBA::Gem.gem_name('r2corba', R2CORBA::R2CORBA_VERSION, :extbin)}.gem")]

    task :srcbuild => 'r2corba:build' do
      ext_dir = File.expand_path('ext')
      unless defined?(JRUBY_VERSION) || get_config('without-tao')
        # install ACE+TAO dlls
        R2CORBA::Ext.ace_shlibs.each do |acelib|
          libmask = R2CORBA::Config.is_linux ? acelib+'.*' : acelib
          path = Dir.glob(libmask).first
          raise "Cannot find ACE+TAO library #{File.basename(acelib)}." unless path
          FileUtils.install(path, ext_dir, :mode => 0555, :verbose => Rake.verbose)
          # create unversioned symlink
          ln_s(File.join(ext_dir, File.basename(path)), File.join(ext_dir, File.basename(acelib)), :force => true) if R2CORBA::Config.is_linux
        end
        # clean up (uninstall) taosource gem
        require 'rubygems/uninstaller'
        Gem::Uninstaller.new('taosource', :all => true).uninstall
      end
    end

    task :binbuild => ['r2corba:bin:build', 'r2corba:build_idl'] do
      unless defined?(JRUBY_VERSION)
        if R2CORBA::Config.is_linux
          # create unversioned ACE/TAO lib symlinks
          R2CORBA::Ext.ace_shlibs('.so', 'ext').each do |acelib|
            acelib_ver = File.expand_path(Dir[acelib+'.*'].first)
            ln_s(acelib_ver, acelib)
          end
        end
        unless R2CORBA::Config.is_win32
          # patch RPATH setting of shared libs
          R2CORBA::Gem.patch_extlib_rpath
        end
      end
    end

    unless defined?(JRUBY_VERSION)
      task :taogem do
        # get version of latest ACE release from internet
        _ace_ver = R2CORBA::Ext.get_latest_ace_version
        # make sure download target dir exists
        Rake.mkdir_p('src')
        # download latest TAO source archive from internet
        R2CORBA::Ext.download_tao_source(_ace_ver, 'src')
        # build gem
        gemspec = R2CORBA::Gem.define_spec('taosource', _ace_ver) do |gem|
          gem.summary = %Q{TAO sourcecode for building R2CORBA}
          gem.description = %Q{TAO sourcecode for building R2CORBA.}
          gem.email = 'mcorino@remedy.nl'
          gem.homepage = "https://www.remedy.nl/opensource/r2corba.html"
          gem.authors = ['Martin Corino', 'Johnny Willemsen']
          gem.files = Dir['lib/taosource/**/*']
          gem.files.concat(Dir["src/ACE+TAO-src-#{_ace_ver}.tar.gz"])
          gem.files << 'mkrf_conf_taogem.rb'
          gem.extensions = ['mkrf_conf_taogem.rb']
          gem.require_paths = %w{lib}
          gem.executables = []
          gem.required_ruby_version = '>= 2.0'
          gem.licenses = ['DOC']
          gem.metadata = {
            "bug_tracker_uri"   => "https://github.com/DOCGroup/ACE_TAO/issues",
            "source_code_uri"   => "https://github.com/DOCGroup/ACE_TAO"
          }
        end
        R2CORBA::Gem.build_gem(gemspec)
      end
    end
  end
end

# source gem file
t_ = file File.join('pkg', "#{R2CORBA::Gem.gem_name('r2corba', R2CORBA::R2CORBA_VERSION)}.gem") => R2CORBA::Gem.manifest do
  gemspec = R2CORBA::Gem.define_spec('r2corba', R2CORBA::R2CORBA_VERSION) do |gem|
    gem.summary = %Q{CORBA language mapping implementation for Ruby}
    gem.description = %Q{OMG CORBA v3.3 compliant CORBA language mapping implementation for Ruby. Depends on ridl gem for providing native Ruby IDL compiler. }
    gem.email = 'mcorino@remedy.nl'
    gem.homepage = "https://www.remedy.nl/opensource/r2corba.html"
    gem.authors = ['Martin Corino', 'Johnny Willemsen']
    gem.files = R2CORBA::Gem.manifest
    gem.extensions = ['mkrf_conf_srcgem.rb']
    gem.require_paths = %w{lib}
    gem.executables = %w{ridlc rins r2corba}
    gem.required_ruby_version = '>= 2.0'
    gem.licenses = ['Nonstandard', 'DOC', 'GPL-2.0']
    gem.require_paths << 'ext'
    gem.add_dependency 'ridl', '~> 2.8'
    gem.add_dependency 'rake', '~> 12.3.3'
    gem.rdoc_options << '--exclude=\\.dll' << '--exclude=\\.so' << '--exclude=\\.pidlc'
    gem.metadata = {
      "bug_tracker_uri"   => "https://github.com/RemedyIT/r2corba/issues",
      "source_code_uri"   => "https://github.com/RemedyIT/r2corba"
    }
  end
  R2CORBA::Gem.build_gem(gemspec)
end
t_.enhance ['mkrf_conf_srcgem.rb']

# Extension binaries gem file
t_ = file File.join('pkg', "#{R2CORBA::Gem.gem_name('r2corba', R2CORBA::R2CORBA_VERSION, :extbin)}.gem") => R2CORBA::Gem.manifest(:extbin, true) do
  unless defined?(JRUBY_VERSION)
    # prepare required shared libs for ext libs
    if R2CORBA::Config.is_win32
      ext_deplibs = R2CORBA::Ext.ace_shlibs + R2CORBA::Ext.sys_dlls
    elsif R2CORBA::Config.is_linux
      ext_deplibs = R2CORBA::Ext.ace_shlibs('.so.*').collect {|acelib| Dir.glob(acelib).first }
    else
      ext_deplibs = R2CORBA::Ext.ace_shlibs
    end
    ext_deplibs.each {|deplib| cp(deplib, File.join('ext', File.basename(deplib)), :verbose => false) }
  end
  begin
    gemspec = R2CORBA::Gem.define_spec('r2corba', R2CORBA::R2CORBA_VERSION, :extbin) do |gem|
      gem.summary = %Q{CORBA language mapping implementation for Ruby (extension binaries)}
      gem.description = %Q{OMG CORBA v3.3 compliant CORBA language mapping implementation for Ruby. Depends on ridl gem for providing native Ruby IDL compiler. (extension binaries)}
      gem.email = 'mcorino@remedy.nl'
      gem.homepage = "https://www.remedy.nl/opensource/r2corba.html"
      gem.authors = ['Martin Corino', 'Johnny Willemsen']
      gem.files = R2CORBA::Gem.manifest(:extbin)
      gem.extensions = []
      gem.require_paths = %w{ext}
      gem.executables = []
      gem.required_ruby_version = '>= 2.0'
      gem.licenses = ['Nonstandard', 'DOC']
      gem.rdoc_options << '--exclude=\\.dll' << '--exclude=\\.so'
      gem.metadata = {
        "bug_tracker_uri"   => "https://github.com/RemedyIT/r2corba/issues",
        "source_code_uri"   => "https://github.com/RemedyIT/r2corba"
      }
    end
    R2CORBA::Gem.build_gem(gemspec)
  ensure
    ext_deplibs.each {|deplib| rm_f(File.join('ext', File.basename(deplib)), :verbose => false) } unless defined?(JRUBY_VERSION)
  end
end

# binary gem file
t_ = file File.join('pkg', "#{R2CORBA::Gem.gem_name('r2corba', R2CORBA::R2CORBA_VERSION, :bin)}.gem") => R2CORBA::Gem.manifest(:bin, true) do
  unless defined?(JRUBY_VERSION)
    if ENV['FULL_BINGEM']
      # prepare required shared libs for ext libs
      if R2CORBA::Config.is_win32
        ext_deplibs = R2CORBA::Ext.ace_shlibs + R2CORBA::Ext.sys_dlls
      elsif R2CORBA::Config.is_linux
        ext_deplibs = R2CORBA::Ext.ace_shlibs('.so.*').collect {|acelib| Dir.glob(acelib).first }
      else
        ext_deplibs = R2CORBA::Ext.ace_shlibs
      end
      ext_deplibs.each {|deplib| cp(deplib, File.join('ext', File.basename(deplib)), :verbose => false) }
    else
      touch(File.join('ext', '.keep'))
    end
  end
  begin
    # create gemspec
    gemspec = R2CORBA::Gem.define_spec('r2corba', R2CORBA::R2CORBA_VERSION, :bin) do |gem|
      gem.summary = %Q{CORBA language mapping implementation for Ruby}
      gem.description = %Q{OMG CORBA v3.3 compliant CORBA language mapping implementation for Ruby. Depends on ridl gem for providing native Ruby IDL compiler. }
      gem.email = 'mcorino@remedy.nl'
      gem.homepage = "https://www.remedy.nl/opensource/r2corba.html"
      gem.authors = ['Martin Corino', 'Johnny Willemsen']
      gem.files = R2CORBA::Gem.manifest(:bin)
      gem.require_paths = %w{lib}
      gem.executables = %w{ridlc rins r2corba}
      gem.extensions = ['mkrf_conf_bingem.rb']
      if defined?(JRUBY_VERSION)
        gem.require_paths << 'jacorb/lib'
        gem.required_ruby_version = '>= 2.0'
        gem.licenses = ['Nonstandard', 'GPL-2.0']
      else
        gem.files << File.join('ext', '.keep') unless ENV['FULL_BINGEM'] # to force installation of ext folder if libs are left out
        gem.required_ruby_version = '>= 2.0'
        gem.licenses = ['Nonstandard', 'DOC', 'GPL-2.0']
        gem.require_paths << 'ext'
      end
      gem.add_dependency 'ridl', '~> 2.8'
      gem.add_dependency 'rake', '~> 12.3.3'
      gem.rdoc_options << '--exclude=\\.dll' << '--exclude=\\.so' << '--exclude=\\.pidlc'
      gem.metadata = {
        "bug_tracker_uri"   => "https://github.com/RemedyIT/r2corba/issues",
        "source_code_uri"   => "https://github.com/RemedyIT/r2corba"
      }
    end
    R2CORBA::Gem.build_gem(gemspec)
  ensure
    if ENV['FULL_BINGEM']
      ext_deplibs.each {|deplib| rm_f(File.join('ext', File.basename(deplib)), :verbose => false) } unless defined?(JRUBY_VERSION)
    else
      rm_f(File.join('ext', '.keep')) unless defined?(JRUBY_VERSION)
    end
  end
end
t_.enhance ['mkrf_conf_bingem.rb']

unless defined?(JRUBY_VERSION) || !R2CORBA::Config.is_win32
  # Devkit faker Gem for binary Windows gems
  t_devkit = file File.join('pkg', "#{R2CORBA::Gem.gem_name('r2corba_devkit', '1.0.0', :devkit)}.gem") => 'lib/rubygems_plugin.rb' do
    # create gemspec
    gemspec = R2CORBA::Gem.define_spec('r2corba_devkit', '1.0.0', :devkit) do |gem|
      gem.summary = %Q{R2CORBA Devkit faker for RubyInstaller Rubies}
      gem.description = %Q{Fake Devkit loader to satisfy stupid RubyInstaller pre-install hook. }
      gem.email = 'mcorino@remedy.nl'
      gem.homepage = "https://www.remedy.nl/opensource/r2corba.html"
      gem.authors = ['Martin Corino', 'Johnny Willemsen']
      gem.files = 'lib/rubygems_plugin.rb'
      gem.require_paths = %w{lib}
      gem.executables = []
      gem.extensions = []
      gem.required_ruby_version = '>= 2.0'
      gem.licenses = ['Nonstandard']
      gem.metadata = {
        "bug_tracker_uri"   => "https://github.com/RemedyIT/r2corba/issues",
        "source_code_uri"   => "https://github.com/RemedyIT/r2corba"
      }
    end
    R2CORBA::Gem.build_gem(gemspec)
  end
  namespace :r2corba do
    namespace :gem do
      task :devkit => t_devkit.name
    end
  end
end

desc 'Build R2CORBA gem'
if defined?(JRUBY_VERSION)
  task :gem => 'r2corba:gem:bingem'
elsif R2CORBA::Config.is_win32
  task :gem => 'r2corba:gem:bingem'
else
  task :gem => 'r2corba:gem:srcgem'
end
