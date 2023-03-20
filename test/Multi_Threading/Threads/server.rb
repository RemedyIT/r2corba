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
  watchdog_iorfile: 'file://watchdog.ior'
}

ARGV.options do |opts|
    script_name = File.basename($0)
    opts.banner = "Usage: ruby #{script_name} [options]"

    opts.separator ''

    opts.on('--o IORFILE',
            'Set IOR filename.',
            "Default: 'server.ior'") { |v| OPTIONS[:iorfile] = v }
    opts.on('--w IORFILE',
            'Set Watchdog IOR filename.',
            "Default: 'file://watchdog.ior'") { |v| OPTIONS[:watchdog_iorfile] = v }
    opts.on('--d LVL',
            'Set ORBDebugLevel value.',
            'Default: 0') { |v| OPTIONS[:orb_debuglevel] = v }
    opts.on('--use-implement',
            'Load IDL through CORBA.implement() instead of precompiled code.',
            'Default: off') { |v| OPTIONS[:use_implement] = v }

    opts.separator ''

    opts.on('-h', '--help',
            'Show this help message.') { puts opts; exit }

    opts.parse!
end

if OPTIONS[:use_implement]
  require 'corba/poa'
  CORBA.implement('Test.idl', OPTIONS, CORBA::IDL::SERVANT_INTF)
else
  require 'TestS.rb'
end

class MyHello < POA::Test::Hello
  def initialize(orb, watchdog)
    @orb = orb
    @watchdog = watchdog
    @count = 0
    @stop = false
    @wdt = Thread.new do
      while !@stop
        @watchdog.ping(self.object_id.to_s)
        @count += 1
        sleep 0.001
      end
    end
  end

  def get_string()
    return 'Hello, world!'
  end

  def shutdown()
    @stop = true
    @wdt.join
    @watchdog.shutdown
    puts %Q{Server - pinged watchdog #{@count} times.}
    @orb.shutdown
  end
end # of servant MyHello

orb = CORBA.ORB_init(['-ORBDebugLevel', OPTIONS[:orb_debuglevel]], 'myORB')

obj = orb.resolve_initial_references('RootPOA')

root_poa = PortableServer::POA._narrow(obj)

poa_man = root_poa.the_POAManager

poa_man.activate

obj = orb.string_to_object(OPTIONS[:watchdog_iorfile])

watchdog_obj = Test::Watchdog._narrow(obj)

hello_srv = MyHello.new(orb, watchdog_obj)

hello_obj = hello_srv._this

hello_ior = orb.object_to_string(hello_obj)

File.open(OPTIONS[:iorfile], 'w') { |io|
  io.write hello_ior
}

Signal.trap('INT') do
  puts 'SIGINT - shutting down ORB...'
  orb.shutdown
end

if Signal.list.has_key?('USR2')
  Signal.trap('USR2', 'EXIT')
end

orb.run
