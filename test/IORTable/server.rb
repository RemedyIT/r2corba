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
  :listenport => 9999,
  :iorfile => 'server.ior'
}

ARGV.options do |opts|
    script_name = File.basename($0)
    opts.banner = "Usage: ruby #{script_name} [options]"

    opts.separator ''

    opts.on('--o IORFILE',
            'Set IOR filename.',
            "Default: 'server.ior'") { |v| OPTIONS[:iorfile] = v }
    opts.on('--p PORT',
            'Set endpoint port.',
            'Default: 3456') { |v| OPTIONS[:listenport] = v }
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

begin STDERR.puts 'Not supported on this platform'; open(OPTIONS[:iorfile], 'w') {|io|io.write ''}; exit(0); end unless defined?(IORTable)

class MyHello < POA::Test::Hello
  def initialize(orb, id)
    @orb = orb
    @id = id
  end

  def get_string()
    "#{@id}: Hello there!"
  end

  def shutdown()
    @orb.shutdown()
  end
end #of servant MyHello

class MyLocator
  include IORTable::Locator

  def initialize(object_key, ior)
    @map = {object_key => ior}
  end

  def locate(object_key)
    puts "server: MyLocator.locate('#{object_key}') called"
    return @map[object_key] if @map.has_key?(object_key)
    raise IORTable::NotFound
  end
end

orb = CORBA.ORB_init(['-ORBDebugLevel', OPTIONS[:orb_debuglevel], '-ORBListenEndpoints', "iiop://localhost:#{OPTIONS[:listenport]}"], 'myORB')

obj = orb.resolve_initial_references('RootPOA')

root_poa = PortableServer::POA._narrow(obj)

poa_man = root_poa.the_POAManager

poa_man.activate

obj = orb.resolve_initial_references('IORTable')

iortbl = IORTable::Table._narrow(obj)

hello_srv = MyHello.new(orb, 'Hello')

hello_obj = hello_srv._this()

hello_ior = orb.object_to_string(hello_obj)

iortbl.bind('Hello', hello_ior)

hello_srv = MyHello.new(orb, 'Hello2')

hello_obj = hello_srv._this()

hello_ior = orb.object_to_string(hello_obj)

iortbl.set_locator(MyLocator.new('Hello2', hello_ior))

open(OPTIONS[:iorfile], 'w') { |io|
  io.write hello_ior
}

Signal.trap('INT') do
  puts 'SIGINT - shutting down ORB...'
  orb.shutdown()
end

if Signal.list.has_key?('USR2')
  Signal.trap('USR2', 'EXIT')
end

orb.run
