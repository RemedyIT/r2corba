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
  :iorfile => 'server.ior',
  :iter_num => 10
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
    opts.on('--i ITERATIONS',
            'Set number of iterations.',
            'Default: 10', Integer) { |v| OPTIONS[:iter_num] = v }

    opts.separator ''

    opts.on('-h', '--help',
            'Show this help message.') { puts opts; exit }

    opts.parse!
end

if OPTIONS[:use_implement]
  require 'corba/poa.rb'
  CORBA.implement('Test.idl', OPTIONS, CORBA::IDL::SERVANT_INTF)
else
  require 'TestS.rb'
end
require 'corba/policies.rb'

class Simple_Server_i < POA::Simple_Server
  def initialize(orb, iter_num)
    @orb = orb
    @iter_num = iter_num
    @flag = false
    @callback = nil
  end

  def test_method(do_callback)
    if do_callback == true
      @flag = true
    end
    0
  end

  def callback_object(cb)
    @callback = cb
  end

  def shutdown()
    @orb.shutdown()
  end

  def call_client()
    if @flag
      @iter_num.times do
        @callback.callback_method()
      end

      @callback.shutdown()
      @flag = false

      return 1
    else
      sleep(0.05) # don't hog the CPU
    end
    return 0
  end

end # of servant Simple_Server_i

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

simple_srv = Simple_Server_i.new(orb, OPTIONS[:iter_num])

id = child_poa.activate_object(simple_srv)

obj = child_poa.id_to_reference(id)

ior = orb.object_to_string(obj)

puts "Activated as <#{ior}>"

open(OPTIONS[:iorfile], 'w') { |io|
  io.write ior
}

Signal.trap('INT') do
  puts 'SIGINT - shutting down ORB...'
  orb.shutdown()
end

if Signal.list.has_key?('USR2')
  Signal.trap('USR2', 'EXIT')
end

retval = 0
while retval == 0
  pending = orb.work_pending()

  if pending
    orb.perform_work()
  end

  retval = simple_srv.call_client()
end

puts 'event loop finished'

root_poa.destroy(true, true)
