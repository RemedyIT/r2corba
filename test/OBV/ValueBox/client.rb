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
            "Default: 'file://server.ior'") { |v| OPTIONS[:iorfile]=v }
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
  require 'corba'
  CORBA.implement('valuebox.idl', OPTIONS)
else
  require 'valueboxC'
end

##

module Test
  def Test.basic_invocations(test)
    # test boxed value
    p1 = VBlong.new(25)
    p2 = VBlong.new(53)
    p2_out = nil
    p3_out = nil
    retval = nil

    STDERR.puts '*** basic_op1 (1)'
    retval, p2_out, p3_out = test.basic_op1(p1, p2)

    assert "basic_invocations:1 failed", (p2_out == (53*3))
    assert "basic_invocations:1 failed", (p3_out == (53*5))
    assert "basic_invocations:1 failed", (retval == (p1.value*3))

    # test boxed value using implicit conversion of Ruby types
    p1 = 25
    p2 = 53
    p2_out = nil
    p3_out = nil
    retval = nil

    STDERR.puts '*** basic_op1 (2)'
    retval, p2_out, p3_out = test.basic_op1(p1, p2)

    assert "basic_invocations:2 failed", (p2_out == (53*3))
    assert "basic_invocations:2 failed", (p3_out == (53*5))
    assert "basic_invocations:2 failed", (retval == (p1*3))

    # test boxed value using nil
    p1 = nil
    p2 = VBlong.new(53)
    p2_out = nil
    p3_out = nil
    retval = nil

    STDERR.puts '*** basic_op1 (3)'
    retval, p2_out, p3_out = test.basic_op1(p1, p2)

    assert "basic_invocations:2 failed", (p2_out == (53*3))
    assert "basic_invocations:2 failed", (p3_out == (53*5))
    assert "basic_invocations:2 failed", (retval.nil?)

    # test boxed value from nested module
    p1 = Vb_basic::M_VBlong.new(25) # explicit value box
    p2 = 53                         # implicitly converted value
    p2_out = nil
    p3_out = nil
    retval = nil

    retval, p2_out, p3_out = test.basic_op2(p1, p2)

    assert "basic_invocations:3 failed", (p2_out == (53*3))
    assert "basic_invocations:3 failed", (p3_out == (53*5))
    assert "basic_invocations:3 failed", (retval == (p1.value*3))

    # test regular Ruby types using values from valueboxes
    p1 = VBlong.new(25)
    p2 = VBlong.new(53)
    p2_out = nil
    p3_out = nil
    retval = nil

    retval, p2_out, p3_out = test.basic_op3(p1.value, p2.value)

    assert "basic_invocations:4 failed", (p2_out == (53*3))
    assert "basic_invocations:4 failed", (p3_out == (53*5))
    assert "basic_invocations:4 failed", (retval == (p1.value*3))
  end

  def Test.boxed_string_invocations(test)
    string1 = "First-string"
    string2 = "Second-string"

    # Establish that we have data setup correctly...
    assert "boxed_string_invocations:0 failed", (string1 < string2)
    assert "boxed_string_invocations:0 failed", (string2 > string1)
    assert "boxed_string_invocations:0 failed", (string1 == string1)

    # create valueboxes
    vbstring1 = VBstring.new(string1.dup)
    vbstring2 = VBstring.new(string1.dup)

    # check valuebox correctness
    assert "boxed_string_invocations:1 failed", (vbstring1.value == string1)
    assert "boxed_string_invocations:1 failed", (vbstring2.value == string1)

    # test value modifier
    vbstring2.value = string2.dup
    assert "boxed_string_invocations:2 failed", (vbstring2.value == string2)

    # test invocation with value boxes
    p1 = VBstring.new('string1')
    p2 = VBstring.new('string2')
    assert "boxed_string_invocations:3 failed", (p1.value == 'string1')
    assert "boxed_string_invocations:3 failed", (p2.value == 'string2')

    p2_out = nil
    p3_out = nil
    retval = nil
    retval, p2_out, p3_out = test.string_op1(p1, p2)

    assert "boxed_string_invocations:4 failed", (p2_out == '2string')
    assert "boxed_string_invocations:4 failed", (p3_out == '2string')
    assert "boxed_string_invocations:4 failed", (retval == '1string')

    # test invocation with Ruby types using valuebox values
    assert "boxed_string_invocations:3 failed", (p1.value == 'string1')
    assert "boxed_string_invocations:3 failed", (p2.value == 'string2')

    p2_out = nil
    p3_out = nil
    retval = nil
    retval, p2_out, p3_out = test.string_op2(p1.value, p2.value)

    assert "boxed_string_invocations:4 failed", (p2_out == '2string')
    assert "boxed_string_invocations:4 failed", (p3_out == '2string')
    assert "boxed_string_invocations:4 failed", (retval == '1string')
  end

  def Test.boxed_sequence_invocations(test)
    # basic test
    p1 = VBseqlong.new([101, 202, 303])
    assert "boxed_sequence_invocations:0 failed", (p1.value[0]==101 && p1.value[2]==303)

    # test invocation with value boxes
    p1 = VBseqlong.new([10, 9, 8, 7])
    p2 = VBseqlong.new([100, 99, 98])
    assert "boxed_sequence_invocations:1 failed", (p1.value[0] == 10 && p1.value[3] == 7)
    assert "boxed_sequence_invocations:1 failed", (p2.value[0] == 100 && p2.value[2] == 98)

    p2_out = nil
    p3_out = nil
    retval = nil
    retval, p2_out, p3_out = test.seq_op1(p1, p2)

    p2.value().each_with_index do |e, i|
      assert "boxed_sequence_invocations:2 failed", (p2_out[i] == e*3)
    end
    p2.value().each_with_index do |e, i|
      assert "boxed_sequence_invocations:2 failed", (p3_out[i] == e*5)
    end
    p1.value().each_with_index do |e, i|
      assert "boxed_sequence_invocations:2 failed", (retval[i] == e)
    end

    # test invocation with Ruby types using valuebox values
    p2_out = nil
    p3_out = nil
    p2_out, p3_out = test.seq_op2(p1.value, p2.value)

    p2.value().each_with_index do |e, i|
      assert "boxed_sequence_invocations:3 failed", (p2_out[i] == e*3)
    end
    p2.value().each_with_index do |e, i|
      assert "boxed_sequence_invocations:3 failed", (p3_out[i] == e*5)
    end
  end

  def Test.boxed_struct_invocations(test)
    # basic test
    p1 = VBfixed_struct1.new(
                Fixed_Struct1.new(29,
                        Fixed_Struct1::Bstruct.new(117,21)))

    assert "boxed_struct_invocations:0 failed", (p1.value.is_a?(Fixed_Struct1))
    assert "boxed_struct_invocations:0 failed", (p1.value.l == 29)
    assert "boxed_struct_invocations:0 failed", (p1.value.abstruct.s1 == 117 && p1.value.abstruct.s2 == 21)

    # test invocation with valueboxes
    p2 = VBfixed_struct1.new(
                Fixed_Struct1.new(92,
                        Fixed_Struct1::Bstruct.new(171,12)))
    p2_out = nil
    p3_out = nil
    retval = nil
    retval, p2_out, p3_out = test.struct_op1(p1, p2)

    assert "boxed_struct_invocations:1 failed", (p2_out.is_a?(Fixed_Struct1))
    assert "boxed_struct_invocations:1 failed", (p2_out.l == (92*3))
    assert "boxed_struct_invocations:1 failed", (p2_out.abstruct.s1 == (171*3) &&
                                                 p2_out.abstruct.s2 == (12*3))

    assert "boxed_struct_invocations:1 failed", (p3_out.is_a?(Fixed_Struct1))
    assert "boxed_struct_invocations:1 failed", (p3_out.l == (92*5))
    assert "boxed_struct_invocations:1 failed", (p3_out.abstruct.s1 == (171*5) &&
                                                 p3_out.abstruct.s2 == (12*5))

    assert "boxed_struct_invocations:1 failed", (retval.is_a?(Fixed_Struct1))
    assert "boxed_struct_invocations:1 failed", (retval.l == p1.value.l)
    assert "boxed_struct_invocations:1 failed", (retval.abstruct.s1 == p1.value.abstruct.s1 &&
                                                 retval.abstruct.s2 == p1.value.abstruct.s2)

    # test invocation with Ruby types using valuebox values
    p2_out, p3_out = test.struct_op2(p1.value, p2_out)

    assert "boxed_struct_invocations:2 failed", (p2_out.is_a?(Fixed_Struct1))
    assert "boxed_struct_invocations:2 failed", (p2_out.l == (92*3*3))
    assert "boxed_struct_invocations:2 failed", (p2_out.abstruct.s1 == (171*3*3) &&
                                                 p2_out.abstruct.s2 == (12*3*3))

    assert "boxed_struct_invocations:2 failed", (p3_out.is_a?(Fixed_Struct1))
    assert "boxed_struct_invocations:2 failed", (p3_out.l == p1.value.l)
    assert "boxed_struct_invocations:2 failed", (p3_out.abstruct.s1 == p1.value.abstruct.s1 &&
                                                 p3_out.abstruct.s2 == p1.value.abstruct.s2)

    # test invocation with valueboxes
    p1 = VBvariable_struct1.new(Variable_Struct1.new(29, 'variable1'))
    p2 = VBvariable_struct1.new(Variable_Struct1.new(37, 'variable2'))

    assert "boxed_struct_invocations:3 failed", (p1.value.is_a?(Variable_Struct1))
    assert "boxed_struct_invocations:3 failed", (p1.value.l == 29)
    assert "boxed_struct_invocations:3 failed", (p1.value.str == 'variable1')

    p2_out = nil
    p3_out = nil
    retval = nil
    retval, p2_out, p3_out = test.struct_op3(p1, p2)

    assert "boxed_struct_invocations:4 failed", (p2_out.is_a?(Variable_Struct1))
    assert "boxed_struct_invocations:4 failed", (p2_out.l == (37*3))
    assert "boxed_struct_invocations:4 failed", (p2_out.str == '2variable')

    assert "boxed_struct_invocations:4 failed", (p3_out.is_a?(Variable_Struct1))
    assert "boxed_struct_invocations:4 failed", (p3_out.l == (37*3))
    assert "boxed_struct_invocations:4 failed", (p3_out.str == '2variable')

    assert "boxed_struct_invocations:1 failed", (retval.is_a?(Variable_Struct1))
    assert "boxed_struct_invocations:1 failed", (retval.l == p1.value.l)
    assert "boxed_struct_invocations:1 failed", (retval.str == p1.value.str)

    # test invocation with Ruby types using valuebox values
    p2_out, p3_out = test.struct_op4(p1.value, p2_out)

    assert "boxed_struct_invocations:4 failed", (p2_out.is_a?(Variable_Struct1))
    assert "boxed_struct_invocations:4 failed", (p2_out.l == (37*3*3))
    assert "boxed_struct_invocations:4 failed", (p2_out.str == 'e2variabl')

    assert "boxed_struct_invocations:1 failed", (p3_out.is_a?(Variable_Struct1))
    assert "boxed_struct_invocations:1 failed", (p3_out.l == p1.value.l)
    assert "boxed_struct_invocations:1 failed", (p3_out.str == p1.value.str)
  end

  def Test.boxed_array_invocations(test)
    # basic test
    p1 = VBlongarray.new([101, 202, 303])
    assert "boxed_array_invocations:0 failed", (p1.value[0]==101 && p1.value[2]==303)

    # test invocation with value boxes
    p1 = VBlongarray.new([10, 9, 8])
    p2 = VBlongarray.new([100, 99, 98])
    assert "boxed_array_invocations:1 failed", (p1.value[0] == 10 && p1.value[2] == 8)
    assert "boxed_array_invocations:1 failed", (p2.value[0] == 100 && p2.value[2] == 98)

    p2_out = nil
    p3_out = nil
    retval = nil
    retval, p2_out, p3_out = test.array_op1(p1, p2)

    p2.value().each_with_index do |e, i|
      assert "boxed_array_invocations:2 failed", (p2_out[i] == e*3)
    end
    p2.value().each_with_index do |e, i|
      assert "boxed_array_invocations:2 failed", (p3_out[i] == e*3)
    end
    p1.value().each_with_index do |e, i|
      assert "boxed_array_invocations:2 failed", (retval[i] == e)
    end

    # test invocation with Ruby types using valuebox values
    p2_out = nil
    p3_out = nil
    p2_out, p3_out = test.array_op2(p1.value, p2.value)

    p2.value().each_with_index do |e, i|
      assert "boxed_array_invocations:3 failed", (p2_out[i] == e*3)
    end
    p1.value().each_with_index do |e, i|
      assert "boxed_array_invocations:3 failed", (p3_out[i] == e)
    end

    # test invocation with value boxes
    p1 = VBstringarray.new(['in string1', 'in string1'])
    p2 = VBstringarray.new(['inout string1', 'inout string1'])
    assert "boxed_array_invocations:4 failed", (p1.value[0] == 'in string1' && p1.value[1] == 'in string1')
    assert "boxed_array_invocations:4 failed", (p2.value[0] == 'inout string1' && p2.value[1] == 'inout string1')

    p2_out = nil
    p3_out = nil
    retval = nil
    retval, p2_out, p3_out = test.array_op3(p1, p2)

    p2.value().each_with_index do |e, i|
      assert "boxed_array_invocations:5 failed", (p2_out[i] == '1inout string')
    end
    p2.value().each_with_index do |e, i|
      assert "boxed_array_invocations:5 failed", (p3_out[i] == '1inout string')
    end
    p1.value().each_with_index do |e, i|
      assert "boxed_array_invocations:5 failed", (retval[i] == e)
    end

    # test invocation with Ruby types using valuebox values
    p2_out = nil
    p3_out = nil
    p2_out, p3_out = test.array_op4(p1.value, p2.value)

    p2.value().each_with_index do |e, i|
      assert "boxed_array_invocations:6 failed", (p2_out[i] == '1inout string')
    end
    p1.value().each_with_index do |e, i|
      assert "boxed_array_invocations:6 failed", (p3_out[i] == e)
    end
  end
  def Test.boxed_union_invocations(test)
    # basic test
    p1 = VBfixed_union1.new(Fixed_Union1.new)
    p1.value.m1 = 321
    p2 = VBfixed_union1.new(Fixed_Union1.new)
    p2.value.m2 = 789

    assert "boxed_union_invocations:0 failed", (p1.value.is_a?(Fixed_Union1))
    assert "boxed_union_invocations:0 failed", (p1.value._disc == 1)
    assert "boxed_union_invocations:0 failed", (p1.value.m1 == 321)

    assert "boxed_union_invocations:0 failed", (p2.value.is_a?(Fixed_Union1))
    assert "boxed_union_invocations:0 failed", (p2.value._disc == 2)
    assert "boxed_union_invocations:0 failed", (p2.value.m1 == 789)

    # test invocation with valueboxes
    p2_out = nil
    p3_out = nil
    retval = nil
    retval, p2_out, p3_out = test.union_op1(p1, p2)

    assert "boxed_union_invocations:1 failed", (p2_out.is_a?(Fixed_Union1))
    assert "boxed_union_invocations:1 failed", (p2_out._disc == 2)
    assert "boxed_union_invocations:1 failed", (p2_out.m2 == 789*3)

    assert "boxed_union_invocations:1 failed", (p3_out.is_a?(Fixed_Union1))
    assert "boxed_union_invocations:1 failed", (p3_out._disc == 1)
    assert "boxed_union_invocations:1 failed", (p3_out.m1 == 321*3)

    assert "boxed_union_invocations:1 failed", (retval.is_a?(Fixed_Union1))
    assert "boxed_union_invocations:1 failed", (retval._disc == 1)
    assert "boxed_union_invocations:1 failed", (retval.m1 == 321*3)

    # test invocation with Ruby types using valuebox values
    p2_out = nil
    p3_out = nil
    p2_out, p3_out = test.union_op2(p1.value, p2.value)

    assert "boxed_union_invocations:1 failed", (p2_out.is_a?(Fixed_Union1))
    assert "boxed_union_invocations:1 failed", (p2_out._disc == 2)
    assert "boxed_union_invocations:1 failed", (p2_out.m2 == 789*3)

    assert "boxed_union_invocations:1 failed", (p3_out.is_a?(Fixed_Union1))
    assert "boxed_union_invocations:1 failed", (p3_out._disc == 1)
    assert "boxed_union_invocations:1 failed", (p3_out.m1 == 321)

    # test invocation with valueboxes
    p1 = VBvariable_union1.new(Variable_Union1.new)
    p1.value.m1 = 321
    p2 = VBvariable_union1.new(Variable_Union1.new)
    p2.value.m2 = 'abracadabra'

    assert "boxed_union_invocations:0 failed", (p1.value.is_a?(Variable_Union1))
    assert "boxed_union_invocations:0 failed", (p1.value._disc == 1)
    assert "boxed_union_invocations:0 failed", (p1.value.m1 == 321)

    assert "boxed_union_invocations:0 failed", (p2.value.is_a?(Variable_Union1))
    assert "boxed_union_invocations:0 failed", (p2.value._disc == 2)
    assert "boxed_union_invocations:0 failed", (p2.value.m1 == 'abracadabra')

    p2_out = nil
    p3_out = nil
    retval = nil
    retval, p2_out, p3_out = test.union_op3(p1, p2)

    assert "boxed_union_invocations:1 failed", (p2_out.is_a?(Variable_Union1))
    assert "boxed_union_invocations:1 failed", (p2_out._disc == 2)
    assert "boxed_union_invocations:1 failed", (p2_out.m2 == 'aabracadabr')

    assert "boxed_union_invocations:1 failed", (p3_out.is_a?(Variable_Union1))
    assert "boxed_union_invocations:1 failed", (p3_out._disc == 1)
    assert "boxed_union_invocations:1 failed", (p3_out.m1 == 321)

    assert "boxed_union_invocations:1 failed", (retval.is_a?(Variable_Union1))
    assert "boxed_union_invocations:1 failed", (retval._disc == 1)
    assert "boxed_union_invocations:1 failed", (retval.m1 == 321)

    # test invocation with Ruby types using valuebox values
    p2_out = nil
    p3_out = nil
    p2_out, p3_out = test.union_op4(p1.value, p2.value)

    assert "boxed_union_invocations:1 failed", (p2_out.is_a?(Variable_Union1))
    assert "boxed_union_invocations:1 failed", (p2_out._disc == 2)
    assert "boxed_union_invocations:1 failed", (p2_out.m2 == 'aabracadabr')

    assert "boxed_union_invocations:1 failed", (p3_out.is_a?(Variable_Union1))
    assert "boxed_union_invocations:1 failed", (p3_out._disc == 1)
    assert "boxed_union_invocations:1 failed", (p3_out.m1 == 321)

  end
end

##

orb = CORBA.ORB_init(["-ORBDebugLevel", OPTIONS[:orb_debuglevel]], 'myORB')

begin
  obj = orb.string_to_object(OPTIONS[:iorfile])

  assert_not 'Object reference is nil.', CORBA::is_nil(obj)

  test = Test._narrow(obj)

  # run tests

  Test.basic_invocations(test)

  Test.boxed_string_invocations(test)

  Test.boxed_sequence_invocations(test)

  Test.boxed_struct_invocations(test)

  Test.boxed_array_invocations(test)

  Test.boxed_union_invocations(test)

  # shutdown test service

  test.shutdown()

ensure

  orb.destroy()

end
