#--------------------------------------------------------------------
# naming_server.rb - Implementation of simple interoperable
#                    naming service
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
  :iorfile => 'ins.ior'
}

ORB_ARG = []

# extract -ORBxxx aguments
f_ = false
ARGV.collect! { |a|
  if f_
    f_ = false
    ORB_ARG << a
    nil
  else
    f_ = /^-ORB/ =~ a
    ORB_ARG << a if f_
    f_ ? nil : a
  end
}.compact!

ARGV.options do |opts|
    script_name = File.basename($0)
    opts.banner = "Usage: ruby #{script_name} [options]"

    opts.separator ""

    opts.on("-o IORFILE",
            "Set IOR filename.",
            "Default: 'ins.ior'") { |v| OPTIONS[:iorfile]=v }

    opts.separator ""

    opts.on("-h", "--help",
            "Show this help message.") { puts opts; exit }

    opts.parse!
end

require 'corba/naming_service'

def p_n(n)
  n.collect {|nm| nm.r_id}.join('.')
end

##
# Binding iterator servant class
#
class RBBindingIterator < POA::CosNaming::BindingIterator
  def initialize(reglist)
    @rl = reglist
  end

  attr_accessor :oid

  def next_one
    reg = @rl.shift
    [!reg.nil?, reg ? CosNaming::Binding.new(reg[:name], reg[:type]) : nil]
  end

  def next_n(how_many)
    bindings = []
    while how_many>0 and !@rl.empty?
      reg = @rl.shift
      bindings << CosNaming::Binding.new(reg[:name], reg[:type])
      how_many -= 1
    end
    [!bindings.empty?, bindings]
  end

  def destroy
    @rl.clear
    poa = self._default_POA
    poa.deactivate_object(self.oid)
  end
end

##
# Naming context servant class
#
class RBNamingContext < POA::CosNaming::NamingContextExt
  def initialize(orb)
    @orb = orb
    @map = {}
  end

  attr_accessor :oid

  # CosNaming::NamingContext methods
  #
  def bind(n, obj)
    raise CosNaming::NamingContext::InvalidName.new if n.size<1
    if n.size>1
      nc = find_context(n)
      nc.bind(n, obj)
    else
      register_object(n.first, n, CosNaming::Nobject, obj)
    end
  end

  def rebind(n, obj)
    raise CosNaming::NamingContext::InvalidName.new if n.size<1
    if n.size>1
      nc = find_context(n)
      nc.rebind(n, obj)
    else
      reregister_object(n.first, n, CosNaming::Nobject, obj)
    end
  end

  def bind_context(n, nc_new)
    raise CosNaming::NamingContext::InvalidName.new if n.size<1
    if n.size>1
      nc = find_context(n)
      nc.bind_context(n, nc_new)
    else
      register_object(n.first, n, CosNaming::Ncontext, nc_new)
    end
  end

  def rebind_context(n, nc_new)
    raise CosNaming::NamingContext::InvalidName.new if n.size<1
    if n.size>1
      nc = find_context(n)
      nc.rebind_context(n, nc_new)
    else
      reregister_object(n.first, n, CosNaming::Ncontext, nc_new)
    end
  end

  def resolve(n)
    raise CosNaming::NamingContext::InvalidName.new if n.size<1
    find_object(n)
  end

  def unbind(n)
    raise CosNaming::NamingContext::InvalidName.new if n.size<1
    if n.size>1
      nc = find_context(n)
      nc.unbind(n)
    else
      raise CosNaming::NamingContext::NotFound.new(CosNaming::NamingContext::Missing_node,
                                                   n) if !@map.has_key?(n.first.r_id)
      @map.delete(n.last.r_id)
    end
  end

  def new_context()
    poa = self._default_POA
    naming_srv = RBNamingContext.new(@orb)
    naming_srv.oid = poa.activate_object(naming_srv)
    ::CosNaming::NamingContextExt::_narrow(poa.id_to_reference(naming_srv.oid))
  end

  def bind_new_context(n)
    raise CosNaming::NamingContext::InvalidName.new if n.size<1
    nc = self.new_context()
    self.bind_context(n, nc)
    nc
  end

  def destroy()
    raise CosNaming::NamingContext::NotEmpty.new if @map.size>0
    return if self.oid.nil? ## no oid for root context
    poa = self._default_POA
    poa.deactivate_object(self.oid)
    @orb = nil
  end

  def list(how_many)
    reglist = @map.values
    bindings = []
    while how_many>0 and !reglist.empty?
      reg = reglist.shift
      bindings << CosNaming::Binding.new(reg[:name], reg[:type])
      how_many -= 1
    end
    bi_obj = nil
    if !reglist.empty?
      bi = RBBindingIterator.new(reglist)
      poa = self._default_POA
      bi.oid = poa.activate_object(bi)
      bi_obj = poa.id_to_reference(bi.oid)
    end
    [bindings, bi_obj]
  end

  # CosNaming::NamingContextExt methods
  #
  def to_string(n)
  end

  def to_name(sn)
  end

  def to_url(addr, sn)
  end

  def resolve_str(n)
  end

  def shutdown()
    @orb.shutdown
  end

  #
  #

  def register_object(name, full_name, type, obj)
    raise CosNaming::NamingContext::AlreadyBound.new if @map.has_key?(name.r_id)
    @map[name.r_id] = {
      :name => full_name,
      :type => type,
      :object => obj
    }
  end

  def reregister_object(name, full_name, type, obj)
    if @map.has_key?(name.r_id) and @map[name.r_id][:type] != type
      why = (type == CosNaming::Nobject ? CosNaming::NamingContext::Not_object : CosNaming::NamingContext::Not_context)
      raise CosNaming::NamingContext::NotFound.new(why, [])
    end
    @map[name.r_id] = {
      :name => full_name,
      :type => type,
      :object => obj
    }
  end

  def find_object(n)
    if n.size>1
      nc = find_context(n)
      nc.resolve(n)
    else
      raise CosNaming::NamingContext::NotFound.new(CosNaming::NamingContext::Missing_node,
                                                   n) if !@map.has_key?(n.first.r_id)
      @map[n.last.r_id][:object]
    end
  end

  def find_context(n)
    raise CosNaming::NamingContext::NotFound.new(CosNaming::NamingContext::Missing_node,
                                                 n) if !@map.has_key?(n.first.r_id)
    raise CosNaming::NamingContext::NotFound.new(CosNaming::NamingContext::Not_context,
                                                 n) if @map[n.first.r_id][:type] != CosNaming::Ncontext
    @map[n.shift.r_id][:object]
  end

end #of NamingContext servant

##########
# Main

orb = CORBA.ORB_init(ORB_ARG, 'myORB')

obj = orb.resolve_initial_references('RootPOA')

root_poa = PortableServer::POA._narrow(obj)

poa_man = root_poa.the_POAManager

poa_man.activate

naming_srv = RBNamingContext.new(orb)

naming_obj = naming_srv._this()

naming_ior = orb.object_to_string(naming_obj)

obj = orb.resolve_initial_references('IORTable')

iortbl = IORTable::Table._narrow(obj)

iortbl.bind("NamingServer", naming_ior)

open(OPTIONS[:iorfile], 'w') { |io|
  io.write naming_ior
}

Signal.trap('INT') do
  puts "SIGINT - shutting down ORB..."
  orb.shutdown()
end

Signal.trap('USR2', 'EXIT')

orb.run

