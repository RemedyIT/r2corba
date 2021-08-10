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
  :serverport => 9999
}

ARGV.options do |opts|
    script_name = File.basename($0)
    opts.banner = "Usage: ruby #{script_name} [options]"

    opts.separator ''

    opts.on('--p PORT',
            'Set server endpoint port.',
            'Default: 3456') { |v| OPTIONS[:serverport] = v }
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
  require 'corba/poa' # to be able to test for IORTable
  CORBA.implement('Test.idl', OPTIONS)
else
  require 'TestC.rb'
end

 STDERR.puts 'Not supported on this platform'; exit(0);  unless defined?(IORTable)

orb = CORBA.ORB_init(['-ORBDebugLevel', OPTIONS[:orb_debuglevel]], 'myORB')

obj = orb.string_to_object("corbaloc:iiop:1.2@localhost:#{OPTIONS[:serverport]}/Hello")

hello_obj = Test::Hello._narrow(obj)

the_string = hello_obj.get_string()

puts "servant Hello returned <#{the_string}>"

obj = orb.string_to_object("corbaloc:iiop:1.2@localhost:#{OPTIONS[:serverport]}/Hello2")

hello_obj = Test::Hello._narrow(obj)

the_string = hello_obj.get_string()

puts "servant Hello2 returned <#{the_string}>"

hello_obj.shutdown()

orb.destroy()
