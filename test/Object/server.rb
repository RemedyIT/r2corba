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
  iorfile: 'server.ior'
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
  CORBA.implement('Test.idl', OPTIONS, CORBA::IDL::SERVANT_INTF)
else
  require 'TestS.rb'
end

class MyHello < POA::Test::Hello
  def initialize(orb)
    @orb = orb
  end

  def get_string()
    'Hello there!'
  end

  def shutdown()
    @orb.shutdown
  end

  ## overrides for standard CORBA::Object methods
  def _get_component
    # misuse this method to
    # create second servant and
    hello_srv = MyHello2.new(@orb)
    # activate and return object ref
    hello_srv._this
  end
end # of servant MyHello

class MyHello2 < POA::Test::Hello
  def initialize(orb)
    @orb = orb
  end

  def get_string()
    'Hello2 there!'
  end

  def shutdown()
    @orb.shutdown
  end

  ## overrides for standard CORBA::Object methods
  def _repository_id
    'IDL:org.omg/custom.Test/Hello2:1.0'
  end

  def _is_a?(id)
    Intf::Ids.include?(id) or id == 'IDL:org.omg/custom.Test/Hello:1.0'
  end
end # of servant MyHello
orb = CORBA.ORB_init(['-ORBDebugLevel', OPTIONS[:orb_debuglevel]], 'myORB')

obj = orb.resolve_initial_references('RootPOA')

root_poa = PortableServer::POA._narrow(obj)

poa_man = root_poa.the_POAManager

poa_man.activate

hello_srv = MyHello.new(orb)

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
