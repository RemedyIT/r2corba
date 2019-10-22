#--------------------------------------------------------------------
# install.rb - build file
#
# Author: Martin Corino
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the R2CORBA LICENSE which is
# included with this program.
#
# Copyright (c) Remedy IT Expertise BV
#--------------------------------------------------------------------

require File.join(File.dirname(__FILE__), 'ext.rb')

module R2CORBA

  module Install
    def self.define(task)
      _argv = Rake.application.cleanup_args(ARGV)
      OptionParser.new do |opts|
        opts.banner = "Usage: rake [rake options] -- #{task} [options] [NO_HARM=1]"

        opts.separator ""

        opts.on('--prefix=path',
                "path prefix of target environment [#{get_config(:prefix)}]") {|v| set_config(:prefix, File.expand_path(v)) }

        opts.separator ""

        opts.on('--help', 'Show this help message') { puts opts; puts; exit }

        opts.separator ""

        opts.separator "\tAdding 'NO_HARM=1' will run the command without actually executing any\n\tactions but only printing what it would do."

      end.parse!(_argv)
    end

    def self.nowrite(v = nil)
      # need to do this because of Rake version differences
      rv = Rake.__send__ :nowrite
      Rake.__send__(:nowrite, v) if v
      if block_given?
        begin
          yield
        ensure
          Rake.__send__(:nowrite, rv)
        end
      end
      rv
    end

    def self.verbose
      Rake.__send__ :verbose
    end

    def self.specs
      specs = [
        [get_config('bindir'), ['bin'], 0755],
        [get_config('rbdir'), ['lib/corba.rb'], 0644],
        [File.join(get_config('rbdir'), 'corba'), ['lib/corba'], 0644],
        [File.join(get_config('rbdir'), 'ridlbe'), ['lib/ridlbe'], 0644]
      ]
      if defined?(JRUBY_VERSION)
        jar_files = [File.join(get_config('jacorb_home'), 'lib', 'jacorb.jar'),
                     File.join(get_config('jacorb_home'), 'lib', 'jacorb-services.jar')] +
            Dir.glob(File.join(get_config('jacorb_home'), 'lib', 'slf4j*.jar')) +
            Dir.glob(File.join(get_config('jacorb_home'), 'lib', 'antlr*.jar'))
        specs << [File.join(get_config('siterubyverarch'), 'jacorb', 'lib'), jar_files, 0444]
      else
        unless get_config('without-tao')
          dll_ext = if R2CORBA::Config.is_win32
                      '.dll'
                    elsif R2CORBA::Config.is_osx
                      '.dylib'
                    else
                       '.so.*'
                    end
          dll_files = R2CORBA::Ext::ace_shlibs(dll_ext)
          dll_files = dll_files.collect {|p| Dir.glob(p).first } unless R2CORBA::Config.is_win32 || R2CORBA::Config.is_osx
          dll_files.concat(R2CORBA::Ext.sys_dlls) if R2CORBA::Config.is_win32
          specs << [get_config('aceinstdir'), dll_files, 0555]
        end
        specs << [get_config('sodir'), Dir['ext/*.so'], 0555]
      end
      if R2CORBA::Config.ridl_is_local?
        specs << [get_config('rbdir'), ['ridl/lib'], 0644, /\.rb$/]
      end
      specs
    end

    def self.install
      R2CORBA::Install.specs.each do |dest, srclist, mode, match|
        srclist.each do |src|
          if File.directory?(src)
            install_dir(src, dest, mode, match)
          else
            install_file(src, dest, mode) if match.nil? || match =~ src
          end
        end
      end
      unless get_config('without-tao') || defined?(JRUBY_VERSION) || !R2CORBA::Config.is_linux
        R2CORBA::Ext::ace_shlibs('.so', get_config('aceinstdir')).each do |acelib|
          acelib = File.join(get_config(:prefix), acelib) if get_config(:prefix)
          libver = File.expand_path(Dir.glob(acelib+'.*').first || (nowrite ? acelib+'.x.x.x' : nil))
          FileUtils.ln_s(libver, acelib, :force => true, :noop => nowrite, :verbose => verbose)
        end
      end
    end

    def self.uninstall
      unless get_config('without-tao') || defined?(JRUBY_VERSION) || !R2CORBA::Config.is_linux
        R2CORBA::Ext::ace_shlibs('.so', get_config('aceinstdir')).each do |acelib|
          acelib = File.join(get_config(:prefix), acelib) if get_config(:prefix)
          FileUtils.rm_f(acelib, :noop => nowrite, :verbose => verbose) if nowrite || File.exists?(acelib)
        end
      end
      R2CORBA::Install.specs.each do |dest, srclist, mode, match|
        srclist.each do |src|
          if File.directory?(src)
            uninstall_dir(src, dest, match)
          else
            uninstall_file(src, dest) if match.nil? || match =~ src
          end
        end
      end
    end

  end

  module InstallMethods

    def install_file(src, dest, mode)
      dest = File.join(get_config(:prefix), dest) if get_config(:prefix)
      FileUtils.mkdir_p(dest, :noop => nowrite, :verbose => verbose) unless File.directory?(dest)
      FileUtils.install(src, dest, :mode => mode, :noop => nowrite, :verbose => verbose)
    end
    def install_dir(dir, dest, mode, match)
      curdir = Dir.getwd
      begin
        FileUtils.cd(dir, :verbose => verbose)
        Dir.glob('*') do |entry|
          if File.directory?(entry)
            install_dir(entry, File.join(dest, entry), mode, match)
          else
            install_file(entry, dest, mode) if match.nil? || match =~ entry
          end
        end
      ensure
        FileUtils.cd(curdir, :verbose => verbose)
      end
    end
    def uninstall_file(src, dest)
      dest = File.join(get_config(:prefix), dest) if get_config(:prefix)
      dst_file = File.join(dest, File.basename(src))
      if nowrite || File.file?(dst_file)
        if nowrite || FileUtils.compare_file(src, dst_file)
          FileUtils.rm_f(dst_file, :noop => nowrite, :verbose => verbose)
        else
          $stderr.puts "ALERT: source (#{src}) differs from installed file (#{dst_file})"
        end
      end
    end
    def uninstall_dir(dir, dest, match)
      curdir = Dir.getwd
      begin
        FileUtils.cd(dir, :verbose => verbose)
        Dir.glob('*') do |entry|
          if File.directory?(entry)
            uninstall_dir(entry, File.join(dest, entry), match)
          else
            uninstall_file(entry, dest) if match.nil? || match =~ entry
          end
        end
      ensure
        FileUtils.cd(curdir, :verbose => verbose)
      end
    end

  end

end

include R2CORBA::InstallMethods
