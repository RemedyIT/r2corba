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

OPTIONS = {
  use_implement: false,
  orb_debuglevel: 0,
  iorfile: 'server.ior',
  iter_num: 10
}

ARGV.options do |opts|
    script_name = File.basename($0)
    opts.banner = "Usage: ruby #{script_name} [options]"

    opts.separator ''

    opts.on('--o IORFILE',
            'Set IOR filename.',
            "Default: 'server.ior'") { |v| OPTIONS[:iorfile] = v }
    opts.on('--d LVL',
            'Set ORBDebugLevel value.',
            'Default: 0') { |v| OPTIONS[:orb_debuglevel] = v }
    opts.on('--use-implement',
            'Load IDL through CORBA.implement() instead of precompiled code.',
            'Default: off') { |v| OPTIONS[:use_implement] = v }
    opts.on('--i ITERATIONS',
            'Set number of iterations.',
            'Default: 10', Integer) { |v| OPTIONS[:iter_num] = v }

    opts.separator ''

    opts.on('-h', '--help',
            'Show this help message.') { puts opts; exit }

    opts.parse!
end

if OPTIONS[:use_implement]
  require 'corba/poa.rb'
  CORBA.implement('test.idl', OPTIONS, CORBA::IDL::SERVANT_INTF)
else
  require 'testS.rb'
end

class Simple_Server_i < POA::Simple_Server
  def initialize(orb)
    @orb = orb
  end

  def echo(x, msecs)
    sleep_time = msecs / 1000.0

    puts "server (#{Process.pid}) will request sleep for #{sleep_time.to_s} sec"

    t = Time.now
    sleep(sleep_time)

    puts "server (#{Process.pid}) actually slept for #{(Time.now - t).to_s} sec"

    return x
  end

  def shutdown()
    puts "server (#{Process.pid}) received shutdown request from client"
    @orb.shutdown
  end
end # of servant Simple_Server_i

orb = CORBA.ORB_init(['-ORBDebugLevel', OPTIONS[:orb_debuglevel]], 'myORB')

obj = orb.resolve_initial_references('RootPOA')

root_poa = PortableServer::POA._narrow(obj)

poa_man = root_poa.the_POAManager

poa_man.activate

simple_srv = Simple_Server_i.new(orb)

simple_ref = simple_srv._this

ior = orb.object_to_string(simple_ref)

File.open(OPTIONS[:iorfile], 'w') { |io|
  io.write ior
}

Signal.trap('INT') do
  puts 'SIGINT - shutting down ORB...'
  orb.shutdown
end

if Signal.list.has_key?('USR2')
  Signal.trap('USR2', 'EXIT')
end

orb.run
