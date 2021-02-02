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
  :iorfile => 'file://server.ior'
}

ARGV.options do |opts|
    script_name = File.basename($0)
    opts.banner = "Usage: ruby #{script_name} [options]"

    opts.separator ""

    opts.on("--k IORFILE",
            "Set IOR.",
            "Default: 'file://server.ior'") { |v| OPTIONS[:iorfile] = v }
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
  require 'corba'
  CORBA.implement('Extra.idl', OPTIONS)
else
  require 'ExtraC'
end

orb = CORBA.ORB_init(["-ORBDebugLevel", OPTIONS[:orb_debuglevel]], 'myORB')

begin
  # make sure valuetype factories are registered
  OBV_TruncatableTest::BaseValueFactory.get_factory(orb)
  OBV_TruncatableTest::TValue1Factory.get_factory(orb)
  OBV_TruncatableTest::TValue2Factory.get_factory(orb)
  OBV_TruncatableTest::TValue3Factory.get_factory(orb)
  OBV_TruncatableTest::TValue4Factory.get_factory(orb)
  OBV_TruncatableTest::TValue5Factory.get_factory(orb)
  OBV_TruncatableTest::NestedValueFactory.get_factory(orb)

  obj = orb.string_to_object(OPTIONS[:iorfile])

  tester = OBV_TruncatableTest::Test._narrow(obj)

  assert_not 'Object reference is nil.', CORBA::is_nil(tester)

  if defined?(JRUBY_VERSION)
    STDERR.puts "Skipping. Value type truncation currently not properly supported by JacORB!"
    tester.shutdown
    exit 0
  end

  # 1.
  v1 = OBV_TruncatableTest::TValue1.new
  v1.basic_data = 9
  v1.data1 = 99

  desc = "A<-tB, truncate B to A"
  STDERR.print "Case 1: #{desc}: "

  ov1, odesc = tester.op1("case1", v1, desc)

  assert '\nERROR: tester.op1 desc FAILED', odesc == "case1: #{desc}"
  assert '\nERROR: tester.op1 ov FAILED' , v1.basic_data == ov1.basic_data

  STDERR.puts 'passed'

  # 2.
  v2 = OBV_TruncatableTest::TValue2.new
  v2.basic_data = 9
  v2.data1 = 99
  v2.data2 = 99 * 2

  desc = "A<-tB<-tC, truncate C to A"
  STDERR.print "Case 2: #{desc}: "

  ov2, odesc = tester.op1("case2", v2, desc)

  assert '\nERROR: tester.op1 - 2 desc FAILED', odesc == "case2: #{desc}"
  assert '\nERROR: tester.op1 - 2 ov FAILED' , v2.basic_data == ov2.basic_data
  STDERR.puts 'passed'

  desc = "A<-tB<-tC, truncate C to B"
  STDERR.print "Case 2b: #{desc}: "

  otv1, odesc = tester.op2(v2, "case2b", desc)

  assert '\nERROR: tester.op2 - 2b desc FAILED', odesc == "case2b: #{desc}"
  assert '\nERROR: tester.op2 - 2b otv1 FAILED' , v2.basic_data == otv1.basic_data
  assert '\nERROR: tester.op2 - 2b otv1 FAILED' , v2.data1 == otv1.data1
  STDERR.puts 'passed'

  # 3.
  itv1b = OBV_TruncatableTest::TValue1.new
  itv1b.basic_data = 7
  itv1b.data1 = 8

  desc = "A<-tB, truncatable but no truncation"
  STDERR.print "Case 3: #{desc}: "

  otv1b, odesc = tester.op2(itv1b, "case3", desc)

  assert '\nERROR: tester.op2 - 3 desc FAILED', odesc == "case3: #{desc}"
  assert '\nERROR: tester.op2 - 3 otv1b FAILED' , itv1b.basic_data == otv1b.basic_data
  assert '\nERROR: tester.op2 - 3 otv1b FAILED' , itv1b.data1 == otv1b.data1
  STDERR.puts 'passed'

  # 4.
  v3 = OBV_TruncatableTest::TValue3.new
  v3.basic_data = 9
  v3.data1 = 99
  v3.data3 = (99 * 3)

  begin
    desc = "A<-tB<-C, try truncate C to A, MARSHAL exception"
    STDERR.print "Case 4: #{desc}: "
    ov3, odesc = tester.op1("case4", v3, desc)
    STDERR.puts 'failed'
  rescue CORBA::MARSHAL
    STDERR.puts 'passed'
  end

  # 5.
  nv = OBV_TruncatableTest::NestedValue.new
  nv.data = 2

  v5 = OBV_TruncatableTest::TValue5.new

  v5.basic_data = 9
  v5.nv4 = nv
  v5.data4 = (99 * 4)
  v5.str1 = "str1"
  v5.data5 = (99 * 5)
  v5.nv5 = nv
  v5.str2 = "str2"

  desc = "A<-tB<-tC, B & C have nested value type, truncate C to A"
  STDERR.print "Case 5: #{desc}: "
  ov5, odesc = tester.op1("case5", v5, desc)

  assert '\nERROR: tester.op1 - 5 desc FAILED', odesc == "case5: #{desc}"
  assert '\nERROR: tester.op1 - 5 ov5 FAILED' , v5.basic_data == ov5.basic_data
  STDERR.puts 'passed'

  desc = "A<-tB<-tC, B & C have nested value type, truncate C to B"
  STDERR.print "Case 5b: #{desc}: "
  otv4, odesc = tester.op3("case5b", v5, desc)

  assert '\nERROR: tester.op3 - 5b desc FAILED', odesc == "case5b: #{desc}"
  assert '\nERROR: tester.op3 - 5b otv4 FAILED' , v5.basic_data == otv4.basic_data
  assert '\nERROR: tester.op3 - 5b otv4.nv4 FAILED' , v5.nv4.data == otv4.nv4.data
  assert '\nERROR: tester.op3 - 5b otv4.data4 FAILED' , v5.data4 == otv4.data4
  STDERR.puts 'passed'

  # 6.
  iv = OBV_TruncatableTest::TValue6.new
  iv.basic_data = 9

  desc = "A<-tB, B has no data, truncate B to A"
  STDERR.print "Case 6: #{desc}: "
  ov, odesc = tester.op1("case6", iv, desc)

  assert '\nERROR: tester.op1 - 6 desc FAILED', odesc == "case6: #{desc}"
  assert '\nERROR: tester.op1 - 6 ov FAILED' , iv.basic_data == ov.basic_data
  STDERR.puts 'passed'

  # 7.
  v1 = OBV_TruncatableTest::TValue1.new
  v1.basic_data = 8
  v1.data1 = 88

  v4 = OBV_TruncatableTest::TValue1.new
  v4.basic_data = 9
  v4.data1 = 99

  nv = OBV_TruncatableTest::NestedValue.new
  nv.data = 2

  v2 = OBV_TruncatableTest::TValue4.new
  v2.basic_data = 7
  v2.nv4 = nv
  v2.data4 = 77

  v3 = OBV_TruncatableTest::TValue4.new
  v3.basic_data = 6
  v3.nv4 = nv
  v3.data4 = 66

  desc = "multiple IN truncatable valuetype parameters" +
         " and return truncatable valuetype"
  STDERR.print "Case 7: #{desc}: "
  ov, odesc = tester.op4("case7", v1, 5, v2, v3, v4, desc)

  assert '\nERROR: tester.op4 - 7 desc FAILED', odesc == "case7: #{desc}"
  total = 5 * (v1.basic_data + v2.basic_data +
               v3.basic_data + v4.basic_data)
  assert '\nERROR: tester.op4 - 7 ov FAILED' ,  total == ov.basic_data
  STDERR.puts 'passed'

  # 8.
  v1 = OBV_TruncatableTest::Extra1.new
  v1.basic_data = 9
  v1.data1 = 99
  v1.edata1 = 1234

  desc = "A<-tB, truncate unknown B to A"
  STDERR.print "Case 8: #{desc}: "
  ov1, odesc = tester.op2(v1, "case8", desc)

  assert '\nERROR: tester.op2 - 8 desc FAILED', odesc == "case8: #{desc}"
  assert '\nERROR: tester.op2 - 8 ov1 FAILED' , v1.basic_data == ov1.basic_data &&
                                                v1.data1 == ov1.data1
  STDERR.puts 'passed'

  # 9.
  v1 = OBV_TruncatableTest::TValue1.new
  v1.basic_data = 9
  v1.data1 = 99

  a = CORBA::Any.to_any(v1)
  desc = "A<-tB, known truncatable via Any"
  STDERR.print "Case 9: #{desc}: "
  ov1, odesc = tester.op5(a, "case9", desc)

  assert '\nERROR: tester.op5 - 9 desc FAILED', odesc == "case9: #{desc}"
  assert '\nERROR: tester.op5 - 9 ov1 FAILED' , v1.basic_data == ov1.basic_data &&
                                                v1.data1 == ov1.data1
  STDERR.puts 'passed'

  # 10.
  v1 = OBV_TruncatableTest::Extra1.new
  v1.basic_data = 9
  v1.data1 = 99
  v1.edata1 = 1234

  a = CORBA::Any.to_any(v1)
  desc = "A<-tB, unknown truncatable via Any"
  STDERR.print "Case 10: #{desc}: "
  ov1, odesc = tester.op5(a, "case10", desc)

  assert '\nERROR: tester.op5 - 10 desc FAILED', odesc == "case10: #{desc}"
  assert '\nERROR: tester.op5 - 10 ov1 FAILED' , v1.basic_data == ov1.basic_data &&
                                                 v1.data1 == ov1.data1
  STDERR.puts 'passed'

  # shutdown tester service

  tester.shutdown()

ensure

  orb.destroy()

end
