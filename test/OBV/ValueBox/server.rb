#--------------------------------------------------------------------
#
# Author: Martin Corino
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the R2CORBA LICENSE which is
# included with this program.
#
# Copyright (c) Remedy IT Expertise BV
# Chamber of commerce Rotterdam nr.276339, The Netherlands
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

    opts.separator ""

    opts.on("--o IORFILE",
            "Set IOR filename.",
            "Default: 'server.ior'") { |v| OPTIONS[:iorfile]=v }
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
  require 'corba/poa'
  CORBA.implement('valuebox.idl', OPTIONS, CORBA::IDL::SERVANT_INTF)
else
  require 'valueboxS'
end

class Test_impl < POA::Test
  def initialize(orb)
    @orb = orb
  end

  def ros(s)
    s.slice(s.size-1,1) << s.slice(0,s.size-1)
  end

  def basic_op1(p1, p2)
    p3 = p2 * 5
    p2 = p2 * 3
    retval = p1.nil?() ? nil : p1 * 3
    [retval, p2, p3]
  end

  def basic_op2(p1, p2)
    p3 = p2 * 5
    p2 = p2 * 3
    retval = p1 * 3
    [retval, p2, p3]
  end

  def basic_op3(p1, p2)
    p3 = p2 * 5
    p2 = p2 * 3
    retval = p1 * 3
    [retval, p2, p3]
  end

  def string_op1(p1, p2)
    p2 = ros(p2)
    p3 = p2
    retval = ros(p1)
    [retval, p2, p3]
  end

  def string_op2(p1, p2)
    p2 = ros(p2)
    p3 = p2
    retval = ros(p1)
    [retval, p2, p3]
  end

  def seq_op1(p1, p2)
    p3 = p2.collect {|e| e*5}
    p2.collect! {|e| e*3}
    retval = p1
    [retval, p2, p3]
  end

  def seq_op2(p1, p2)
    p3 = p2.collect {|e| e*5}
    p2.collect! {|e| e*3}
    [p2, p3]
  end

  def struct_op1(p1, p2)
    p3 = Fixed_Struct1.new(p2.l*5,
                           Fixed_Struct1::Bstruct.new(p2.abstruct.s1*5,
                                                      p2.abstruct.s2*5))
    p2.l = p2.l*3
    p2.abstruct.s1 = p2.abstruct.s1*3
    p2.abstruct.s2 = p2.abstruct.s2*3

    retval = p1
    [retval, p2, p3]
  end

  def struct_op2(p1, p2)
    p3 = p1

    p2.l = p2.l*3
    p2.abstruct.s1 = p2.abstruct.s1*3
    p2.abstruct.s2 = p2.abstruct.s2*3

    [p2, p3]
  end

  def struct_op3(p1, p2)
    p2.l = p2.l * 3
    p2.str = ros(p2.str)

    p3 = Variable_Struct1.new(p2.l, p2.str)

    retval = p1
    [retval, p2, p3]
  end

  def struct_op4(p1, p2)
    p3 = p1
    p2.l = p2.l * 3
    p2.str = ros(p2.str)

    [p2, p3]
  end

  def array_op1(p1, p2)
    p2.collect! {|e| e*3}
    p3 = p2
    retval = p1
    [retval, p2, p3]
  end

  def array_op2(p1, p2)
    p2.collect! {|e| e*3}
    p3 = p1
    [p2, p3]
  end

  def array_op3(p1, p2)
    p2.collect! {|e| ros(e)}
    p3 = p2
    retval = p1
    [retval, p2, p3]
  end

  def array_op4(p1, p2)
    p2.collect! {|e| ros(e)}
    p3 = p1
    [p2, p3]
  end

  def union_op1(p1, p2)
    p3 = VBfixed_union1.new(Fixed_Union1.new)
    retval = VBfixed_union1.new(Fixed_Union1.new)
    case p1._disc
    when 1
      p3.value.m1 = p1.m1*3
      retval.value.m1 = p1.m1*3
    when 2
      p3.value.m2 = p1.m2*3
      retval.value.m2 = p1.m2*3
    end
    case p2._disc
    when 1
      p2.m1 = p2.m1*3
    when 2
      p2.m2 = p2.m2*3
    end
    [retval, p2, p3]
  end

  def union_op2(p1, p2)
    p3 = p1
    case p2._disc
    when 1
      p2.m1 = p2.m1*3
    when 2
      p2.m2 = p2.m2*3
    end
    [p2, p3]
  end

  def union_op3(p1, p2)
    p3 = VBvariable_union1.new(Variable_Union1.new)
    retval = VBvariable_union1.new(Variable_Union1.new)
    case p1._disc
    when 1
      p3.value.m1 = p1.m1
      retval.value.m1 = p1.m1
    when 2
      p3.value.m2 = p1.m2
      retval.value.m2 = p1.m2
    end
    case p2._disc
    when 1
      p2.m1 = p2.m1*3
    when 2
      p2.m2 = ros(p2.m2)
    end
    [retval, p2, p3]
  end

  def union_op4(p1, p2)
    p3 = p1
    case p2._disc
    when 1
      p2.m1 = p2.m1*3
    when 2
      p2.m2 = ros(p2.m2)
    end
    [p2, p3]
  end

  def shutdown()
    @orb.shutdown()
  end
end #of servant Test_impl

orb = CORBA.ORB_init(["-ORBDebugLevel", OPTIONS[:orb_debuglevel]], 'myORB')

obj = orb.resolve_initial_references('RootPOA')

root_poa = PortableServer::POA._narrow(obj)

poa_man = root_poa.the_POAManager

poa_man.activate

test_srv = Test_impl.new(orb)

test_obj = test_srv._this()

ior = orb.object_to_string(test_obj)

open(OPTIONS[:iorfile], 'w') { |io|
  io.write ior
}

Signal.trap('INT') do
  puts "SIGINT - shutting down ORB..."
  orb.shutdown()
end

if Signal.list.has_key?('USR2')
  Signal.trap('USR2', 'EXIT')
end

orb.run
