#--------------------------------------------------------------------
#
# Author: Martin Corino
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the R2CORBA LICENSE which is
# included with this program.
#
# Copyright (c) Remedy IT Expertise BV
#--------------------------------------------------------------------

require 'optparse'
require 'lib/assert.rb'
include TestUtil::Assertions

OPTIONS = {
  :use_implement => false,
  :orb_debuglevel => 0,
  :iorfile => 'file://server.ior'
}

ARGV.options do |opts|
    script_name = File.basename($0)
    opts.banner = "Usage: ruby #{script_name} [options]"

    opts.separator ""

    opts.on("--k IORFILE",
            "Set IOR.",
            "Default: 'file://server.ior'") { |v| OPTIONS[:iorfile] = v }
    opts.on("--d LVL",
            "Set ORBDebugLevel value.",
            "Default: 0") { |v| OPTIONS[:orb_debuglevel] = v }
    opts.on("--use-implement",
            "Load IDL through CORBA.implement() instead of precompiled code.",
            "Default: off") { |v| OPTIONS[:use_implement] = v }

    opts.separator ""

    opts.on("-h", "--help",
            "Show this help message.") { puts opts; exit }

    opts.parse!
end

if OPTIONS[:use_implement]
  require 'corba'
  CORBA.implement('Test.idl', OPTIONS)
else
  require 'TestC.rb'
end

orb = CORBA.ORB_init(["-ORBDebugLevel", OPTIONS[:orb_debuglevel]], 'myORB')

begin

  obj = orb.string_to_object(OPTIONS[:iorfile])

  unless defined?(JRUBY_VERSION) && CORBA::Native::Jacorb::MAJOR_VERSION == 3 &&
      ([4, 5].include? CORBA::Native::Jacorb::MINOR_VERSION)
    ## JacORB 3.4 introduced an optimization which *requires* use of the Java endorsed dirs
    ## mechanism to replace standard JDK CORBA stubs with the JacORB version in order to
    ## have JacORB process these base methods correctly with DSI servants
    ## JacORB 3.6 may be released with a fix for this
    id = obj._repository_id # fetches id remotely as obj has not been narrowed
                            # yet and thus there is no type known yet

    assert 'incorrect repository id returned (1)', id == Test::Hello._tc.id

    STDERR.puts "Got Object reference for [#{id}]"

    hello_obj = Test::Hello._narrow(obj)

    id = obj._repository_id # returns locally known id as obj has been narrowed
                            # and thus type is known

    assert 'incorrect repository id returned (2)', id == Test::Hello._tc.id

    the_string = hello_obj.get_string()

    puts "string returned <#{the_string}>"

    obj = hello_obj._get_component

    id = obj._repository_id # fetches id remotely which is doctored by
                            # overridden servant method

    assert 'original repository id returned', id != Test::Hello._tc.id

    STDERR.puts "Got Object reference for [#{id}]"

    # since _is_a? is also overridden we still get a match on the original id
    assert '_is_a? returned FALSE', obj._is_a?(Test::Hello._tc.id)

    hello2_obj = Test::Hello._narrow(obj)

    id = obj._repository_id # returns locally known id as obj has been narrowed
                            # and thus type is known

    assert 'incorrect repository id returned (3)', id == Test::Hello._tc.id
  else
    hello2_obj = Test::Hello._narrow(obj)
  end

  hello2_obj.shutdown()

ensure

  orb.destroy()

end
