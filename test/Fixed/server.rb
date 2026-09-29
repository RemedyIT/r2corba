require 'optparse'

OPTIONS = {
  use_implement: false,
  orb_debuglevel: 0,
  iorfile: 'server.ior'
}

ARGV.options do |opts|
  opts.on('--o IORFILE', 'Set IOR filename.') { |v| OPTIONS[:iorfile] = v }
  opts.on('--d LVL', 'Set ORBDebugLevel value.') { |v| OPTIONS[:orb_debuglevel] = v }
  opts.on('--use-implement', 'Load IDL through CORBA.implement().') { OPTIONS[:use_implement] = true }
  opts.on('-h', '--help', 'Show this help message.') { puts opts; exit }
  opts.parse!
end

if OPTIONS[:use_implement]
  require 'corba/poa'
  CORBA.implement('Test.idl', OPTIONS, CORBA::IDL::SERVANT_INTF)
else
  require 'TestS.rb'
end

class FixedValues_i < POA::Test::FixedValues
  def initialize(orb)
    @orb = orb
  end

  def echo_fixed(value)
    value
  end

  def echo_sequence(value)
    value
  end

  def echo_array(value)
    value
  end

  def echo_any(value)
    value
  end

  def shutdown
    @orb.shutdown
  end
end

orb = CORBA.ORB_init(['-ORBDebugLevel', OPTIONS[:orb_debuglevel]], 'myORB')
root_poa = PortableServer::POA._narrow(orb.resolve_initial_references('RootPOA'))
root_poa.the_POAManager.activate

servant = FixedValues_i.new(orb)
ior = orb.object_to_string(servant._this)
File.open(OPTIONS[:iorfile], 'w') { |io| io.write(ior) }

Signal.trap('INT') { orb.shutdown }
Signal.trap('USR2', 'EXIT') if Signal.list.has_key?('USR2')
orb.run
