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

OPTIONS = {
  :use_implement => false,
  :orb_debuglevel => 0,
  :iorfile => 'server.ior'
}

ARGV.options do |opts|
    script_name = File.basename($0)
    opts.banner = "Usage: ruby #{script_name} [options]"

    opts.separator ""

    opts.on("--o IORFILE",
            "Set IOR filename.",
            "Default: 'server.ior'") { |v| OPTIONS[:iorfile]=v }
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

require 'corba'
require 'corba/poa'

class MyHello < PortableServer::DynamicImplementation
  def initialize(orb)
    @orb = orb
  end

  OPTABLE = {
    'echo' => {
        :result_type => CORBA._tc_string,
        :arg_list => [
        ['message', CORBA::ARG_IN, CORBA._tc_string],
        ['msglen', CORBA::ARG_OUT, CORBA._tc_long] ] }
  }

  Id = 'IDL:Test/Hello:1.0'

  def _primary_interface(oid, poa)
    puts "Server: repo_id requested for OID: #{oid.inspect}"
    Id
  end

  def echo(message)
    [message.to_s, message.to_s.size]
  end

  def shutdown()
    @orb.shutdown()
  end
end #of servant MyHello

orb = CORBA.ORB_init(["-ORBDebugLevel", OPTIONS[:orb_debuglevel]], 'myORB')

obj = orb.resolve_initial_references('RootPOA')

root_poa = PortableServer::POA._narrow(obj)

poa_man = root_poa.the_POAManager

poa_man.activate

hello_srv = MyHello.new(orb)

hello_obj = hello_srv._this()

hello_ior = orb.object_to_string(hello_obj)

open(OPTIONS[:iorfile], 'w') { |io|
  io.write hello_ior
}

Signal.trap('INT') do
  puts "SIGINT - shutting down ORB..."
  orb.shutdown()
end

if Signal.list.has_key?('USR2')
  Signal.trap('USR2', 'EXIT')
end

orb.run
