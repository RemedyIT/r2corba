#--------------------------------------------------------------------
# config.rb - build file
#
# Author: Martin Corino
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the R2CORBA LICENSE which is
# included with this program.
#
# Copyright (c) Remedy IT Expertise BV
#--------------------------------------------------------------------

require 'rbconfig'
require 'yaml'
require 'optparse'

require 'rake/clean'

require File.join(File.dirname(__FILE__), '../lib/corba/common/version')

=begin

  Generic keys defaulted to RB_CONFIG value
  ================================================
  bindir
  libdir
  datadir
  mandir
  sysconfdir
  localstatedir

  custom keys
  ===========
  Generic

  key             default
  ---             ------
  prefix          nil
  libruby         File.join(RB_CONFIG['libdir'], 'ruby'),
  librubyver      RB_CONFIG['rubylibdir'],
  librubyverarch  RB_CONFIG['archdir'],
  siteruby        RB_CONFIG['sitedir'],
  siterubyver     RB_CONFIG['sitelibdir'],
  siterubyverarch RB_CONFIG['sitearchdir'],
  rbdir           RB_CONFIG['siterubyver']
  sodir           RB_CONFIG['siterubyverarch']

  MRI

  key             default
  ---             ------
  makeprog        'make'
  without-tao     'no'
  aceroot         nil
  taoroot         nil
  mpcroot         nil
  aceinstdir      $ACE_ROOT/lib || get_config[:sodir]
  with-ipv6       'no'
  with-ssl        'no'
  sslroot         '/usr'
  with-debug      'no'

  Java

  key             default
  ---             ------
  without-jacorb  false
  jacorb_home     ENV['JACORB_HOME']
=end

if (Rake::Version::MAJOR.to_i == 10 &&
    ((Rake::Version::MINOR.to_i == 4 && Rake::Version::BUILD.to_i >= 2) ||
        Rake::Version::MINOR.to_i > 4)) || Rake::Version::MAJOR.to_i > 10

  # patch Rake::Application with method to cleanup ARGV consuming
  # all Rake options
  class Rake::Application

    def cleanup_args(argv = ARGV) # :nodoc:
      return argv if options.r2corba_cleanup_done

      _opt_backup = options
      @options = OpenStruct.new
      options.rakelib = ['rakelib']
      options.trace_output = $stderr

      begin
        return OptionParser.new do |opts|
          opts.banner = ''
          opts.separator ''

          standard_rake_options.each { |args| opts.on(*args) }
          opts.environment('RAKEOPT')
        end.parse!(argv)
      ensure
        @options = _opt_backup
        @options.r2corba_cleanup_done = true
      end
    end

  end
else

  class Rake::Application

    ## noop for other Rake versions
    def cleanup_args(argv = ARGV) # :nodoc:
      argv
    end

  end
end

