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
  :iorfile => 'server'
}

ARGV.options do |opts|
    script_name = File.basename($0)
    opts.banner = "Usage: ruby #{script_name} [options]"

    opts.separator ""

    opts.on("--o IORFILE",
            "Set IOR base filename.",
            "Default: 'server'") { |v| OPTIONS[:iorfile] = v }
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
  require 'corba/poa'
  CORBA.implement('Test.idl', OPTIONS, CORBA::IDL::SERVANT_INTF)
else
  require 'TestS.rb'
end

class MyHello < POA::Test::Hello
  def initialize(orb, sid)
    @orb = orb
    @sid = sid
  end

  def get_string()
    "[#{Thread.current}] ##{@sid} Hello there!"
  end

  def shutdown()
    @orb.shutdown()
  end
end #of servant MyHello

orb_trds = []

Signal.trap('INT') do
  puts "SIGINT - shutting down ORB..."
  orb_trds.each { |t| t[:orb].shutdown() }
end

if Signal.list.has_key?('USR2')
  Signal.trap('USR2', 'EXIT')
end

orb_trds.concat((0..1).collect do |i|
  Thread.new(i) do |sid|
    orb = CORBA.ORB_init(["-ORBDebugLevel", OPTIONS[:orb_debuglevel]], "myORB#{sid}")

    Thread.current[:orb] = orb # TSS

    obj = orb.resolve_initial_references('RootPOA')

    root_poa = PortableServer::POA._narrow(obj)

    poa_man = root_poa.the_POAManager

    poa_man.activate

    hello_srv = MyHello.new(orb, sid)

    hello_id = root_poa.activate_object(hello_srv)

    hello_obj = root_poa.id_to_reference(hello_id)

    hello_ior = orb.object_to_string(hello_obj)

    open("#{OPTIONS[:iorfile]}#{sid}.ior", 'w') { |io|
      io.write hello_ior
    }

    orb.run
  end
end)

orb_trds.each {|t| t.join }
