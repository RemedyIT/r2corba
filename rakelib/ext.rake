#--------------------------------------------------------------------
# ext.rake - build file
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

  namespace :r2corba do
    namespace :ext do
      task :build # noop
    end
  end

else # !JRUBY_VERSION

  require File.join(File.dirname(__FILE__), 'ext.rb')

  file R2CORBA::Ext.r2tao_mpc_file do |t|
    File.open(t.name, 'w') {|f| f.puts R2CORBA::Ext::R2TAO_MPC }
  end

  file R2CORBA::Ext.rpoa_mpc_file do |t|
    File.open(t.name, 'w') {|f| f.puts R2CORBA::Ext::RPOA_MPC }
  end

  file R2CORBA::Ext.rpol_mpc_file do |t|
    File.open(t.name, 'w') {|f| f.puts R2CORBA::Ext::RPOL_MPC }
  end

  file R2CORBA::Ext.ext_makefile => [R2CORBA::BUILD_CFG,
                                     R2CORBA::Ext.default_features_path,
                                     R2CORBA::Ext.ace_config_path,
                                     R2CORBA::Ext.platform_macros_path,
                                     R2CORBA::Ext.r2tao_mpc_file,
                                     R2CORBA::Ext.rpoa_mpc_file,
                                     R2CORBA::Ext.rpol_mpc_file] do
    # check availability of PERL
    raise "PERL missing! A working version of PERL in the PATH is required." unless system('perl -v')
    # configure R2TAO build
    _mwc = File.join(get_config('aceroot'), 'bin', 'mwc.pl')

    cur_dir = Dir.getwd
    Dir.chdir 'ext'
    begin
      sh("perl #{_mwc} -type gnuace ext.mwc -workers #{R2CORBA::Config.cpu_cores}")
    ensure
      Dir.chdir cur_dir
    end
  end

  CLOBBER.include [R2CORBA::Ext.ext_makefile, R2CORBA::Ext.r2tao_mpc_file, R2CORBA::Ext.rpoa_mpc_file, R2CORBA::Ext.rpol_mpc_file]

  namespace :r2corba do
    namespace :ext do
      #desc 'Build extension libraries'
      task :build => R2CORBA::Ext.ext_makefile do
        cur_dir = Dir.getwd
        Dir.chdir 'ext'
        begin
          sh("#{get_config('makeprog')}#{get_config('with-debug') ? ' debug=1' : ''}")
        ensure
          Dir.chdir cur_dir
        end
        R2CORBA::Ext.post_build
      end

      task :clobber do
        cur_dir = Dir.getwd
        Dir.chdir 'ext'
        begin
          sh("#{get_config('makeprog')} realclean") if File.exist?('GNUmakefile')
        ensure
          Dir.chdir cur_dir
        end
      end
    end
  end

  Rake::Task['clobber'].enhance ['r2corba:ext:clobber']

  # Do we handle ACE+TAO here?
  unless get_config('without-tao')

    file R2CORBA::Ext.ace_config_path => R2CORBA::BUILD_CFG do |t|
      File.open(t.name, "w") {|f|
        f.puts R2CORBA::Ext.ace_config
      }
    end

    CLOBBER.include R2CORBA::Ext.ace_config_path

    file R2CORBA::Ext.platform_macros_path => R2CORBA::BUILD_CFG do |t|
      File.open(t.name, "w") {|f|
        f.puts R2CORBA::Ext.platform_macros
      }
    end

    CLOBBER.include R2CORBA::Ext.platform_macros_path

    file R2CORBA::Ext.default_features_path => R2CORBA::BUILD_CFG do |t|
      File.open(t.name, "w") do |f|
        f.puts R2CORBA::Ext.default_features
      end
    end

    CLOBBER.include R2CORBA::Ext.default_features_path

    file R2CORBA::Ext.tao_mwc_path => R2CORBA::BUILD_CFG do |t|
      File.open(t.name, "w") do |f|
        f.puts R2CORBA::Ext.tao_mwc
      end
    end

    CLOBBER.include R2CORBA::Ext.tao_mwc_path

    file R2CORBA::Ext.tao_makefile => [R2CORBA::Ext.ace_config_path,
                                       R2CORBA::Ext.platform_macros_path,
                                       R2CORBA::Ext.default_features_path,
                                       R2CORBA::Ext.tao_mwc_path]  do
      # check availability of PERL
      raise "PERL missing! A working version of PERL in the PATH is required." unless system('perl -v')
      # generate ACE+TAO makefile
      cur_dir = Dir.getwd
      Dir.chdir File.expand_path(get_config('aceroot'))
      begin
        sh("perl bin/mwc.pl -type gnuautobuild TAO4Ruby.mwc -workers #{R2CORBA::Config.cpu_cores}")
      ensure
        Dir.chdir cur_dir
      end
    end

    CLOBBER.include R2CORBA::Ext.tao_makefile

    namespace :r2corba do
      namespace :ext do
        task :build_tao

        R2CORBA::Ext::ace_shlibs.each do |acelib|
          file acelib => R2CORBA::Ext.tao_makefile do
            # build ACE+TAO
            cur_dir = Dir.getwd
            Dir.chdir File.expand_path(get_config('aceroot'))
            begin
              sh("#{get_config('makeprog')} -j#{R2CORBA::Config.cpu_cores} #{get_config('with-debug') ? ' debug=1' : ''}")
            ensure
              Dir.chdir cur_dir
            end
            # touch all libraries to cover the case that the timestamps do not match
            # the makefile but make triggers not rebuild as no sources have changed
            touch(R2CORBA::Ext::ace_shlibs)
          end
          Rake::Task['r2corba:ext:build_tao'].enhance [acelib]
        end

        task :clobber_tao do
          # clean ACE+TAO
          cur_dir = Dir.getwd
          ace_root = File.expand_path(get_config('aceroot'))
          if File.exist?(ace_root)
            Dir.chdir ace_root
            begin
              sh("#{get_config('makeprog')} realclean") if File.exist?('GNUmakefile')
            ensure
              Dir.chdir cur_dir
            end
          end
        end
      end
    end

    Rake::Task['r2corba:ext:build'].enhance ['r2corba:ext:build_tao']
    Rake::Task['r2corba:ext:clobber'].enhance ['r2corba:ext:clobber_tao']

  end # !without-tao

end # defined?(JRUBY_VERSION)
