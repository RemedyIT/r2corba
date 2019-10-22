#--------------------------------------------------------------------
# mkrf_conf_srcgem.rb - Rakefile generator src gem installation
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

task :default => 'r2corba:gem:srcbuild'
EOF__
end

require 'optparse'

if defined?(JRUBY_VERSION)

  usage_text =<<-__EOT
Make sure you have provided a JACORB_HOME definition pointing at a valid JacORB installation
with all required .jar files located at JACORB_HOME\lib. You can do this either by setting
the JACORB_HOME environment variable or by providing the --jacorb-home buildflag to the
'gem install' command.
Checkout the documentation at http://osportal.remedy.nl/projects/r2corba
for more information.
__EOT

  jacorb_home = ENV['JACORB_HOME']

  opts = OptionParser.new
  opts.on('--jacorb-home=path',
          'the path to the root directory of JacORB')  {|v| jacorb_home = v}
  opts.parse!(ARGV)

  # check for proper JacORB installation
  if jacorb_home
    jar_files = Dir.glob(File.join(jacorb_home, 'lib', 'jacorb.jar'))+
                Dir.glob(File.join(jacorb_home, 'lib', 'jacorb-services.jar')) +
                Dir.glob(File.join(jacorb_home, 'lib', 'slf4j*.jar')) +
                Dir.glob(File.join(jacorb_home, 'lib', 'antlr*.jar'))
    if jar_files.size == 5
      # run configure with appropriate settings
      puts "Valid JacORB installation found.\n"+
           "Running 'ruby -S rake -- configure --without-jacorb --jacorb-home=#{jacorb_home}'"
      unless system("ruby -S rake -- configure --without-jacorb --jacorb-home=#{jacorb_home}")
        puts 'Failed to configure R2CORBA'
        exit(1)
      end
      exit(0)
    end
    puts 'JACORB_HOME defined but cannot find a valid JacORB installation.'
    puts usage_text
    exit(1)
  end
  puts 'No JACORB_HOME defined. Missing JacORB installation.'
  puts usage_text
  exit(1)

else

  require 'rbconfig'
  if defined? ::RbConfig
    RB_CONFIG = ::RbConfig
  else
    RB_CONFIG = ::Config
  end unless defined? RB_CONFIG
  RB_CONFIG::MAKEFILE_CONFIG['TRY_LINK'] = "$(CXX) #{RB_CONFIG::MAKEFILE_CONFIG['OUTFLAG']}conftest#{$EXEEXT} $(INCFLAGS) $(CPPFLAGS) " \
      "$(CFLAGS) $(src) $(LIBPATH) $(LDFLAGS) $(ARCH_FLAG) $(LOCAL_LIBS) $(LIBS)"
  require 'mkmf'
  if defined?(MakeMakefile)
    MakeMakefile::COMMON_HEADERS.clear
  elsif defined?(COMMON_HEADERS)
    COMMON_HEADERS.slice!(/./)
  end

  usage_txt =<<-__EOT
Please define a valid ACE/TAO build environment either by defining the ACE_ROOT and (optionally)
the TAO_ROOT (defaults to ACE_ROOT/TAO) and MPC_ROOT (defaults to ACE_ROOT/MPC) environment
variable OR by providing the --aceroot and (optionally) --taoroot and --mpcroot build flags to
the 'gem install' command.
Alternatively you can have the r2corba gem install the taosource gem for you and use that for
the ACE/TAO build environment by *not* providing the --without-taogem build flag to the 'gem install'
command.
Checkout the documentation at http://osportal.remedy.nl/projects/r2corba for more information.
__EOT

  install_taosource_gem = true
  ace_root = ENV['ACE_ROOT']
  tao_root = ENV['TAO_ROOT']
  mpc_root = ENV['MPC_ROOT']

  opts = OptionParser.new
  opts.on('--aceroot=path',
          'the path to the root directory of ACE')  {|v| ace_root = v}
  opts.on('--taoroot=path',
          'the path to the root directory of TAO')  {|v| tao_root = v}
  opts.on('--mpcroot=path',
          'the path to the root directory of MPC')  {|v| mpc_root = v}
  opts.on('--without-taogem',
          'do not use the taosource gem')  {|v| install_taosource_gem = false }
  opts.parse!(ARGV)

  # Check if we should use the taogem to install a private ACE/TAO version?
  if install_taosource_gem

    # install taosource gem as a dependent gem
    require 'rubygems'
    require 'rubygems/command.rb'
    require 'rubygems/dependency_installer.rb'
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
      inst.install "taosource", ">= 6.1.8"
    rescue
      $stderr.puts 'Failed to install taosource gem.'
      exit(1)
    end

    # initialize root paths by loading this
    require 'taosource/rootpaths'
    ext_dir = File.expand_path('ext')
    # run configure with appropriate settings
    puts "Running 'rake -- configure --aceroot=#{ENV['ACE_ROOT']} --taoroot=#{ENV['TAO_ROOT']} --mpcroot=#{ENV['MPC_ROOT']} --aceinstdir=#{ext_dir}'"
    unless system("rake -- configure --aceroot=#{ENV['ACE_ROOT']} --taoroot=#{ENV['TAO_ROOT']} --mpcroot=#{ENV['MPC_ROOT']} --aceinstdir=#{ext_dir}")
      $stderr.puts 'Failed to configure R2CORBA'
      exit(1)
    end

  elsif ace_root  # OR is there an ACE/TAO version installed which we should reuse?

    # check for a valid MPC environment
    mpc_root ||= File.join(ace_root, 'MPC')
    unless mpc_root && File.directory?(mpc_root) && File.file?(File.join(ace_root, 'bin', 'mwc.pl'))
      puts 'ACE_ROOT defined but cannot find a valid MPC environment!'
      puts usage_txt
      exit(1)
    end

    # check for valid TAO dev environment
    tao_root ||= File.join(ace_root, 'TAO')
    unless have_library('TAO', 'int a=0; CORBA::ORB_init(a, 0)', ['tao/corba.h'], "-x c++ -I#{ace_root} -I#{tao_root} -L#{File.join(ace_root, 'lib')} -lACE")
      puts 'ACE_ROOT defined but cannot link TAO libary!'
      puts usage_txt
      exit(1)
    end

    # run configure with appropriate settings
    puts "Running 'rake -- configure --without-tao --aceroot=#{ace_root} --taoroot=#{tao_root} --mpcroot=#{mpc_root}'"
    unless system("rake -- configure --without-tao --aceroot=#{ace_root} --taoroot=#{tao_root} --mpcroot=#{mpc_root}")
      puts 'Failed to configure R2CORBA'
      exit(1)
    end

  else

    puts 'Missing ACE/TAO build environment.'
    puts usage_txt
    exit(1)

  end

end
