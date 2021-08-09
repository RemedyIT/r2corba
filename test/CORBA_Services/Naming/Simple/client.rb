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
  :iorfile => 'file://ins.ior'
}

ARGV.options do |opts|
    script_name = File.basename($0)
    opts.banner = "Usage: ruby #{script_name} [options]"

    opts.separator ''

    opts.on('--k IORFILE',
            'Set IOR.',
            "Default: 'file://ins.ior'") { |v| OPTIONS[:iorfile] = v }
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
require 'corba/naming'

orb = CORBA.ORB_init(['-ORBDebugLevel', OPTIONS[:orb_debuglevel]], 'myORB')

begin

  # resolve NamingContext
  obj = orb.string_to_object(OPTIONS[:iorfile])

  nc = CosNaming::NamingContextExt._narrow(obj)

  assert_not 'ERROR: INS IOR resolved to nil object!', CORBA::is_nil(nc)

  # retrieve object reference for servant from Naming service
  name = [CosNaming::NameComponent.new('Hello', 'ior')]

  obj = nc.resolve(name)

  # narrow object ref and call
  hello_obj = Test::Hello._narrow(obj)

  the_string = hello_obj.get_string()

  puts "string returned <#{the_string}>"

  hello_obj.shutdown()

ensure

  orb.destroy()

end
