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
            "Default: 'file://server.ior'") { |v| OPTIONS[:iorfile]=v }
    opts.on("--d LVL",
            "Set ORBDebugLevel value.",
            "Default: 0", Integer) { |v| OPTIONS[:orb_debuglevel]=v }
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
  CORBA.implement('test.idl', OPTIONS)
else
  require 'testC.rb'
end
require 'corba/policies.rb'

Min_timeout = 0
Max_timeout = 20

None, Orb1, Thread1, Object1 = (0..3).to_a
To_type_names = [ "none", "orb", "thread", "object" ]

Timeout_count = [0, 0, 0, 0]
In_time_count = [0, 0, 0, 0]

def send_echo (ctype, orb, server, t)
  begin
    server.echo(0, t)

    In_time_count[ctype] += 1
  rescue CORBA::TIMEOUT
      Timeout_count[ctype] += 1

      # Trap this exception and continue...
      puts "==> Trapped a TIMEOUT exception (expected)"

      # Sleep so the server can send the reply...
      tv = Max_timeout / 1000.0  # max_timeout is in msec, so get seconds

      ts_end = Time.now + tv
      begin
        orb.perform_work if orb.work_pending
        sleep 0.01
      end until Time.now > ts_end
      # This is a non-standard TAO call that's used to give the
      # client ORB a chance to cleanup the reply that's come back
      # from the server.
#orb.run(tv)
  end
end


orb = CORBA.ORB_init(["-ORBDebugLevel", OPTIONS[:orb_debuglevel]], 'myORB')

begin

  obj = orb.string_to_object(OPTIONS[:iorfile])

  assert_not 'Object reference is nil.', CORBA::is_nil(obj)

  simple_srv = Simple_Server._narrow(obj)

  obj = orb.resolve_initial_references('ORBPolicyManager')

  pol_man = CORBA::PolicyManager._narrow(obj)

  obj = begin
    orb.resolve_initial_references('PolicyCurrent')
  rescue CORBA::ORB::InvalidName
    STDERR.puts 'Client: PolicyCurrent not supported'
    nil
  end

  pol_cur = obj ? CORBA::PolicyCurrent._narrow(obj) : nil

  mid_value = 10000 * (Min_timeout + Max_timeout) / 2   # convert from msec to "TimeT" (0.1 usec units)

  any_orb = CORBA::Any.to_any(mid_value, TimeBase::TimeT._tc)
  any_thread = CORBA::Any.to_any(mid_value+10000, TimeBase::TimeT._tc) # midvalue + 1 msec
  any_object = CORBA::Any.to_any(mid_value+20000, TimeBase::TimeT._tc) # midvalue + 2 msec

  policies = []
  policies << orb.create_policy(Messaging::RELATIVE_RT_TIMEOUT_POLICY_TYPE, any_object)

  obj = simple_srv._set_policy_overrides(policies, CORBA::SET_OVERRIDE)

  simple_timeout_srv = Simple_Server._narrow(obj)

  policies[0].destroy()
  policies[0] = nil

  puts "client (#{Process.pid}) testing from #{Min_timeout} to #{Max_timeout} milliseconds"

  for t in Min_timeout...Max_timeout
    puts ""
    puts "client (#{Process.pid}) ================================"
    puts "client (#{Process.pid}) Trying with timeout = #{t} msec"

    puts "client (#{Process.pid}) Cleanup ORB/Thread/Object policies"

    policies.clear()
    pol_man.set_policy_overrides(policies, CORBA::SET_OVERRIDE)
    pol_cur.set_policy_overrides(policies, CORBA::SET_OVERRIDE) if pol_cur

    send_echo(None, orb, simple_srv, t)

    puts "client (#{Process.pid}) Set the ORB policies"

    policies << orb.create_policy(Messaging::RELATIVE_RT_TIMEOUT_POLICY_TYPE,
                                  any_orb)

    pol_man.set_policy_overrides(policies, CORBA::SET_OVERRIDE)

    send_echo(Orb1, orb, simple_srv, t)

    policies[0].destroy()

    if pol_cur
      puts "client (#{Process.pid}) Set the thread policies"

      policies.clear()
      policies << orb.create_policy(Messaging::RELATIVE_RT_TIMEOUT_POLICY_TYPE,
                                    any_thread)

      pol_cur.set_policy_overrides(policies, CORBA::SET_OVERRIDE)

      send_echo(Thread1, orb, simple_srv, t)

      policies[0].destroy()
    end

    puts "client (#{Process.pid}) Use the object policies"

    send_echo(Object1, orb, simple_timeout_srv, t)
  end

  puts "\n\n"
  puts "client (#{Process.pid}) Test completed, resynch with server"

  policies.clear()
  pol_man.set_policy_overrides(policies, CORBA::SET_OVERRIDE)
  pol_cur.set_policy_overrides(policies, CORBA::SET_OVERRIDE) if pol_cur

  send_echo(None, orb, simple_srv, 0)

  simple_srv.shutdown()

  timeout_count_total = 0
  in_time_count_total = 0
  for i in 0..3
    timeout_count_total += Timeout_count[i]
    in_time_count_total += In_time_count[i]
    puts "client (#{Process.pid}) in_time_count[#{To_type_names[i]}]= #{In_time_count[i]} "+
                                "timeout_count[#{To_type_names[i]}]= #{Timeout_count[i]}"
  end

  assert_not "client (#{Process.pid}) ERROR: No messages timed out", timeout_count_total == 0

  assert_not "client (#{Process.pid}) ERROR: No messages on time (within time limit)", in_time_count_total == 0

  puts "client (#{Process.pid}) in_time_count_total = #{in_time_count_total}, timeout_count_total = #{timeout_count_total}"

  sleep(0.1)

ensure

  orb.destroy()

end
