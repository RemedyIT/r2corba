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

TEST_ALL = 0
TEST_STATE = 1
TEST_OPERATION = 2
TEST_EXCEPTION = 3

OPTIONS = {
  :use_implement => false,
  :orb_debuglevel => 0,
  :iorfile => 'file://server.ior',
  :test => TEST_ALL
}

ARGV.options do |opts|
    script_name = File.basename($0)
    opts.banner = "Usage: ruby #{script_name} [options]"

    opts.separator ""

    opts.on("--k IORFILE",
            "Set IOR.",
            "Default: 'file://server.ior'") { |v| OPTIONS[:iorfile]=v }
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

if OPTIONS[:use_implement]
  require 'corba'
  CORBA.implement('test.idl', OPTIONS)
else
  require 'testC'
end

def dump_node(node, indent)
  return if node.nil?

  if $VERBOSE
    STDERR.print ' ' * indent

    if node.is_a?(StringNode)
      STDERR.puts("#{node} <StringNode> #{node.name}")
    else
      STDERR.puts("#{node} <BaseNode> #{node.name}")
    end
  end

  dump_node(node.left, indent + 1)
  dump_node(node.right, indent + 1)
end

def dump_tree(tc)
  if $VERBOSE
    STDERR.puts "start tree dump #{tc}"
  end

  dump_node(tc.root, 1)

  if $VERBOSE
    STDERR.puts "end tree dump #{tc}"
  end
end

def test_state(abs)
  raise CORBA::BAD_PARAM.new unless abs.is_a?(TreeController)
  dump_tree(abs)
end

def test_operation(abs)
  retval = abs.base_op('base_op')
  if $VERBOSE
    STDERR.puts retval
  end

  concrete = Foo::_narrow(abs)

  retval = concrete.foo_op('foo_op')
  if $VERBOSE
    STDERR.puts retval
  end

  retval = concrete.base_op('base_op')
  if $VERBOSE
    STDERR.puts retval
  end
end

def test_exception(abs)
  
    retval = abs.base_op('bad_name')
    if $VERBOSE
      STDERR.puts retval
    end
  rescue BadInput => ex
    if $VERBOSE
      STDERR.puts ex.to_s
    end
  
end

orb = CORBA.ORB_init(["-ORBDebugLevel", OPTIONS[:orb_debuglevel]], 'myORB')

begin
  obj = orb.string_to_object(OPTIONS[:iorfile])

  assert_not 'Object reference is nil.', CORBA::is_nil(obj)

  passer = Passer._narrow(obj)

  if OPTIONS[:test] == TEST_STATE || OPTIONS[:test] == TEST_ALL
    # make sure valuetype factories are registered
    BaseNodeFactory.get_factory(orb)
    StringNodeFactory.get_factory(orb)
    TreeControllerFactory.get_factory(orb)

    package = passer.pass_state()
    if CORBA::is_nil(package)
      STDERR.puts "ERROR: passer.pass_state returned nil 'out' arg (#{package})"
    end

    test_state(package)
  end

  if OPTIONS[:test] != TEST_STATE
    package = passer.pass_ops()
    if CORBA::is_nil(package)
      STDERR.puts "ERROR: passer.pass_ops returned nil 'out' arg (#{package})"
    end
  end

  if OPTIONS[:test] == TEST_OPERATION || OPTIONS[:test] == TEST_ALL
    test_operation(package)
  end

  if OPTIONS[:test] == TEST_EXCEPTION || OPTIONS[:test] == TEST_ALL
    test_exception(package)
  end

  if OPTIONS[:test] == TEST_ALL
    package = passer.pass_nil()
    unless CORBA::is_nil(package)
      STDERR.puts "ERROR: passer.pass_state did NOT return nil 'out' arg (#{package})"
    end
  end

  # shutdown passer service

  passer.shutdown()

ensure

  orb.destroy()

end
