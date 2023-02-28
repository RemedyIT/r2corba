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
  use_implement: false,
  orb_debuglevel: 0,
  iorfile: 'server.ior'
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
  end

  def get_string(tid)
    "[server #{Thread.current}] Hello there thread \##{tid}!"
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

File.open(OPTIONS[:iorfile], 'w') { |io|
  io.write hello_ior
}

Signal.trap('INT') do
  puts 'SIGINT - shutting down ORB...'
  orb.shutdown
end

if Signal.list.has_key?('USR2')
  Signal.trap('USR2', 'EXIT')
end

if defined?(JRUBY_VERSION)
  # JRuby based jR2CORBA behaves slightly different from MRI based R2CORBA
  # because the underlying ORB (JacORB) uses an implicit threadpool based
  # thread-per-request model; so running multiple threads with ORB#run
  # does not bring anything here
  orb.run
else
  # TAO, the underlying ORB implementation for MRI base R2CORBA has support
  # for several multithreading options; the simplest way to set up multithreaded
  # request processing is starting ORB#run in multiple threads which results
  # in each of those threads being 're-used' as request processing threads.
  # NOTE: as MRI Ruby 1.8 threads are 'green' threads there is only 1 native
  #       thread from which the TAO ORB is run however many Ruby threads are
  #       started; the ORB#run method for this platform implements a special
  #       cooperative ORB event loop allowing multiple Ruby threads executing
  #       ORB#run to operate in parallel.
  orb_trds = (0..1).collect do
    Thread.new do
      orb.run
    end
  end

  orb_trds.each {|t| t.join }
end
