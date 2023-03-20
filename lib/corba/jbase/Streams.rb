#--------------------------------------------------------------------
# Streams.rb - Java/JacORB Definition of CORBA CDR Streams
#
# Author: Martin Corino
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the R2CORBA LICENSE which is
# included with this program.
#
# Copyright (c) Remedy IT Expertise BV
#--------------------------------------------------------------------

module R2CORBA
  module CORBA
    module Portable
      module InputStream
        @@wrapper_klass = Class.new do
          include CORBA::Portable::InputStream
          def initialize(jobj)
            @stream_ = jobj
          end
          attr_reader :stream_
        end

        def self._wrap_native(jobj)
          if jobj.nil? || !jobj.is_a?(Native::V2_3::Portable::InputStream)
            raise ArgumentError, 'Expected org.omg.CORBA.portable.InputStream'
          end
          @@wrapper_klass.new(jobj)
        end

        def read_member(tc)
          tc = tc.resolved_tc # takes care of recursive typecodes
          v = case tc.kind
          when TK_ANY
            read_any()
          when TK_BOOLEAN
            read_boolean()
          when TK_SHORT
            read_short()
          when TK_LONG
            read_long()
          when TK_USHORT
            read_ushort()
          when TK_WCHAR
            read_wchar()
          when TK_ULONG
            read_ulong()
          when TK_LONGLONG
            read_longlong()
          when TK_ULONGLONG
            read_ulonglong()
          when TK_OCTET
            read_octet()
          when TK_FLOAT
            read_float()
          when TK_DOUBLE
            read_double()
          when TK_LONGDOUBLE
            raise CORBA::NO_IMPLEMENT.new('LongDouble not supported', 0, CORBA::COMPLETED_NO)
          when TK_FIXED
            read_fixed()
          when TK_CHAR
            read_char()
          when TK_STRING
            read_string()
          when TK_WSTRING
            read_wstring()
          when TK_OBJREF
            read_Object()
          when TK_TYPECODE
            read_TypeCode()
          when TK_ARRAY, TK_SEQUENCE,
               TK_ENUM, TK_STRUCT, TK_EXCEPT, TK_UNION,
               TK_PRINCIPAL
            read_construct(tc)
          when TK_ABSTRACT_INTERFACE
            read_Abstract()
          when TK_VALUE
            read_value()
          when TK_VALUE_BOX
            read_valuebox(tc.get_type.boxedvalue_helper)
            ## TODO: TK_NATIVE
          end
          v
        end

        def read_any()
          begin
            self.stream_.read_any()
          rescue ::NativeException
            CORBA::Exception.native2r($!)
          end
        end

        def read_boolean()
          begin
            self.stream_.read_boolean()
          rescue ::NativeException
            CORBA::Exception.native2r($!)
          end
        end

        def read_boolean_array(arr, offset, length)
          jarr = Array.new(arr.size).to_java(:boolean)
          begin
            self.stream_.read_boolean_array(jarr, offset, length)
          rescue ::NativeException
            CORBA::Exception.native2r($!)
          end
          arr.fill(offset, length) {|i| jarr[i]}
        end

        def read_char()
          begin
            self.stream_.read_char().chr
          rescue ::NativeException
            CORBA::Exception.native2r($!)
          end
        end

        def read_char_array(arr, offset, length)
          jarr = Array.new(arr.size).to_java(:char)
          begin
            self.stream_.read_char_array(jarr, offset, length)
          rescue ::NativeException
            CORBA::Exception.native2r($!)
          end
          arr.fill(offset, length) {|i| jarr[i].chr }
        end

        def read_wchar()
          begin
            self.stream_.read_wchar()
          rescue ::NativeException
            CORBA::Exception.native2r($!)
          end
        end

        def read_wchar_array(arr, offset, length)
          jarr = Array.new(arr.size).to_java(:char)
          begin
            self.stream_.read_char_array(jarr, offset, length)
          rescue ::NativeException
            CORBA::Exception.native2r($!)
          end
          arr.fill(offset, length) {|i| jarr[i] }
        end

        def read_octet(value)
          begin
            [self.stream_.read_octet()].pack('c').unpack('C').first
          rescue ::NativeException
            CORBA::Exception.native2r($!)
          end
        end

        def read_octet_array(arr, offset, length)
          jarr = Array.new(arr.size).to_java(:byte)
          begin
            self.stream_.read_octet_array(jarr, offset, length)
          rescue ::NativeException
            CORBA::Exception.native2r($!)
          end
          jarr = jarr.pack('c*').unpack('C*')
          arr.fill(offset, length) {|i| jarr[i] }
        end

        def read_short()
          begin
            self.stream_.read_short()
          rescue ::NativeException
            CORBA::Exception.native2r($!)
          end
        end

        def read_short_array(arr, offset, length)
          jarr = Array.new(arr.size).to_java(:short)
          begin
            self.stream_.read_short_array(jarr, offset, length)
          rescue ::NativeException
            CORBA::Exception.native2r($!)
          end
          arr.fill(offset, length) {|i| jarr[i] }
        end

        def read_ushort()
          begin
            [self.stream_.read_ushort()].pack('s').unpack('S').first
          rescue ::NativeException
            CORBA::Exception.native2r($!)
          end
        end

        def read_ushort_array(arr, offset, length)
          jarr = Array.new(arr.size).to_java(:short)
          begin
            self.stream_.read_octet_array(jarr, offset, length)
          rescue ::NativeException
            CORBA::Exception.native2r($!)
          end
          jarr = jarr.pack('s*').unpack('S*')
          arr.fill(offset, length) {|i| jarr[i] }
        end

        def read_long()
          begin
            self.stream_.read_long()
          rescue ::NativeException
            CORBA::Exception.native2r($!)
          end
        end

        def read_long_array(arr, offset, length)
          jarr = Array.new(arr.size).to_java(:int)
          begin
            self.stream_.read_long_array(jarr, offset, length)
          rescue ::NativeException
            CORBA::Exception.native2r($!)
          end
          arr.fill(offset, length) {|i| jarr[i] }
        end

        def read_ulong()
          begin
            [self.stream_.read_ulong()].pack('l').unpack('L').first
          rescue ::NativeException
            CORBA::Exception.native2r($!)
          end
        end

        def read_ulong_array(arr, offset, length)
          jarr = Array.new(arr.size).to_java(:int)
          begin
            self.stream_.read_ulong_array(jarr, offset, length)
          rescue ::NativeException
            CORBA::Exception.native2r($!)
          end
          jarr = jarr.pack('l*').unpack('L*')
          arr.fill(offset, length) {|i| jarr[i] }
        end

        def read_longlong()
          begin
            self.stream_.read_longlong()
          rescue ::NativeException
            CORBA::Exception.native2r($!)
          end
        end

        def read_longlong_array(arr, offset, length)
          jarr = Array.new(arr.size).to_java(:long)
          begin
            self.stream_.read_longlong_array(jarr, offset, length)
          rescue ::NativeException
            CORBA::Exception.native2r($!)
          end
          arr.fill(offset, length) {|i| jarr[i] }
        end

        def read_ulonglong()
          begin
            [self.stream_.read_ulonglong()].pack('q').unpack('Q').first
          rescue ::NativeException
            CORBA::Exception.native2r($!)
          end
        end

        def read_ulonglong_array(arr, offset, length)
          jarr = Array.new(arr.size).to_java(:long)
          begin
            self.stream_.read_ulonglong_array(jarr, offset, length)
          rescue ::NativeException
            CORBA::Exception.native2r($!)
          end
          jarr = jarr.pack('q*').unpack('Q*')
          arr.fill(offset, length) {|i| jarr[i] }
        end

        def read_float()
          begin
            self.stream_.read_float()
          rescue ::NativeException
            CORBA::Exception.native2r($!)
          end
        end

        def read_float_array(arr, offset, length)
          jarr = Array.new(arr.size).to_java(:float)
          begin
            self.stream_.read_float_array(jarr, offset, length)
          rescue ::NativeException
            CORBA::Exception.native2r($!)
          end
          arr.fill(offset, length) {|i| jarr[i] }
        end

        def read_double()
          begin
            self.stream_.read_double()
          rescue ::NativeException
            CORBA::Exception.native2r($!)
          end
        end

        def read_double_array(arr, offset, length)
          jarr = Array.new(arr.size).to_java(:double)
          begin
            self.stream_.read_double_array(jarr, offset, length)
          rescue ::NativeException
            CORBA::Exception.native2r($!)
          end
          arr.fill(offset, length) {|i| jarr[i] }
        end

        def read_string()
          begin
            self.stream_.read_string()
          rescue ::NativeException
            CORBA::Exception.native2r($!)
          end
        end

        def read_wstring()
          begin
            self.stream_.read_wstring()
          rescue ::NativeException
            CORBA::Exception.native2r($!)
          end
        end

        def read_Object()
          begin
            CORBA::Object._wrap_native(self.stream_().read_Object())
          rescue ::NativeException
            CORBA::Exception.native2r($!)
          end
        end

        def read_TypeCode()
          begin
            CORBA::TypeCode._wrap_native(self.stream_().read_TypeCode())
          rescue ::NativeException
            CORBA::Exception.native2r($!)
          end
        end

        def read_fixed()
          begin
            java.math.BigDecimal.new(self.stream_.read_fixed().toString())
          rescue ::NativeException
            CORBA::Exception.native2r($!)
          end
        end

        def read_construct(tc)
          begin
            jany = self.stream_.orb().create_any()
            jany.read_value(self.stream_, tc.tc_)
            CORBA::Any.from_java(jany, self.stream_.orb(), tc)
          rescue ::NativeException
            CORBA::Exception.native2r($!)
          end
        end

        def read_Abstract()
          begin
            obj = self.stream_.read_abstract_interface()
          rescue ::NativeException
            CORBA::Exception.native2r($!)
          end
          obj = CORBA::Object._wrap_native(obj) if obj.is_a?(CORBA::Native::Object)
          obj
        end

        def read_value()
          begin
            self.stream_.read_value()
          rescue ::NativeException
            CORBA::Exception.native2r($!)
          end
        end
        alias :read_Value :read_value
        def read_valuebox(boxedvalue_helper)
          begin
            self.stream_.read_value(boxedvalue_helper)
          rescue ::NativeException
            CORBA::Exception.native2r($!)
          end
        end
      end

      module OutputStream
        @@wrapper_klass = Class.new do
          include CORBA::Portable::OutputStream
          def initialize(jobj)
            @stream_ = jobj
          end
          attr_reader :stream_
        end

        def self._wrap_native(jobj)
          if jobj.nil? || !jobj.is_a?(Native::V2_3::Portable::OutputStream)
            raise ArgumentError, 'Expected org.omg.CORBA.portable.OutputStream'
          end
          @@wrapper_klass.new(jobj)
        end

        def write_member(tc, value)
          tc = tc.resolved_tc # takes care of recursive typecodes
          case tc.kind
          when TK_ANY
            write_any(value)
          when TK_BOOLEAN
            write_boolean(value)
          when TK_SHORT
            write_short(value)
          when TK_LONG
            write_long(value)
          when TK_USHORT
            write_ushort(value)
          when TK_WCHAR
            write_wchar(value)
          when TK_ULONG
            write_ulong(value)
          when TK_LONGLONG
            write_longlong(value)
          when TK_ULONGLONG
            write_ulonglong(value)
          when TK_OCTET
            write_octet(value)
          when TK_FLOAT
            write_float(value)
          when TK_DOUBLE
            write_double(value)
          when TK_LONGDOUBLE
            raise CORBA::NO_IMPLEMENT.new('LongDouble not supported', 0, CORBA::COMPLETED_NO)
          when TK_FIXED
            write_fixed(value)
          when TK_CHAR
            write_char(value)
          when TK_STRING
            write_string(value)
          when TK_WSTRING
            write_wstring(value)
          when TK_OBJREF
            write_Object(value)
          when TK_TYPECODE
            write_TypeCode(value)
          when TK_ARRAY, TK_SEQUENCE,
               TK_ENUM, TK_STRUCT, TK_EXCEPT, TK_UNION,
               TK_PRINCIPAL
            write_construct(value, tc)
          when TK_ABSTRACT_INTERFACE
            write_Abstract(value)
          when TK_VALUE
            write_value(value)
          when TK_VALUE_BOX
            write_valuebox(value, tc.get_type().boxedvalue_helper())
            ## TODO: TK_NATIVE
          end
        end

        def write_any(value)
          begin
            self.stream_.write_any(value)
          rescue ::NativeException
            CORBA::Exception.native2r($!)
          end
        end

        def write_boolean(value)
          begin
            self.stream_.write_boolean(value)
          rescue ::NativeException
            CORBA::Exception.native2r($!)
          end
        end

        def write_boolean_array(value, offset, length)
          begin
            self.stream_.write_boolean_array(value.to_java(:boolean), offset, length)
          rescue ::NativeException
            CORBA::Exception.native2r($!)
          end
        end

        def write_char(value)
          begin
            self.stream_.write_char(value[0])
          rescue ::NativeException
            CORBA::Exception.native2r($!)
          end
        end

        def write_char_array(value, offset, length)
          begin
            self.stream_.write_char_array(value.collect{|c| c[0]}.to_java(:char), offset, length)
          rescue ::NativeException
            CORBA::Exception.native2r($!)
          end
        end

        def write_wchar(value)
          self.stream_.write_wchar(value)
        end

        def write_wchar_array(value, offset, length)
          begin
            self.stream_.write_wchar_array(value.to_java(:char), offset, length)
          rescue ::NativeException
            CORBA::Exception.native2r($!)
          end
        end

        def write_octet(value)
          begin
            self.stream_.write_octet([value].pack('C').unpack('c').first)
          rescue ::NativeException
            CORBA::Exception.native2r($!)
          end
        end

        def write_octet_array(value, offset, length)
          begin
            self.stream_.write_octet_array(value.pack('C*').unpack('c*').to_java(:byte), offset, length)
          rescue ::NativeException
            CORBA::Exception.native2r($!)
          end
        end

        def write_short(value)
          begin
            self.stream_.write_short(value)
          rescue ::NativeException
            CORBA::Exception.native2r($!)
          end
        end

        def write_short_array(value, offset, length)
          begin
            self.stream_.write_short_array(value.to_java(:short), offset, length)
          rescue ::NativeException
            CORBA::Exception.native2r($!)
          end
        end

        def write_ushort(value)
          begin
            self.stream_.write_ushort([value].pack('S').unpack('s').first)
          rescue ::NativeException
            CORBA::Exception.native2r($!)
          end
        end

        def write_ushort_array(value, offset, length)
          begin
            self.stream_.write_ushort_array(value.pack('S*').unpack('s*').to_java(:short), offset, length)
          rescue ::NativeException
            CORBA::Exception.native2r($!)
          end
        end

        def write_long(value)
          begin
            self.stream_.write_long(value)
          rescue ::NativeException
            CORBA::Exception.native2r($!)
          end
        end

        def write_long_array(value, offset, length)
          begin
            self.stream_.write_long_array(value.to_java(:int), offset, length)
          rescue ::NativeException
            CORBA::Exception.native2r($!)
          end
        end

        def write_ulong(value)
          begin
            self.stream_.write_ulong([value].pack('L').unpack('l').first)
          rescue ::NativeException
            CORBA::Exception.native2r($!)
          end
        end

        def write_ulong_array(value, offset, length)
          begin
            self.stream_.write_ulong_array(value.pack('L*').unpack('l*').to_java(:int), offset, length)
          rescue ::NativeException
            CORBA::Exception.native2r($!)
          end
        end

        def write_longlong(value)
          begin
            self.stream_.write_longlong(value)
          rescue ::NativeException
            CORBA::Exception.native2r($!)
          end
        end

        def write_longlong_array(value, offset, length)
          begin
            self.stream_.write_longlong_array(value.to_java(:long), offset, length)
          rescue ::NativeException
            CORBA::Exception.native2r($!)
          end
        end

        def write_ulonglong(value)
          begin
            self.stream_.write_ulonglong([value].pack('Q').unpack('q').first)
          rescue ::NativeException
            CORBA::Exception.native2r($!)
          end
        end

        def write_ulonglong_array(value, offset, length)
          begin
            self.stream_.write_ulonglong_array(value.pack('Q*').unpack('q*').to_java(:long), offset, length)
          rescue ::NativeException
            CORBA::Exception.native2r($!)
          end
        end

        def write_float(value)
          begin
            self.stream_.write_float(value)
          rescue ::NativeException
            CORBA::Exception.native2r($!)
          end
        end

        def write_float_array(value, offset, length)
          begin
            self.stream_.write_float_array(value.to_java(:float), offset, length)
          rescue ::NativeException
            CORBA::Exception.native2r($!)
          end
        end

        def write_double(value)
          begin
            self.stream_.write_double(value)
          rescue ::NativeException
            CORBA::Exception.native2r($!)
          end
        end

        def write_double_array(value, offset, length)
          begin
            self.stream_.write_double_array(value.to_java(:double), offset, length)
          rescue ::NativeException
            CORBA::Exception.native2r($!)
          end
        end

        def write_string(value)
          begin
            self.stream_.write_string(value)
          rescue ::NativeException
            CORBA::Exception.native2r($!)
          end
        end

        def write_wstring(value)
          begin
            self.stream_.write_wstring(value.inject('') {|s, b| s << b.chr})
          rescue ::NativeException
            CORBA::Exception.native2r($!)
          end
        end

        def write_fixed(value)
          begin
            self.stream_.write_fixed(java.math.BigDecimal.new(value.to_s))
          rescue ::NativeException
            CORBA::Exception.native2r($!)
          end
        end

        def write_Object(value)
          begin
            self.stream_.write_Object(value.objref_)
          rescue ::NativeException
            CORBA::Exception.native2r($!)
          end
        end

        def write_TypeCode(value)
          begin
            self.stream_.write_TypeCode(value.tc_)
          rescue ::NativeException
            CORBA::Exception.native2r($!)
          end
        end

        def write_construct(value, tc)
          begin
            CORBA::Any.to_any(value, tc).to_java(self.stream_().orb()).write_value(self.stream_)
          rescue ::NativeException
            CORBA::Exception.native2r($!)
          end
        end

        def write_Abstract(value)
          begin
            self.stream_().write_abstract_interface(value.is_a?(CORBA::Object) ? value.objref_ : value)
          rescue ::NativeException
            CORBA::Exception.native2r($!)
          end
        end

        def write_value(value)
          begin
            self.stream_.write_value(value)
          rescue ::NativeException
            CORBA::Exception.native2r($!)
          end
        end
        alias :write_Value :write_value
        def write_valuebox(value, boxedvalue_helper)
          begin
            self.stream_.write_value(value, boxedvalue_helper)
          rescue ::NativeException
            CORBA::Exception.native2r($!)
          end
        end
      end
    end
  end
end