module R2CORBA

  if defined? ::RbConfig
    RB_CONFIG = ::RbConfig::CONFIG
  else
    RB_CONFIG = ::Config::CONFIG
  end unless defined? RB_CONFIG

  CFGKEYS = %w{prefix
               bindir
               libdir
               datadir
               mandir
               sysconfdir
               localstatedir
               libruby
               librubyver
               librubyverarch
               siteruby
               siterubyver
               siterubyverarch
               rbdir
               sodir}

  RBDEFAULTS = %w{bindir
                  libdir
                  datadir
                  mandir
                  sysconfdir
                  localstatedir}

  CONFIG = {
      :libruby => File.join(RB_CONFIG['libdir'], 'ruby'),
      :librubyver => RB_CONFIG['rubylibdir'],
      :librubyverarch => RB_CONFIG['archdir'],
      :siteruby => RB_CONFIG['sitedir'],
      :siterubyver => RB_CONFIG['sitelibdir'],
      :siterubyverarch => RB_CONFIG['sitearchdir'],
      :rbdir => :siterubyver,
      :sodir => :siterubyverarch,
  }

  if defined?(JRUBY_VERSION)
    CFGKEYS.concat(%w{without-jacorb jacorb_home})
    CONFIG.merge!({
      :'without-jacorb' => false,
      :jacorb_home => ENV['JACORB_HOME'] || ''
    })
    BUILD_CFG = '.jrconfig'
  else
    CFGKEYS.concat(%w{makeprog without-tao aceroot taoroot mpcroot aceinstdir with-ipv6 with-ssl sslroot with-debug})
    CONFIG.merge!({
      :makeprog => 'make',
      :'without-tao' => false,
      :aceroot => ENV['ACE_ROOT'] || '',
      :taoroot => ENV['TAO_ROOT'] || '',
      :mpcroot => ENV['MPC_ROOT'] || '',
      :aceinstdir => '',
      :'with-ipv6' => false,
      :'with-ssl' => false,
      :sslroot => ENV['SSL_ROOT'] || (RUBY_PLATFORM =~ /mingw32/ ? '' : '/usr'),
      :'with-debug' => false,
    })
    BUILD_CFG = '.rconfig'
  end

  module AccessMethods
    def get_config(key)
      v = R2CORBA::CONFIG.has_key?(key.to_sym) ? R2CORBA::CONFIG[key.to_sym] : (RBDEFAULTS.include?(key.to_s) ? RB_CONFIG[key.to_s] : nil)
      v = R2CORBA::CONFIG[v] while Symbol === v && R2CORBA::CONFIG.has_key?(v)
      v
    end

    def set_config(key, val)
      R2CORBA::CONFIG[key.to_sym] = val
    end
  end

  module Config

    @@ruby_ver = RUBY_VERSION.split('.').collect {|n| n.to_i}

    def self.rb_ver_major
      @@ruby_ver[0]
    end

    def self.rb_ver_minor
      @@ruby_ver[1]
    end

    def self.rb_ver_release
      @@ruby_ver[2]
    end

    @@is_win32 = RUBY_PLATFORM =~ /mingw32/ ? true : false
    @@is_win64 = (@@is_win32 && (RUBY_PLATFORM =~ /x64/)) ? true : false
    @@is_linux = RB_CONFIG['target_os'] =~ /linux/ ? true : false
    @@is_osx = RUBY_PLATFORM =~ /darwin/ ? true : false

    if @@is_linux
      # determin distro
      name = 'linux'
      if File.readable?('/etc/os-release')
        # find 'NAME=...'
        File.foreach('/etc/os-release', :encoding => 'utf-8') do |ln|
          if /^NAME=(.*)$/ =~ ln.strip
            name = $1.downcase
            break
          end
        end
      elsif File.readable?('/etc/lsb-release')
        # find 'DISTRIB_ID='
        File.foreach('/etc/lsb-release', :encoding => 'utf-8') do |ln|
          if /^DISTRIB_ID=(.*)$/ =~ ln.strip
            name = $1.downcase
            break
          end
        end
      elsif File.readable?('/etc/redhat-release')
        name = File.read('/etc/redhat-release').strip.downcase
      elsif File.exist?('/etc/SuSE-release')
        name = 'suse'
      elsif File.exist?('/etc/debian_version')
        name = 'debian'
      end
      @@linux_distro = case name
        when /suse/
          :suse
        when /fedora/
          :fedora
        when /ubuntu/
          :ubuntu
        when /red\s*hat/
          :redhat
        when /centos/
          :centos
        when /debian/
          :debian
        else
          :linux
        end
    else
      @@linux_distro = :none
    end

    def self.is_win32
      @@is_win32
    end
    def self.is_win64
      @@is_win64
    end
    def self.is_linux
      @@is_linux
    end
    def self.linux_distro
      @@linux_distro
    end
    def self.is_osx
      @@is_osx
    end

    @@cpu_cores = (@@is_linux ? `cat /proc/cpuinfo | grep processor | wc -l`.to_i : (ENV['NUMBER_OF_PROCESSORS'] || 1).to_i)

    def self.cpu_cores
      @@cpu_cores
    end

    @@ridl_local = nil
    @@ridlc = nil

    def self.ridl_is_local?
      @@ridl_local
    end

    def self.ridlc
      @@ridlc.dup
    end

    @@rpath_patch = nil

    def self.rpath_patch
      @@rpath_patch
    end

    def self.init
      if defined?(JRUBY_VERSION)
        # check/set environment settings for JacORB
        ENV['JACORB_HOME'] ||= get_config('jacorb_home')
      else

        if Dir[File.join('ext', 'libACE.*')].empty? # Don't check for ACE/TAO installation when executed for binary gem install

          # check/set environment settings for ACE+TAO
          ENV['ACE_ROOT'] = get_config('aceroot')
          ENV['TAO_ROOT'] = get_config('taoroot')
          ENV['MPC_ROOT'] = get_config('mpcroot')

          if is_win32
            ENV['PATH'] = "#{File.join(ENV['ACE_ROOT'], 'lib')}#{';'}#{ENV['PATH']}"
            ENV['SSL_ROOT'] = get_config('sslroot') if get_config('with-ssl')
          elsif RUBY_PLATFORM =~ /darwin/
            ENV['DYLD_LIBRARY_PATH'] = "#{File.join(ENV['ACE_ROOT'], 'lib')}#{File::PATH_SEPARATOR}#{ENV['DYLD_LIBRARY_PATH'] || ""}"
            ENV['SSL_ROOT'] = get_config('sslroot') if get_config('with-ssl') && get_config('sslroot') != '/usr'
          else
            ENV['LD_LIBRARY_PATH'] = "#{File.join(ENV['ACE_ROOT'], 'lib')}#{File::PATH_SEPARATOR}#{ENV['LD_LIBRARY_PATH'] || ""}"
            ENV['SSL_ROOT'] = get_config('sslroot') if get_config('with-ssl') && get_config('sslroot') != '/usr'
          end

        else

          unless is_win32
            # check for required tools to patch RPATH setting of shared libs
            if is_osx
              if system('which install_name_tool > /dev/null 2>&1')
                @@rpath_patch = 'install_name_tool'
              else
                raise 'Installation of binary gem requires an installed version of the install_name_tool utility.'
              end
            else
              if system('which patchelf > /dev/null 2>&1')
                @@rpath_patch = 'patchelf --set-rpath'
              elsif system('which chrpath > /dev/null 2>&1')
                @@rpath_patch = 'chrpath --replace'
              else
                raise 'Installation of binary gem requires an installed version of either the patchelf OR chrpath utility.'
              end
            end
          end

        end

      end

      @@ridlc = File.join('bin', 'ridlc')

      # check availability of RIDL; either as gem or in subdir
      if (@@ridl_local = File.exist?(File.join('ridl', 'lib', 'ridl', 'ridl.rb')))
        incdirs = [
            File.expand_path(File.join('ridl', 'lib')),
            File.expand_path('lib'),
            ENV['RUBYLIB']
        ].compact
        ENV['RUBYLIB'] = incdirs.join(File::PATH_SEPARATOR)
      else # RIDL probably installed as gem
        incdirs = [
            File.expand_path('lib'),
            ENV['RUBYLIB']
        ].compact
        ENV['RUBYLIB'] = incdirs.join(File::PATH_SEPARATOR)
      end

    end

    def self.define
      _argv = Rake.application.cleanup_args(ARGV)
      OptionParser.new do |opts|
        opts.banner = 'Usage: rake [rake options] -- configure [options]'

        opts.separator ''

        opts.on('--prefix=path',
                "path prefix of target environment [#{get_config(:prefix)}]") {|v| set_config(:prefix, File.expand_path(v))}
        opts.on('--bindir=path',
                "the directory for commands [#{RB_CONFIG['bindir']}]") {|v| CONFIG[:bindir] = v}
        opts.on('--libdir=path',
                "the directory for libraries [#{RB_CONFIG['libdir']}]")  {|v| CONFIG[:libdir] = v}
        opts.on('--datadir=path',
                "the directory for shared data [#{RB_CONFIG['datadir']}]")  {|v| CONFIG[:datadir] = v}
        opts.on('--mandir=path',
                "the directory for man pages [#{RB_CONFIG['mandir']}]")  {|v| CONFIG[:mandir] = v}
        opts.on('--sysconfdir=path',
                "the directory for system configuration files [#{RB_CONFIG['sysconfdir']}]")  {|v| CONFIG[:sysconfdir] = v}
        opts.on('--localstatedir=path',
                "the directory for local state data [#{RB_CONFIG['localstatedir']}]")  {|v| CONFIG[:localstatedir] = v}
        opts.on('--libruby=path',
                "the directory for ruby libraries [#{get_config('libruby')}]")  {|v| CONFIG[:libruby] = v}
        opts.on('--librubyver=path',
                "the directory for standard ruby libraries [#{get_config('librubyver')}]")  {|v| CONFIG[:librubyver] = v}
        opts.on('--librubyverarch=path',
                "the directory for standard ruby extensions [#{get_config('librubyverarch')}]")  {|v| CONFIG[:librubyverarch] = v}
        opts.on('--siteruby=path',
                "the directory for version-independent aux ruby libraries [#{get_config('siteruby')}]")  {|v| CONFIG[:siteruby] = v}
        opts.on('--siterubyver=path',
                "the directory for aux ruby libraries [#{get_config('siterubyver')}]")  {|v| CONFIG[:siterubyver] = v}
        opts.on('--siterubyverarch=path',
                "the directory for aux ruby binaries [#{get_config('siterubyverarch')}]")  {|v| CONFIG[:siterubyverarch] = v}
        opts.on('--rbdir=path',
                "the directory for ruby scripts [#{get_config(:rbdir)}]")  {|v| CONFIG[:rbdir] = v}
        opts.on('--sodir=path',
                "the directory for ruby extensions [#{get_config(:sodir)}]")  {|v| CONFIG[:sodir] = v}
        if defined?(JRUBY_VERSION)
          opts.on('--without-jacorb',
                  "do *not* install JacORB JAR files with R2CORBA [#{get_config('without-jacorb')}]")  {|v| CONFIG[:'without-jacorb'] = true}
          opts.on('--jacorb-home=path',
                  "the path to the root directory of JacORB [#{get_config(:jacorb_home)}]")  {|v| CONFIG[:jacorb_home] = v}
        else
          opts.on('--makeprog=name',
                  "the make program to compile ruby extensions [#{get_config(:makeprog)}]")  {|v| CONFIG[:makeprog] = v}
          opts.on('--without-tao',
                  "do *not* configure/build/clean the ACE+TAO libraries [#{get_config('without-tao')}]")  {|v| CONFIG[:'without-tao'] = true }
          opts.on('--aceroot=path',
                  "the path to the root directory of ACE [#{get_config(:aceroot)}]")  {|v| CONFIG[:aceroot] = v}
          opts.on('--taoroot=path',
                  "the path to the root directory of TAO [#{get_config(:taoroot)}]")  {|v| CONFIG[:taoroot] = v}
          opts.on('--mpcroot=path',
                  "the path to the root directory of MPC [#{get_config(:mpcroot)}]")  {|v| CONFIG[:mpcroot] = v}
          opts.on('--aceinstdir=path',
                  "the directory where the ACE+TAO dlls are installed (automatically determined if not specified) [#{get_config(:aceinstdir)}]") {|v| CONFIG[:aceinstdir] = v}
          opts.on('--with-ipv6',
                  "build ACE+TAO libraries with IPv6 support enabled [#{get_config('with-ipv6')}]")  {|v| CONFIG[:'with-ipv6'] = true}
          opts.on('--with-ssl',
                  "build ACE+TAO libraries with SSL support enabled (autodetected with prebuilt ACE/TAO) [#{get_config('with-ssl')}]")  {|v| CONFIG[:'with-ssl'] = true}
          opts.on('--sslroot=path',
                  "the root path where SSL includes and libraries can be found [#{get_config(:sslroot)}]")  {|v| CONFIG[:sslroot] = v}
          opts.on('--with-debug',
                  "build with debugger support [#{get_config('with-debug')}]")  {|v| CONFIG[:'with-debug'] = true}
        end

        opts.separator ''

        opts.on('--help', 'Show this help message') { puts opts; puts; exit }
      end.parse!(_argv)
    end

    def self.check
      if defined?(JRUBY_VERSION)
        # check availability of JacORB
        if get_config('jacorb_home') == '' && File.directory?('jacorb')
          set_config('jacorb_home', File.expand_path('jacorb'))
        end
        raise 'Cannot find JacORB. Missing JACORB_HOME configuration!' if get_config('jacorb_home').empty?
      else
        if Dir[File.join('ext', 'libACE.*')].empty? # Don't check for ACE/TAO installation when executed for binary gem install

          if get_config('without-tao') && !(File.directory?(File.join('ACE', 'ACE_wrappers')) || File.directory?(File.join('ACE', 'ACE')))

            # check if a user defined ACE/TAO location is specified or we're using a system standard install
            if get_config('aceroot').empty?
              # assume system standard install; will be checked below
              set_config('aceroot', '/usr/include')
              set_config('taoroot', '/usr/include')
              set_config('mpcroot', '/usr/share/mpc')
              set_config('aceinstdir', get_config('libdir')) if get_config('aceinstdir').empty?
            else
              set_config('aceinstdir', File.join(get_config('aceroot'), 'lib')) if get_config('aceinstdir').empty?
            end

          else
            # check availability of ACE/TAO
            if get_config('aceroot').empty? && (File.directory?(File.join('ACE', 'ACE_wrappers')) || File.directory?(File.join('ACE', 'ACE')))
              set_config('aceroot', File.directory?(File.join('ACE', 'ACE_wrappers')) ? File.expand_path(File.join('ACE', 'ACE_wrappers')) : File.expand_path(File.join('ACE', 'ACE')))
            end
            if get_config('taoroot').empty? && (File.directory?(File.join(get_config('aceroot'), 'TAO')) || File.directory?(File.join('ACE', 'TAO')))
              set_config('taoroot', File.directory?(File.join(get_config('aceroot'), 'TAO')) ? File.expand_path(File.join(get_config('aceroot'), 'TAO')) : File.expand_path(File.join('ACE', 'TAO')))
            end
            if get_config('mpcroot').empty? && (File.directory?(File.join('ACE', 'MPC')) || File.directory?(File.join(get_config('aceroot'), 'MPC')))
              set_config('mpcroot', File.directory?(File.join('ACE', 'MPC')) ? File.expand_path(File.join('ACE', 'MPC')) : File.expand_path(File.join(get_config('aceroot'), 'MPC')))
            end

            set_config('aceinstdir', get_config('sodir')) if get_config('aceinstdir').empty?
          end

          raise 'Cannot find ACE+TAO. Missing ACE_ROOT configuration!' if get_config('aceroot').empty? || !File.directory?(File.join(get_config('aceroot'), 'ace'))
          raise 'Cannot find ACE+TAO. Missing TAO_ROOT configuration!' if get_config('taoroot').empty? || !File.directory?(File.join(get_config('taoroot'), 'tao'))
          raise 'Cannot find MPC. Missing MPC_ROOT configuration!' if get_config('mpcroot').empty? || !File.file?(File.join(get_config('mpcroot'), 'mpc.pl'))

          unless get_config('without-tao') || get_config('with-ssl')
            set_config('with-ssl', Dir.glob(File.join(get_config('aceroot'), 'lib', '*ACE_SLL.*')).empty?() ? false : true)
          end

          if is_osx
            if system('which install_name_tool > /dev/null 2>&1')
              @@rpath_patch = 'install_name_tool'
            else
              raise 'Building R2CORBA requires an installed version of the install_name_tool utility.'
            end
          end

        else

          unless is_win32
            # check for required tools to patch RPATH setting of shared libs
            if is_osx
              if system('which install_name_tool > /dev/null 2>&1')
                @@rpath_patch = 'install_name_tool'
              else
                raise 'Installation of binary gem requires an installed version of the install_name_tool utility.'
              end
            else
              if system('which patchelf > /dev/null 2>&1')
                @@rpath_patch = 'patchelf --set-rpath'
              elsif system('which chrpath > /dev/null 2>&1')
                @@rpath_patch = 'chrpath --replace'
              else
                raise 'Installation of binary gem requires an installed version of either the patchelf OR chrpath utility.'
              end
            end
          end

        end
      end

      # check availability of RIDL; either as gem or in subdir
      unless File.exist?(File.join('ridl', 'lib', 'ridl', 'ridl.rb')) || (`gem search -i -q ridl`.strip) == 'true'
        raise 'Missing RIDL installation. R2CORBA requires RIDL installed either as gem or in subdirectory ridl.'
      end
    end

    def self.save
      File.open(BUILD_CFG, 'w') do |f|
        f << YAML.dump(CONFIG)
      end
    end

    def self.load
      if File.file?(BUILD_CFG)
        File.open(BUILD_CFG, 'r') do |f|
          CONFIG.merge!(YAML.load(f.read))
        end
        init
      end
    end
  end
end

include R2CORBA::AccessMethods

# load current config (if any)
R2CORBA::Config.load
