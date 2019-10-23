#--------------------------------------------------------------------
# mkrf_conf_bingem.rb - Rakefile generator binary gem installation
#
# Author: Martin Corino
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the R2CORBA LICENSE which is
# included with this program.
#
# Copyright (c) Remedy IT Expertise BV
#--------------------------------------------------------------------

# generate Rakefile with appropriate default task (all actual task in rakelib)
File.open('Rakefile', 'w') do |f|
  f.puts <<EOF__
#--------------------------------------------------------------------
# Rakefile - build file for srcgem installation
#
# Author: Martin Corino
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the R2CORBA LICENSE which is
# included with this program.
#
# Copyright (c) Remedy IT Expertise BV
#--------------------------------------------------------------------

if defined?(JRUBY_VERSION)
  task :default => 'r2corba:build'
else
  task :default => 'r2corba:gem:binbuild'
end
EOF__
end

if defined?(JRUBY_VERSION)

  unless system("ruby -S rake -- configure --jacorb-home=#{File.expand_path('ext')}")
    $stderr.puts "Failed to configure R2CORBA"
    exit(1)
  end

else
  require 'rbconfig'
  if defined? ::RbConfig
    RB_CONFIG = ::RbConfig::CONFIG
  else
    RB_CONFIG = ::Config::CONFIG
  end unless defined? RB_CONFIG

  # check if we have a full bin gem here, or one without extension binaries
  if Dir["ext/*.#{RB_CONFIG['DLEXT']}"].empty?

    RB_VER_MAJOR, RB_VER_MINOR, RB_VER_REL = RUBY_VERSION.split('.').collect {|n| n.to_i}

    require File.join(File.dirname(__FILE__), 'lib', 'corba', 'common', 'version.rb')

    require 'rubygems'
    require 'rubygems/command.rb'
    require 'rubygems/dependency_installer.rb'
    require 'rubygems/uninstaller'
    require 'fileutils'

    ## ==========================================================================================##

    # determin rubygems version
    gem_ver_major, gem_ver_minor, gem_ver_release = Gem::VERSION.split('.').collect {|s| s.to_i }
    # in case of rubygems 2.3.0 - 2.4.5
    if gem_ver_major == 2 && (gem_ver_minor == 3 || (gem_ver_minor == 4 && gem_ver_release <= 5))
      # patch the Gem::Resolver::InstallerSet class
      require 'rubygems/resolver/installer_set'
      class ::Gem::Resolver::InstallerSet
        def add_always_install dependency
          request = Gem::Resolver::DependencyRequest.new dependency, nil

          found = find_all request

          found.delete_if { |s|
            s.version.prerelease? and not s.local?
          } unless dependency.prerelease?

          found = found.select do |s|
            Gem::Source::SpecificFile === s.source or
                Gem::Platform::RUBY == s.platform or
                # *** MCO patch *** use correct platform comparison -> s.platform === String
                Gem::Platform.local =~ s.platform
          end

          if found.empty? then
            exc = Gem::UnsatisfiableDependencyError.new request
            exc.errors = errors

            raise exc
          end

          newest = found.max_by do |s|
            [s.version, s.platform == Gem::Platform::RUBY ? -1 : 1]
          end

          @always_install << newest.spec
        end
      end
    end

    ## ==========================================================================================##

    begin
      Gem::Command.build_args = ARGV
    rescue NoMethodError
    end
    unless ENV['R2CORBA_GEM_SOURCE'].to_s.empty?
      # make sure the RubyGems configuration has been loaded as this potentially overwrites
      # Gem.sources
      Gem.configuration
      # add custom source
      Gem.sources << ENV['R2CORBA_GEM_SOURCE']
      puts "Gem sources: #{Gem.sources.to_a}"
    end
    inst = Gem::DependencyInstaller.new
    begin
      # install corresponding gem with extension binaries
      puts "Installing extension binaries gem: r2corba_ext#{RB_VER_MAJOR}#{RB_VER_MINOR}-#{R2CORBA::R2CORBA_VERSION}."
      spec = inst.install("r2corba_ext#{RB_VER_MAJOR}#{RB_VER_MINOR}", R2CORBA::R2CORBA_VERSION.dup).last
      begin
        # move extension binaries from extension binaries gem location to our own
        srcdir = File.join(spec.gem_dir, 'ext')
        puts "Moving extension binaries from #{srcdir}"
        Dir[File.join(srcdir, '*')].each do |extpath|
          FileUtils.mv(extpath, 'ext', :force => true)
        end
      ensure
        # uninstall extension binaries gem
        puts "Uninstalling extension binaries gem: r2corba_ext#{RB_VER_MAJOR}#{RB_VER_MINOR}-#{R2CORBA::R2CORBA_VERSION}."
        Gem::Uninstaller.new("r2corba_ext#{RB_VER_MAJOR}#{RB_VER_MINOR}", :version => R2CORBA::R2CORBA_VERSION.dup).uninstall
      end
    rescue
      puts "Failed to install binary r2corba_ext#{RB_VER_MAJOR}#{RB_VER_MINOR} v. #{R2CORBA::R2CORBA_VERSION} gem for #{RUBY_PLATFORM}."
      puts "#{$!}\n#{$!.backtrace.join('\n')}"
      exit(1)
    end

  end

  puts "Running rake -- configure --without-tao"
  unless system("rake -- configure --without-tao")
    puts "Failed to configure R2CORBA."
    exit(1)
  end
end
