#--------------------------------------------------------------------
#
# Author: Martin Corino
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the R2CORBA LICENSE which is
# included with this program.
#
# Copyright (c) Remedy IT Expertise BV
# Chamber of commerce Rotterdam nr.276339, The Netherlands
#--------------------------------------------------------------------

require 'optparse'
require 'lib/assert.rb'
include TestUtil::Assertions

OPTIONS = {
  :use_implement => false,
  :orb_debuglevel => 0,
  :ior => 'corbaloc:iiop:192.3.47.5/10007/RandomObject'
}

ARGV.options do |opts|
    script_name = File.basename($0)
    opts.banner = "Usage: ruby #{script_name} [options]"

    opts.separator ""

    opts.on("--k IOR",
            "Set IOR.",
            "Default: 'corbaloc:iiop:192.3.47/10007/RandomObject'") { |v| OPTIONS[:ior]=v }
    opts.on("--d LVL",
            "Set ORBDebugLevel value.",
            "Default: 0") { |v| OPTIONS[:orb_debuglevel]=v }
    opts.on("--use-implement",
            "Load IDL through CORBA.implement() instead of precompiled code.",
            "Default: off") { |v| OPTIONS[:use_implement]=v }

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
require 'corba/policies.rb'

begin STDERR.puts 'Not supported on this platform'; exit(0); end unless defined?(TAO::CONNECTION_TIMEOUT_POLICY_TYPE)

Timeout_period = 1000000

def test_timeout(object)
  # Start the timer
  profile_timer = Time.now

  begin
    # First connection happens here..
    hello = Test::Hello._narrow(object)

    assert_not "Nil Test::Hello reference", CORBA::is_nil(hello)

    the_string = hello.get_string()

    puts "string returned <#{the_string}>"

    hello.shutdown()
  rescue CORBA::Exception
    # Get the elampsed time
    el = Time.now - profile_timer

    # Give a 30% error margin for handling exceptions etc. It is a
    # high margin, though!. But the timeout is too small and wider
    # range would help.
    # The elapsed time is in secs
    assert "ERROR: Too long to timeout: #{el.to_s}", el <= 0.200

    puts "Success, timeout: #{el.to_s}"
  end
end


orb = CORBA.ORB_init(["-ORBDebugLevel", OPTIONS[:orb_debuglevel]], 'myORB')

begin
  tmp = orb.string_to_object(OPTIONS[:ior])

  object = orb.resolve_initial_references("PolicyCurrent")

  policy_current = CORBA::PolicyCurrent::_narrow(object)

  policy_list = []
  policy_list << orb.create_policy(TAO::CONNECTION_TIMEOUT_POLICY_TYPE,
                        CORBA::Any.to_any(Timeout_period, TimeBase::TimeT._tc))

  policy_current.set_policy_overrides(policy_list,
                                        CORBA::ADD_OVERRIDE)

  policy_list.each { |p| p.destroy() }

  test_timeout(tmp)
ensure
  orb.destroy()
end

