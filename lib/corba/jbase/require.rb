#--------------------------------------------------------------------
# require.rb - R2CORBA loader
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
require 'java'

module R2CORBA
  if ENV['JACORB_HOME'] &&
      (File.exists?(File.join(ENV['JACORB_HOME'], 'lib', 'jacorb.jar')) ||
       Dir[File.join(ENV['JACORB_HOME'], 'lib', 'jacorb-*.jar')].any? {|p| p =~ /\/jacorb\-\d\.\d\.jar\Z/})
    JACORB_HOME = ENV['JACORB_HOME']
  else
    # find jacorb.jar in library search path
    JACORB_HOME = File.dirname(($:.find { |path| Dir[File.join(path, 'jacorb-*.jar')].any? {|p| p =~ /\/jacorb(\.jar|\-\d\.\d\.jar)\Z/} }).to_s)
  end

  $LOAD_PATH << File.join(JACORB_HOME, 'lib')
  module JavaLang
    include_package 'java.lang'
    ## Only works if passed as Java commandline arg
    # prop = System.getProperties['java.endorsed.dirs']
    # System.setProperty('java.endorsed.dirs', "#{File.join(R2CORBA::JACORB_HOME, 'lib')}:#{prop}")
    System.setProperty('jacorb.home', "#{R2CORBA::JACORB_HOME}")
    System.setProperty('org.omg.CORBA.ORBClass', 'org.jacorb.orb.ORB')
    System.setProperty('org.omg.CORBA.ORBSingletonClass', 'org.jacorb.orb.ORBSingleton')
    System.setProperty('jacorb.orb.print_version', $VERBOSE ? 'on' : 'off')
    System.setProperty('jacorb.log.default.verbosity', $VERBOSE ? '3' : '1')
  end
end

# add required JAR files for JacORB from searchpath
Dir.glob(File.join(R2CORBA::JACORB_HOME, 'lib', '*.jar')).each do |jar|
  require File.basename(jar)
end

module R2CORBA
  module CORBA
    module Native
      # first include CORBA::Object separately to avoid 'Object' replacement warnings
      java_import 'org.omg.CORBA.Object'
      include_package 'org.omg.CORBA'
      module Portable
        include_package 'org.omg.CORBA.portable'
      end
      module V2_3
        include_package 'org.omg.CORBA_2_3'
        module Portable
          include_package 'org.omg.CORBA.portable'
        end
      end
      module V2_5
        include_package 'org.omg.CORBA_2_5'
      end
      module V3_0
        include_package 'org.omg.CORBA_3_0'
      end
      module Jacorb
        module Util
          java_import org.jacorb.util.Version
        end
        VERSION = Util::Version.version
        va = VERSION.split('.')
        MAJOR_VERSION = va.shift.to_i
        MINOR_VERSION = va.shift.to_i
        RELEASE_NR = va.shift.to_i
      end
    end
  end
end

[ 'exception',
  'Object',
  'ORB',
  'Request',
  'Stub',
  'Typecode',
  'Any',
  'Values',
  'Streams'
].each { |f| require "corba/jbase/#{f}.rb" }
