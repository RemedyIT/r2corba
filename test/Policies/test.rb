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
  :use_implement => false,
  :orb_debuglevel => 0
}

ARGV.options do |opts|
    script_name = File.basename($0)
    opts.banner = "Usage: ruby #{script_name} [options]"

    opts.separator ''

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
require 'corba/policies'

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

if defined?(JRUBY_VERSION)
  ## JacORB needs explicit activation of this option
  props = {
    'org.omg.PortableInterceptor.ORBInitializerClass.bidir_init' =>
               'org.jacorb.orb.giop.BiDirConnectionInitializer'
  }
else
  props = {}
end
orb = CORBA.ORB_init(['-ORBDebugLevel', OPTIONS[:orb_debuglevel]], 'myORB', props)

begin

  o = orb.resolve_initial_references('RootPOA')

  rootpoa = PortableServer::POA._narrow(o)

  assert_not 'Failed to resolve RootPOA', CORBA.is_nil(rootpoa) || !rootpoa.is_a?(PortableServer::POA)

  pol = rootpoa.create_thread_policy(PortableServer::SINGLE_THREAD_MODEL)
  assert 'Failed to create correct policy',
         !pol.nil? and pol.is_a?(PortableServer::ThreadPolicy) and pol.value == PortableServer::SINGLE_THREAD_MODEL

  pol = rootpoa.create_lifespan_policy(PortableServer::PERSISTENT)
  assert 'Failed to create correct policy',
         !pol.nil? and pol.is_a?(PortableServer::LifespanPolicy) and pol.value == PortableServer::PERSISTENT

  pol = rootpoa.create_id_uniqueness_policy(PortableServer::UNIQUE_ID)
  assert 'Failed to create correct policy',
         !pol.nil? and pol.is_a?(PortableServer::IdUniquenessPolicy) and pol.value == PortableServer::UNIQUE_ID

  pol = rootpoa.create_id_assignment_policy(PortableServer::USER_ID)
  assert 'Failed to create correct policy',
         !pol.nil? and pol.is_a?(PortableServer::IdAssignmentPolicy) and pol.value == PortableServer::USER_ID

  pol = rootpoa.create_implicit_activation_policy(PortableServer::NO_IMPLICIT_ACTIVATION)
  assert 'Failed to create correct policy',
         !pol.nil? and pol.is_a?(PortableServer::ImplicitActivationPolicy) and pol.value == PortableServer::NO_IMPLICIT_ACTIVATION

  pol = rootpoa.create_servant_retention_policy(PortableServer::RETAIN)
  assert 'Failed to create correct policy',
         !pol.nil? and pol.is_a?(PortableServer::ServantRetentionPolicy) and pol.value == PortableServer::RETAIN

  pol = rootpoa.create_request_processing_policy(PortableServer::USE_DEFAULT_SERVANT)
  assert 'Failed to create correct policy',
         !pol.nil? and pol.is_a?(PortableServer::RequestProcessingPolicy) and pol.value == PortableServer::USE_DEFAULT_SERVANT

  assert_except('orb.create_policy should have thrown a PolicyError',
                CORBA::PolicyError) { orb.create_policy(9999, CORBA::Any.to_any(0)) }

  pol = orb.create_policy(BiDirPolicy::BIDIRECTIONAL_POLICY_TYPE,
                          CORBA::Any.to_any(BiDirPolicy::BOTH, BiDirPolicy::BidirectionalPolicyValue._tc))
  assert 'Failed to create correct policy',
         !pol.nil? and pol.is_a?(BiDirPolicy) and pol.value == BiDirPolicy::BOTH

  poa_man = rootpoa.the_POAManager

  poa_man.activate

  hello_srv = MyHello.new(orb)

  id = rootpoa.activate_object(hello_srv)

  obj = rootpoa.id_to_reference(id)

  assert_except('obj._get_policy(BiDirPolicy::BIDIRECTIONAL_POLICY_TYPE) should have thrown INV_POLICY',
                CORBA::INV_POLICY) { obj._get_policy(BiDirPolicy::BIDIRECTIONAL_POLICY_TYPE) }

  assert 'obj._get_policy_overrides should have returned an empty sequence',
         obj._get_policy_overrides([BiDirPolicy::BIDIRECTIONAL_POLICY_TYPE, Messaging::RELATIVE_RT_TIMEOUT_POLICY_TYPE]).empty?

  obj = obj._set_policy_overrides([pol], CORBA::SET_OVERRIDE)

  assert 'obj._get_policy_overrides should have returned 1 policy',
         obj._get_policy_overrides([BiDirPolicy::BIDIRECTIONAL_POLICY_TYPE, Messaging::RELATIVE_RT_TIMEOUT_POLICY_TYPE]).size == 1

ensure
  orb.destroy()
end
