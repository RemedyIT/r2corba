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

    opts.separator ""

    opts.on("--o IORFILE",
            "Set IOR filename.",
            "Default: 'server.ior'") { |v| OPTIONS[:iorfile] = v }
    opts.on("--d LVL",
            "Set ORBDebugLevel value.",
            "Default: 0") { |v| OPTIONS[:orb_debuglevel] = v }
    opts.on("--use-implement",
            "Load IDL through CORBA.implement() instead of precompiled code.",
            "Default: off") { |v| OPTIONS[:use_implement] = v }

    opts.separator ""

    opts.on("-h", "--help",
            "Show this help message.") { puts opts; exit }

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
    @msg = 'message'
    @nums = Test::TShortSeq.new((0...10).collect { |i| i * 2 })
    s1 = Test::S1.new
    s1.m_one = 123
    s1.m_two = 2.54
    s1.m_three = "field three"
    s1.m_four = Test::S1::S2.new
    s1.m_four.m_b = false
    s1.m_five = ::Test::TE_ZEROTH
    @s1seq = Test::S1Seq.new << s1
    @cube = Test::TLongCube.new((0...3).collect {|x|
      (0...3).collect {|y|
        (0...4).collect {|z| x + (y * 10) + (z * 100) }
      }
    })
    @anysel = 0
    @s3 = Test::S3.new
    @s3.m_has_more = true
    @s3.m_seq = []
    s3_ = Test::S3.new
    s3_.m_has_more = false
    @s3.m_seq << s3_
    s3_ = Test::S3.new
    s3_.m_has_more = false
    @s3.m_seq << s3_
    @u1 = Test::U1.new
    @u1._disc = Test::TE_FIRST
    @u1.m_str = "Hello world!"
    @u2 = Test::U2.new
    @u2._disc = Test::U2::ONE
    @u2.l_ = 12345
    @u3 = Test::U3.new
    @u3._disc = true
    @u3.lval = 123456
    @u4 = Test::U4.new
    @u4._disc = Test::TE_FIRST
    @u4.m_str = "Hello world!"
    @nex = 0
  end

  def max_LongLong()
    Test::Max_longlong
  end #of attribute get_Max_LongLong

  def min_LongLong()
    Test::Min_longlong
  end #of attribute get_Min_LongLong

  def max_ULongLong()
    Test::Max_ulonglong
  end #of attribute get_Max_ULongLong

  def min_ULongLong()
    Test::Min_ulonglong
  end #of attribute get_Min_ULongLong

  def max_Long()
    Test::Max_long
  end #of attribute get_Max_Long

  def min_Long()
    Test::Min_long
  end #of attribute get_Min_Long

  def max_ULong()
    Test::Max_ulong
  end #of attribute get_Max_ULong

  def min_ULong()
    Test::Min_ulong
  end #of attribute get_Min_ULong

  def max_Short()
    Test::Max_short
  end #of attribute get_Max_Short

  def min_Short()
    Test::Min_short
  end #of attribute get_Min_Short

  def max_UShort()
    Test::Max_ushort
  end #of attribute get_Max_UShort

  def min_UShort()
    Test::Min_ushort
  end #of attribute get_Min_UShort

  def max_Octet()
    Test::Max_octet
  end #of attribute get_Max_Octet

  def min_Octet()
    Test::Min_octet
  end #of attribute get_Min_Octet

  def get_string()
    "Hello there!"
  end

  def message()
    @msg
  end #of attribute get_message

  def message=(val)
    @msg = val.to_s
  end #of attribute set_message

  def numbers()
    @nums
  end #of attribute get_numbers

  def numbers=(val)
    @nums = val
  end #of attribute set_numbers

  def list_of_doubles()
    [1.0, 1.1, 1.2, 1.3]
  end #of attribute get_numbers

  def structSeq()
    @s1seq
  end #of attribute get_structSeq

  def structSeq=(val)
    @s1seq = val
  end #of attribute set_structSeq

  def theCube()
    @cube
  end #of attribute get_theCube

  def theCube=(val)
    @cube = val
  end #of attribute set_theCube

  def anyValue()
    case @anysel
    when 1
      @cube
    when 2
      @s1seq
    when 3
      CORBA::Any.to_any([1,2,3,4,5], CORBA::TypeCode::Sequence.new(CORBA._tc_long))
    else
      @anysel
    end
  end #of attribute get_anyValue

  def anyValue=(val)
    @anysel = val.to_i
  end #of attribute set_anyValue

  def selfref()
    self._this
  end #of attribute get_selfref

  def s3Value()
    @s3
  end #of attribute get_s3Value

  def s3Value=(val)
    @s3 = val
  end #of attribute set_s3Value

  def unionValue()
    @u1
  end #of attribute get_unionValue

  def unionValue=(val)
    @u1 = val
  end #of attribute set_unionValue

  def unionValue2()
    @u2
  end #of attribute get_unionValue2

  def unionValue2=(val)
    @u2 = val
  end #of attribute set_unionValue2

  def unionValue3()
    @u3
  end #of attribute get_unionValue3

  def unionValue3=(val)
    @u3 = val
  end #of attribute set_unionValue3

  def unionValue4()
    @u4
  end #of attribute get_unionValue4

  def unionValue4=(val)
    @u4 = val
  end #of attribute set_unionValue4

  def run_test(instr, inoutstr)
    outstr = instr + inoutstr
    inoutstr = instr
    [outstr.size, inoutstr, outstr]
  end

  def shutdown()
    @orb.shutdown()
  end
end #of servant Hello


orb = CORBA.ORB_init(["-ORBDebugLevel", OPTIONS[:orb_debuglevel]], 'myORB')

obj = orb.resolve_initial_references('RootPOA')

root_poa = PortableServer::POA._narrow(obj)

poa_man = root_poa.the_POAManager

poa_man.activate

hello_srv = MyHello.new(orb)

hello_oid = root_poa.activate_object(hello_srv)

hello_obj = root_poa.id_to_reference(hello_oid)

hello_ior = orb.object_to_string(hello_obj)

open(OPTIONS[:iorfile], 'w') { |io|
  io.write hello_ior
}

Signal.trap('INT') do
  puts "SIGINT - shutting down ORB..."
  orb.shutdown()
end

if Signal.list.has_key?('USR2')
  Signal.trap('USR2', 'EXIT')
end

orb.run
