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
  :iorfile => 'server.ior'
}

ARGV.options do |opts|
    script_name = File.basename($0)
    opts.banner = "Usage: ruby #{script_name} [options]"

    opts.separator ''

    opts.on('--o IORFILE',
            'Set IOR filename.',
            "Default: 'server.ior'") { |v| OPTIONS[:iorfile] = v }
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

class MyHello < POA::Test::Hello
  def initialize(orb)
    @orb = orb
    @nex = 0
  end

  def test_exception()
    @nex += 1
    case (@nex % 3)
    when 1
      x = Test::ExOne.new
      x.why = 'Because I want it'
      x.code = @nex
      raise x
    when 2
      raise Test::ExBoo.new(Test::ExBoo::LOUD)
    else
    end
  end

  def myString
    raise Test::ExOne.new('Need to set string first.', 1) unless @mystr
    @mystr
  end

  def myString=(s)
    @mystr = s.to_s
  end

  def myCount
    @mycnt || 0
  end

  def myCount=(c)
    raise Test::ExOne.new('Value out of bounds', 2) unless c.to_i < 100
    @mycnt = c.to_i
  end

  def myResult
    raise Test::ExOne.new('Need to set myCount first.', 1) unless @mycnt
    @mycnt * 3
  end

  def shutdown()
    @orb.shutdown
  end
end # of servant MyHello

orb = CORBA.ORB_init(['-ORBDebugLevel', OPTIONS[:orb_debuglevel]], 'myORB')

obj = orb.resolve_initial_references('RootPOA')

root_poa = PortableServer::POA._narrow(obj)

poa_man = root_poa.the_POAManager

poa_man.activate

hello_srv = MyHello.new(orb)

hello_obj = hello_srv._this

hello_ior = orb.object_to_string(hello_obj)

open(OPTIONS[:iorfile], 'w') { |io|
  io.write hello_ior
}

Signal.trap('INT') do
  puts 'SIGINT - shutting down ORB...'
  orb.shutdown
end

if Signal.list.has_key?('USR2')
  Signal.trap('USR2', 'EXIT')
end

orb.run

exit 0
