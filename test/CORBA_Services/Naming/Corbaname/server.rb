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
  :iorfile => 'corbaname.ior',
  :use_implement => false,
  :orb_debuglevel => 0,
  :ins_port => 2345
}

ARGV.options do |opts|
    script_name = File.basename($0)
    opts.banner = "Usage: ruby #{script_name} [options]"

    opts.separator ''

    opts.on('--o FILENAME',
            'Set corbaname IOR filename.',
            "Default: 'corbaname.ior'") { |v| OPTIONS[:iorfile] = v }
    opts.on('--d LVL',
            'Set ORBDebugLevel value.',
            'Default: 0') { |v| OPTIONS[:orb_debuglevel] = v }
    opts.on('--p PORT', Integer,
            'INS port number.',
            'Default: 2345') { |v| OPTIONS[:ins_port] = v }
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
require 'corba/naming'

class MyHello < POA::Test::Hello
  def initialize(orb)
    @orb = orb
  end

  def get_string()
    'Hello there!'
  end

  def shutdown()
    @orb.shutdown()
  end
end #of servant MyHello

# initialize ORB
orb = CORBA.ORB_init(['-ORBDebugLevel', OPTIONS[:orb_debuglevel]], 'myORB')

# create NameService corbaloc
ins_url = "iiop:localhost:#{OPTIONS[:ins_port]}/NamingService"

puts "server: resolving [corbaloc:#{ins_url}]"

# resolve NamingContext
obj = orb.string_to_object('corbaloc:' + ins_url)

nc = CosNaming::NamingContextExt._narrow(obj)

# create context tree for registration
full_name = [CosNaming::NameComponent.new('', 'root'),
             CosNaming::NameComponent.new('base', 'dir'),
             CosNaming::NameComponent.new('Hello', 'ior')]

nc_new = nc.bind_new_context(full_name[0, 1])
nc_new = nc_new.bind_new_context(full_name[1, 1])

assert_not 'ERROR: INS IOR resolved to nil object!', CORBA::is_nil(nc)

# initialize POA
obj = orb.resolve_initial_references('RootPOA')

root_poa = PortableServer::POA._narrow(obj)

poa_man = root_poa.the_POAManager

poa_man.activate

# create and activate servant
hello_srv = MyHello.new(orb)

hello_obj = hello_srv._this()

# register object reference with Naming service
name = full_name

nc.bind(name, hello_obj)

# create corbaname url for registered object
sn = nc.to_string(name)             # stringify name
corbaname = nc.to_url(ins_url, sn)  # corbaname url

# write corbaname to file
open(OPTIONS[:iorfile], 'w') { |io|
  io.write corbaname
}

# initialize signal handling
Signal.trap('INT') do
  puts 'SIGINT - shutting down ORB...'
  orb.shutdown()
end

if Signal.list.has_key?('USR2')
  Signal.trap('USR2', 'EXIT')
end

# run ORB event loop
orb.run
