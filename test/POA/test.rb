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
require 'lib/assert'
include TestUtil::Assertions

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
            "Default: 'server.ior'") { |v| OPTIONS[:iorfile] = v }
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
  def initialize(orb)
    @orb = orb
  end

  def get_string()
    "Hello there!"
  end

  def shutdown()
    @orb.shutdown()
  end
end #of servant MyHello

orb = CORBA.ORB_init(["-ORBDebugLevel", OPTIONS[:orb_debuglevel]], 'myORB')

begin
  obj = orb.resolve_initial_references('RootPOA')

  rootpoa = PortableServer::POA._narrow(obj)

  assert_not 'Failed to resolve RootPOA', CORBA.is_nil(rootpoa) || !rootpoa.is_a?(PortableServer::POA)

  poaman = rootpoa.the_POAManager

  assert_not 'Failed to resolve the_POAManager', CORBA.is_nil(poaman) || !poaman.is_a?(PortableServer::POAManager)

  childpoa = rootpoa.create_POA('childPOA', poaman, [])

  assert_not 'Failed to create child POA', CORBA.is_nil(childpoa) || !childpoa.is_a?(PortableServer::POA)

  assert 'POAManager state should have been HOLDING', poaman.get_state == PortableServer::POAManager::HOLDING

  poaman.activate

  assert_except('No PortableServer::POA::AdapterNonExistent exception thrown on rootpoa.find_POA(\'non-existent-poa\')',
                PortableServer::POA::AdapterNonExistent) { rootpoa.find_POA('non-existent-poa', true) }

  childpoa = rootpoa.find_POA('childPOA', true)

  hello_srv = MyHello.new(orb)

  assert_except('childpoa.servant_to_id should have thrown ServantNotActive',
                PortableServer::POA::ServantNotActive) { childpoa.servant_to_id(hello_srv) }

  id = childpoa.activate_object(hello_srv)

  assert 'object ids returned from #activate_object and #servant_to_id not equal', id == childpoa.servant_to_id(hello_srv)

  poaman.deactivate(true, true)

  assert 'POAManager state should have been INACTIVE', poaman.get_state == PortableServer::POAManager::INACTIVE

  assert_except('poaman.activate should have thrown AdapterInactive',
                PortableServer::POAManager::AdapterInactive) { poaman.activate }

ensure
  orb.destroy
end
