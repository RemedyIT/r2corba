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

class Test_impl < POA::OBV_TruncatableTest::Test
  def initialize(orb)
    @orb_ = orb
  end

  def op1(id, iv, desc)
    tmp = "#{id}: #{desc}"
    desc = tmp

    ov = ::OBV_TruncatableTest::BaseValue.new
    ov.basic_data = iv.basic_data
    [ov, desc]
  end

  def op2(iv, id, desc)
    tmp = "#{id}: #{desc}"
    desc = tmp

    ov = ::OBV_TruncatableTest::TValue1.new
    ov.basic_data = iv.basic_data
    ov.data1 = iv.data1
    [ov, desc]
  end

  def op3(id, iv, desc)
    tmp = "#{id}: #{desc}"
    desc = tmp

    ov = ::OBV_TruncatableTest::TValue4.new
    nv = ::OBV_TruncatableTest::NestedValue.new
    nv.data = iv.nv4.data
    ov.basic_data = iv.basic_data
    ov.nv4 = nv
    ov.data4 = iv.data4
    [ov, desc]
  end

  def op4(id, iv1, x, iv2, iv3, iv4, desc)
    tmp = "#{id}: #{desc}"
    desc = tmp

    ov = ::OBV_TruncatableTest::BaseValue.new

    total = x * (iv1.basic_data + iv2.basic_data +
                 iv3.basic_data + iv4.basic_data)
    ov.basic_data = total

    [ov, desc]
  end

  def op5(val, id,  desc)
    ov = ::OBV_TruncatableTest::TValue1.new
    iv = nil
    target = CORBA::Any.value_for_any(val)
    if target.nil?
      STDERR.puts "server:Test_impl::op5 extract failed\n"
      ov.basic_data = 101
      ov.data1 = 10101
    else
      iv = target
      tmp = "#{id}: #{desc}"
      desc = tmp

      ov.basic_data = iv.basic_data
      ov.data1 = iv.data1
    end
    [ov, desc]
  end

  def shutdown()
    @orb_.shutdown
  end

end
