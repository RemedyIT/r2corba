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

    opts.separator ''

    opts.on('--k IORFILE',
            'Set IOR.',
            "Default: 'file://server.ior'") { |v| OPTIONS[:iorfile] = v }
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

  obj = orb.string_to_object(OPTIONS[:iorfile])

  hello_obj = Test::Hello._narrow(obj)

  ## integer max/min values test

  [:max_LongLong,
   :min_LongLong,
   :max_ULongLong,
   :min_ULongLong,
   :max_Long,
   :min_Long,
   :max_ULong,
   :min_ULong,
   :max_Short,
   :min_Short,
   :max_UShort,
   :min_UShort,
   :max_Octet,
   :min_Octet].each do |att|
    att_val = hello_obj.send(att)
    assert "ERROR: value of attribute #{att} (#{att_val}) does not match expected value #{Test.const_get(att.to_s.capitalize)}", Test.const_get(att.to_s.capitalize) == att_val
  end

  ## string test

  str = hello_obj.get_string()

  msg = hello_obj.message

  hello_obj.message = str

  assert 'ERROR setting message attribute', str == hello_obj.message

  ## sequence test

  nums = hello_obj.numbers

  begin
    hello_obj.numbers = (0...11).to_a.collect { |i| i * 3 }
  rescue CORBA::MARSHAL => ex
    ## expected exception since sequence can hold max. 10 elements
  end

  assert "ERROR numbers attribute changed while it shouldn't", nums == hello_obj.numbers

  hello_obj.numbers = nums.collect { |i| i * 3 }

  assert_not 'ERROR numbers attribute did not change while it should have', nums == hello_obj.numbers

  doubles_list = hello_obj.list_of_doubles

  puts doubles_list.inspect

  ## (sequence of) struct test

  svseq = hello_obj.structSeq

  svseq.each { |sv|
    sv.m_one += 1
    sv.m_two += 1.03
    sv.m_three.upcase!
    sv.m_four.m_b = true
    sv.m_five = Test::TE_FIRST
  }

  hello_obj.structSeq = svseq

  ix = 0
  assert_not 'ERROR setting attribute structSeq' do
    hello_obj.structSeq.any? { |sv|
      sv2 = svseq[ix]
      ix += 1
      sv.m_one != sv2.m_one ||
      sv.m_two != sv2.m_two ||
      sv.m_three != sv2.m_three ||
      sv.m_four.m_b != sv2.m_four.m_b ||
      sv.m_five != sv2.m_five
    }
  end

  ## array test

  cube = hello_obj.theCube

  cube2 = cube.collect { |plane|
    plane.collect { |row|
      row.collect { |elem|
        (elem / 3) + (elem % 3)
      }
    }
  }

  hello_obj.theCube = cube2

  assert_not 'ERROR setting attribute theCube' do
    cube2 != hello_obj.theCube || cube == hello_obj.theCube
  end

  ## objref test

  self_obj = hello_obj.selfref

  assert 'ERROR with attribute selfref', self_obj.message == hello_obj.message

  ## Any test

  any = hello_obj.anyValue

  hello_obj.anyValue = 1

  assert_not 'ERROR with attribute anyValue' do
    any == hello_obj.anyValue || 1 == hello_obj.anyValue
  end

  hello_obj.anyValue = 2

  assert_not 'ERROR with attribute anyValue' do
    any == hello_obj.anyValue || 2 == hello_obj.anyValue
  end

  hello_obj.anyValue = 3

  assert_not 'ERROR with attribute anyValue' do
    any == hello_obj.anyValue || 3 == hello_obj.anyValue
  end

  ## union test

  uv1 = hello_obj.unionValue

  uv2 = uv1.class.new
  uv2.m_l = 1234

  hello_obj.unionValue = uv2

  assert_not 'ERROR with attribute unionValue' do
    uv1._disc == hello_obj.unionValue._disc || uv1._value == hello_obj.unionValue._value
  end

  uv21 = hello_obj.unionValue2

  uv22 = uv21.class.new
  uv22.s_ = 'bye bye'

  hello_obj.unionValue2 = uv22

  assert_not 'ERROR with attribute unionValue2' do
    uv21._disc == hello_obj.unionValue2._disc || uv21._value == hello_obj.unionValue2._value
  end

  assert_not 'ERROR with attribute unionValue2' do
    uv21._disc == hello_obj.unionValue2._disc || uv21._value == hello_obj.unionValue2._value
  end

  uv3 = hello_obj.unionValue3

  assert_except 'ERROR with attribute unionValue3', CORBA::BAD_PARAM do
    uv3._disc = false
  end

  uv3._default  # set implicit default

  assert 'ERROR with implicit default union U3' do
    uv3._disc == false
  end

  hello_obj.unionValue3 = uv3

  assert 'ERROR with implicit default attribute unionValue3' do
    hello_obj.unionValue3._disc == false
  end

  uv4 = hello_obj.unionValue4

  assert_except 'ERROR with attribute unionValue4', CORBA::BAD_PARAM do
    uv4._disc = Test::TE_THIRD
  end

  uv4._default  # set implicit default

  assert 'ERROR with implicit default union U4' do
    uv4._disc == Test::TE_THIRD
  end

  hello_obj.unionValue4 = uv4

  assert 'ERROR with implicit default attribute unionValue4' do
    hello_obj.unionValue4._disc == Test::TE_THIRD
  end

  ## recursive struct test

  s3val = hello_obj.s3Value

  s3 = s3val.m_seq.shift
  s3val.m_seq.first.m_seq << s3
  s3val.m_seq.first.m_has_more = true

  hello_obj.s3Value = s3val

  assert_not 'ERROR with attribute s3Value' do
    s3val.m_seq.size != hello_obj.s3Value.m_seq.size || s3val.m_seq.first.m_has_more != hello_obj.s3Value.m_seq.first.m_has_more
  end

  ## in, inout, out test

  reslen, resinoutstr, resoutstr = hello_obj.run_test(instr = Test::TString.new('This is instr'), inoutstr = 'This is inoutstr')

  assert_not 'ERROR with run_test' do
    reslen != resoutstr.size || resinoutstr != instr || resoutstr != (instr + inoutstr)
  end

  hello_obj.shutdown()

ensure

  orb.destroy()

end
