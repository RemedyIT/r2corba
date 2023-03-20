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
  use_implement: false,
  orb_debuglevel: 0,
  ior: 'foo'
}

ARGV.options do |opts|
    script_name = File.basename($0)
    opts.banner = "Usage: ruby #{script_name} [options]"

    opts.separator ''

    opts.on('--k IOR',
            'Set IOR.',
            "Default: 'corbaname::foo'") { |v| OPTIONS[:ior] = v }
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

orb = CORBA.ORB_init(['-ORBDebugLevel', OPTIONS[:orb_debuglevel]], 'myORB')

begin
  begin
    tmp = orb.string_to_object(OPTIONS[:ior])

    assert 'No Nil object reference returned on invalid IOR', CORBA.is_nil(tmp)

    assert 'No Nil object returned on invalid IOR', tmp.nil?
  rescue CORBA::INV_OBJREF
    tmp = nil
  end

  assert 'No Nil object reference returned on #_narrow of nil', CORBA.is_nil(Test::Hello._narrow(tmp))

  assert 'No Nil object returned on #_narrow of nil', Test::Hello._narrow(tmp).nil?

  o = orb.resolve_initial_references('RootPOA')

  rootpoa = PortableServer::POA._narrow(o)

  assert_not 'Failed to resolve RootPOA', CORBA.is_nil(rootpoa) || !rootpoa.is_a?(PortableServer::POA)

  assert 'Not nil returned for RootPOA.the_parent', CORBA.is_nil(rootpoa.the_parent) && rootpoa.the_parent.nil?

ensure
  orb.destroy
end
