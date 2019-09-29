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
  :iorfile => 'file://server.ior'
}

ARGV.options do |opts|
    script_name = File.basename($0)
    opts.banner = "Usage: ruby #{script_name} [options]"

    opts.separator ""

    opts.on("--k IORFILE",
            "Set IOR.",
            "Default: 'file://server.ior'") { |v| OPTIONS[:iorfile]=v }
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

orb = CORBA.ORB_init(["-ORBDebugLevel", OPTIONS[:orb_debuglevel]], 'myORB')

DATA = 'Hello world! 0123456789012345678901234567890123456789012345678901234567890123456789'

begin

  obj = orb.string_to_object(OPTIONS[:iorfile])

  hello_obj = Test::Hello._narrow(obj)

  # run once to initialize the whole path
  hello_obj.do_test(0, DATA)

  t_start = Time.now

  # run test
  10000.times do |i|
    count_, data_ = hello_obj.do_test(i, DATA)
  end

  t_diff = Time.now - t_start

  STDERR.puts "*** Avg turnaround time per invocation = #{'%.2f' % (t_diff / 10)} msec"

  hello_obj.shutdown()

  assert_not "ERROR: Object is reported nil!", CORBA::is_nil(hello_obj)

  hello_obj._free_ref()

  assert "ERROR: Object is reported non-nil!", CORBA::is_nil(hello_obj)

ensure

  orb.destroy()

end
