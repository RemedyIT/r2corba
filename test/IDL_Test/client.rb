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
  :orb_debuglevel => 0,
  :iorfile => 'file://server.ior'
}

ARGV.options do |opts|
    script_name = File.basename($0)
    opts.banner = "Usage: ruby #{script_name} [options]"

    opts.separator ''

    opts.on('--k IORFILE',
            'Set IOR.',
            "Default: 'file://server.ior'") { |v| OPTIONS[:iorfile] = v }
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
  require 'corba'
  CORBA.implement('Test.idl', OPTIONS)
else
  require 'TestC.rb'
end

# tests to test preprocessor processing

assert 'ERROR: struct Test::S1 not defined (correctly)!' do
  Test.const_defined?('S1') and Test::S1.ancestors.include?(CORBA::Portable::Struct)
end

assert 'ERROR: Test::MyNum constant not defined (correctly)!' do
  Test.const_defined?('MyNum') and Test::MyNum == 12345
end

assert 'ERROR: Test::MyString constant not defined (correctly)!' do
  Test.const_defined?('MyString') and Test::MyString == 'hello'
end

# test results of 'typeprefix' and 'typeid'

assert 'ERROR: typeprefix not correctly handled', I2::If3._tc.id == 'IDL:MyPrefix/i2/if3:1.0'

assert 'ERROR: typeid not correctly handled', I2::If2._tc.id == 'IDL:MyIF2:0.1'

# CORBA IDL tests

orb = CORBA.ORB_init(['-ORBDebugLevel', OPTIONS[:orb_debuglevel]], 'myORB')

begin

  obj = orb.string_to_object(OPTIONS[:iorfile])

  hello_obj = Test::Hello._narrow(obj)

  hello_obj.r_super

  hello_obj2 = Test::Hello._narrow(hello_obj.r_self)

  the_string = hello_obj2.get_string

  puts "string returned <#{the_string}>"

  hello_obj.shutdown

  assert_not 'ERROR: Object is reported nil!', CORBA::is_nil(hello_obj)

  hello_obj._free_ref

  assert 'ERROR: Object is reported non-nil!', CORBA::is_nil(hello_obj)

ensure

  orb.destroy

end
