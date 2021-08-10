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
  :use_implement => false,
  :orb_debuglevel => 0,
  :iorfile => 'server.ior'
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

    opts.separator ''

    opts.on('-h', '--help',
            'Show this help message.') { puts opts; exit }

    opts.parse!
end

if OPTIONS[:use_implement]
  require 'corba/poa'
  CORBA.implement('OBV.idl', OPTIONS, CORBA::IDL::SERVANT_INTF)
else
  require 'OBVS'
end

require 'OBV_impl'

class Checkpoint_i < POA::Checkpoint
  def initialize(orb)
    @orb = orb
  end

  def put_event(event)
    event.do_print('server')
  end

  def shutdown()
    @orb.shutdown()
  end
end #of servant MyHello

orb = CORBA.ORB_init(['-ORBDebugLevel', OPTIONS[:orb_debuglevel]], 'myORB')

# make sure valuetype factory is registered
Event_factory.get_factory(orb)

obj = orb.resolve_initial_references('RootPOA')

root_poa = PortableServer::POA._narrow(obj)

poa_man = root_poa.the_POAManager

poa_man.activate

checkpoint = Checkpoint_i.new(orb)

obj = checkpoint._this()

ior = orb.object_to_string(obj)

open(OPTIONS[:iorfile], 'w') { |io|
  io.write ior
}

Signal.trap('INT') do
  puts 'SIGINT - shutting down ORB...'
  orb.shutdown()
end

if Signal.list.has_key?('USR2')
  Signal.trap('USR2', 'EXIT')
end

orb.run
