#--------------------------------------------------------------------
# build.rake - build file
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

namespace :r2corba do
  task :build_bin => [R2CORBA::BUILD_CFG]

  #desc 'Compile R2CORBA base IDL files'
  task :build_idl => [R2CORBA::BUILD_CFG]

  task :build => [R2CORBA::BUILD_CFG] # everything handled in dependecies
end

unless defined?(JRUBY_VERSION)
  Rake::Task['r2corba:build'].enhance ['r2corba:ext:build']
end
Rake::Task['r2corba:build'].enhance ['r2corba:bin:build', 'r2corba:build_idl']

desc 'Build R2CORBA'
task :build => 'r2corba:build'

## compile base IDL

r2c_idlc_root = File.join('lib','corba','idl')
stdidl_root = File.join('lib', 'idl')

orb_pidlc = File.join('lib', 'ridlbe','ruby','orb.pidlc')
file orb_pidlc => [R2CORBA::BUILD_CFG] do |t|
  sh("#{R2CORBA::Config.ridlc} --preprocess --output #{t.name} --include=#{stdidl_root} orb.idl")
end
Rake::Task['r2corba:build_idl'].enhance [orb_pidlc]
CLOBBER.include orb_pidlc

file File.join(r2c_idlc_root,'r2c_orb.rb') => [R2CORBA::BUILD_CFG, orb_pidlc] do |t|
  cmd = R2CORBA::Config.ridlc
  cmd << " --ignore-pidl --output #{t.name} --namespace=R2CORBA --include=#{stdidl_root}" <<
         " --stubs-only --expand-includes --search-includepath --no-libinit --interface-as-class=TypeCode orb.idl"
  sh(cmd)
end
Rake::Task['r2corba:build_idl'].enhance [File.join(r2c_idlc_root,'r2c_orb.rb')]
CLOBBER.include File.join(r2c_idlc_root,'r2c_orb.rb')

[ ['POA', 'PortableServer.pidl'],
  ['Messaging', 'Messaging.pidl'],
  ['BiDirPolicy', 'BiDirPolicy.pidl'],
].each do |stub, pidl|
  file File.join(r2c_idlc_root,stub + 'C.rb') => [R2CORBA::BUILD_CFG, orb_pidlc] do |t|
    cmd = R2CORBA::Config.ridlc
    cmd << " --output #{t.name} --namespace=R2CORBA --include=#{stdidl_root} --stubs-only --expand-includes --search-includepath --no-libinit #{pidl}"
    sh(cmd)
  end
  Rake::Task['r2corba:build_idl'].enhance [File.join(r2c_idlc_root,stub + 'C.rb')]
  CLOBBER.include File.join(r2c_idlc_root,stub + 'C.rb')
end

unless defined?(JRUBY_VERSION)
  r2tao_root = File.join('lib','corba','cbase')
  tao_root = get_config('taoroot')
  [ 'TAO_Ext', 'IORTable' ].each do |stub|
    file File.join(r2c_idlc_root,stub + 'C.rb') => [R2CORBA::BUILD_CFG, orb_pidlc] do |t|
      cmd = R2CORBA::Config.ridlc
      cmd << " --output #{t.name} --namespace=R2CORBA --include=#{stdidl_root} --stubs-only --expand-includes -I#{tao_root}" <<
          " --search-includepath --no-libinit #{File.join(r2c_idlc_root, stub + '.pidl')}"
      sh(cmd)
    end
    Rake::Task['r2corba:build_idl'].enhance [File.join(r2c_idlc_root,stub + 'C.rb')]
    CLOBBER.include File.join(r2c_idlc_root,stub + 'C.rb')
  end
end

file File.join(r2c_idlc_root, 'CosNamingC.rb') => [R2CORBA::BUILD_CFG, orb_pidlc] do |t|
  cmd = R2CORBA::Config.ridlc
  cmd << " -o #{r2c_idlc_root} --include=#{stdidl_root} --expand-includes --search-includepath CosNaming.idl"
  sh(cmd)
end
Rake::Task['r2corba:build_idl'].enhance [File.join(r2c_idlc_root,'CosNamingC.rb')]
CLOBBER.include File.join(r2c_idlc_root,'CosNamingC.rb')
