#--------------------------------------------------------------------
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
            "Default: 'file://server.ior'") { |v| OPTIONS[:iorfile] = v }
    opts.on("--d LVL",
            "Set ORBDebugLevel value.",
            "Default: 0", Integer) { |v| OPTIONS[:orb_debuglevel] = v }
    opts.on("--use-implement",
            "Load IDL through CORBA.implement() instead of precompiled code.",
            "Default: off") { |v| OPTIONS[:use_implement] = v }

    opts.separator ""

    opts.on("-h", "--help",
            "Show this help message.") { puts opts; exit }

    opts.parse!
end

if OPTIONS[:use_implement]
  require 'corba/poa.rb'
  CORBA.implement('Test.idl', OPTIONS, CORBA::IDL::SERVANT_INTF)
else
  require 'TestS.rb'
end
require 'corba/policies.rb'

class MyCallback < POA::Callback
  def initialize(orb)
    @orb = orb
  end

  def shutdown()    # oneway
    @orb.shutdown(false)
  end

  def callback_method()
    if OPTIONS[:orb_debuglevel] > 0
      puts 'Callback method called.'
    end
  end

end #of servant Callback

if defined?(JRUBY_VERSION)
  ## JacORB needs explicit activation of this option
  props = {
    "org.omg.PortableInterceptor.ORBInitializerClass.bidir_init" =>
               "org.jacorb.orb.giop.BiDirConnectionInitializer"
  }
else
  props = {}
end

orb = CORBA.ORB_init(["-ORBDebugLevel", OPTIONS[:orb_debuglevel]], 'myORB', props)

begin

  obj = orb.resolve_initial_references('RootPOA')

  root_poa = PortableServer::POA._narrow(obj)

  poa_man = root_poa.the_POAManager

  policies = []
  policies << orb.create_policy(BiDirPolicy::BIDIRECTIONAL_POLICY_TYPE,
                          CORBA::Any.to_any(BiDirPolicy::BOTH, BiDirPolicy::BidirectionalPolicyValue._tc))

  puts 'policies created'

  child_poa = root_poa.create_POA('childPOA', poa_man, policies)

  puts 'child_poa created'

  policies.each { |pol| pol.destroy() }

  puts 'policies destroyed'

  poa_man.activate

  obj = orb.string_to_object(OPTIONS[:iorfile])

  assert_not 'Object reference is nil.', CORBA::is_nil(obj)

  simple_srv = Simple_Server._narrow(obj)

  callback_i = MyCallback.new(orb)

  callback_ref = callback_i._this()

  # Send the calback object to the server
  simple_srv.callback_object(callback_ref)

  # A  method to kickstart callbacks from the server
  r = simple_srv.test_method(true)

  assert "unexpected result = #{r}", r == 0

  orb.run()

  root_poa.destroy(1, 1)

ensure

  orb.destroy()

end
