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
  iorfile: 'file://server'
}

ARGV.options do |opts|
    script_name = File.basename($0)
    opts.banner = "Usage: ruby #{script_name} [options]"

    opts.separator ''

    opts.on('--k IORFILE',
            'Set IOR base.',
            "Default: 'file://server'") { |v| OPTIONS[:iorfile] = v }
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

orb = CORBA.ORB_init(['-ORBDebugLevel', OPTIONS[:orb_debuglevel]], 'myORB')

begin

  clt_trds = (0..1).collect do |i|
    Thread.new(i) do |sid|
      obj = orb.string_to_object("#{OPTIONS[:iorfile]}#{sid}.ior")

      hello_obj = Test::Hello._narrow(obj)

      10.times do
        the_string = hello_obj.get_string

        puts "[thread \##{sid}] string returned <#{the_string}>"

        Thread.pass
      end

      hello_obj.shutdown
   end
  end

  clt_trds.each { |t| t.join }

ensure

  orb.destroy

end
