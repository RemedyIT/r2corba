#--------------------------------------------------------------------
# Any.rb - CORBA Any support
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
    module Native
      module Dynamic
        include_package 'org.omg.DynamicAny'
      end

      module Reflect
        java_import java.lang.reflect.Array
      end
    end

    class Any
      def to_java(jorb = nil, jany = nil)
        rtc = self._tc
        rval = self._value.nil? ? self._value : rtc.validate(self._value)
        restc = rtc.resolved_tc
        begin
          if [TK_VALUE, TK_VALUE_BOX, TK_ABSTRACT_INTERFACE].include?(restc.kind) ||
             (!rval.nil? && [TK_NULL, TK_ANY, TK_BOOLEAN, TK_SHORT, TK_LONG, TK_USHORT,
                            TK_WCHAR, TK_ULONG, TK_LONGLONG, TK_ULONGLONG, TK_OCTET,
                            TK_FLOAT, TK_DOUBLE, TK_LONGDOUBLE, TK_CHAR, TK_STRING, TK_WSTRING,
                            TK_VALUE, TK_VALUE_BOX, TK_TYPECODE, TK_OBJREF, TK_PRINCIPAL].include?(restc.kind))
            jorb ||= CORBA::ORB._orb
            jany ||= jorb.create_any
            case restc.kind
            when TK_NULL
              # leave any as is
            when TK_ANY
              jany.insert_any(rval.to_java(jorb))
            when TK_BOOLEAN
              jany.insert_boolean(rval)
            when TK_SHORT
              jany.insert_short(rval)
            when TK_LONG
              jany.insert_long(rval)
            when TK_USHORT
              jany.insert_ushort([rval].pack('S').unpack('s').first)
            when TK_WCHAR
              jany.insert_wchar(rval)
            when TK_ULONG
              jany.insert_ulong([rval].pack('L').unpack('l').first)
            when TK_LONGLONG
              jany.insert_longlong(rval)
            when TK_ULONGLONG
              jany.insert_ulonglong([rval].pack('Q').unpack('q').first)
            when TK_OCTET
              jany.insert_octet([rval].pack('C').unpack('c').first)
            when TK_FLOAT
              jany.insert_float(rval)
            when TK_DOUBLE
              jany.insert_double(rval)
            when TK_LONGDOUBLE
              raise CORBA::NO_IMPLEMENT.new('LongDouble not supported', 0, CORBA::COMPLETED_NO)
            when TK_FIXED
              jany.insert_fixed(java.math.BigDecimal.new(rval.to_s))
            when TK_CHAR
              jany.insert_char(rval[0])
            when TK_STRING
              jany.insert_string(rval)
            when TK_WSTRING
              jany.insert_wstring(rval.inject('') { |s, b| s << b.chr })
            when TK_VALUE
              jany.insert_Value(rval, rtc.tc_)
            when TK_VALUE_BOX
              rtc.get_type::Factory._check_factory(jorb) # make sure valuebox factory has been registered
              rval = rtc.get_type.new(rval) unless rval.nil? || rval.is_a?(CORBA::Portable::BoxedValueBase)
              jany.insert_Value(rval, rtc.tc_)
            when TK_TYPECODE
              jany.insert_TypeCode(rtc.tc_)
            when TK_OBJREF
              jany.insert_Object(rval.objref_)
            when TK_ABSTRACT_INTERFACE
              if rval.is_a?(CORBA::Object)
                # since we know what we're doing use this convenience method provided
                # by JacORB so we only make a shallow copy of the object ref
                # insert_Object() will throw an exception because the typecode is not
                # an objref tc but rather an abstract interface tc
                if CORBA::Native::Jacorb::MAJOR_VERSION < 3
                  jany.insert_object(rtc.tc_, rval.objref_)
                else
                  jany.insert(rtc.tc_, rval.objref_)
                end
              else
                jany.insert_Value(rval, rtc.tc_)
              end
            when TK_PRINCIPAL
              raise CORBA::NO_IMPLEMENT.new('Principal not supported', 0, CORBA::COMPLETED_NO)
            ## TODO: TK_NATIVE
            else
              raise CORBA::MARSHAL.new("unknown kind [#{rtc.kind}]", 0, CORBA::COMPLETED_NO)
            end
            return jany
          else
            dynFactory = CORBA::Native::Dynamic::DynAnyFactoryHelper.narrow(
                          (jorb || CORBA::ORB._orb).resolve_initial_references('DynAnyFactory'))
            jdynany = dynFactory.create_dyn_any_from_type_code(rtc.tc_)
            begin
              unless rval.nil?
                restc = rtc.resolved_tc
                case restc.kind
                when TK_ENUM
                  jdynany.set_as_ulong(rval)
                when TK_ARRAY
                  jelems = CORBA::Native::Reflect::Array.newInstance(CORBA::Native::Any.java_class, rval.size)
                  rval.each_with_index { |e, i| jelems[i] = Any.to_any(e, restc.content_type).to_java(jorb) }
                  jdynany.set_elements(jelems)
                when TK_SEQUENCE
                  jelems = CORBA::Native::Reflect::Array.newInstance(CORBA::Native::Any.java_class, rval.size)
                  rval.each_with_index { |e, i| jelems[i] = Any.to_any(e, restc.content_type).to_java(jorb) }
                  jdynany.set_elements(jelems)
                when TK_STRUCT, TK_EXCEPT
                  jmembers = CORBA::Native::Reflect::Array.newInstance(CORBA::Native::Dynamic::NameValuePair.java_class, restc.members.size)
                  rtc.members.each_with_index { |(mn, mt), i| jmembers[i] = CORBA::Native::Dynamic::NameValuePair.new(mn, Any.to_any(rval.__send__(mn.intern), mt).to_java(jorb)) }
                  jdynany.set_members(jmembers)
                when TK_UNION
                  if rval._is_at_default?
                    jdynany.set_to_default_member
                  elsif rval._disc.nil?
                    jdynany.set_to_no_active_member
                  else
                    jdynany.set_discriminator(dynFactory.create_dyn_any(Any.to_any(rval._disc, restc.discriminator_type).to_java(jorb)))
                  end
                  unless rval._disc.nil? || rval._value.nil?
                    jdynany.member.from_any(Any.to_any(rval._value, rval._value_tc).to_java(jorb))
                  end
                else
                  raise CORBA::MARSHAL.new("unknown kind [#{rtc.kind}]", 0, CORBA::COMPLETED_NO)
                end
              end
              if jany.nil?
                jany = jdynany.to_any
              else
                jany.read_value(jdynany.to_any.create_input_stream, rtc.tc_)
              end
            ensure
              jdynany.destroy
            end
            return jany
          end
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
      end # to_java

      def Any.from_java(jany, jorb = nil, rtc = nil)
        rtc ||= CORBA::TypeCode.from_native(jany.type)
        rval = nil
        begin
          if [TK_NULL, TK_VOID, TK_ANY, TK_BOOLEAN, TK_SHORT, TK_LONG, TK_USHORT,
              TK_WCHAR, TK_ULONG, TK_LONGLONG, TK_ULONGLONG, TK_OCTET,
              TK_FLOAT, TK_DOUBLE, TK_LONGDOUBLE, TK_CHAR, TK_STRING, TK_WSTRING,
              TK_VALUE, TK_VALUE_BOX, TK_TYPECODE, TK_OBJREF,
              TK_ABSTRACT_INTERFACE, TK_PRINCIPAL].include?(rtc.resolved_tc.kind)
            case rtc.resolved_tc.kind
            when TK_NULL, TK_VOID
              # leave as is
            when TK_ANY
              rval = Any.from_java(jany.extract_any, jorb)
            when TK_BOOLEAN
              rval = jany.extract_boolean
            when TK_SHORT
              rval = jany.extract_short
            when TK_LONG
              rval = jany.extract_long
            when TK_USHORT
              rval = [jany.extract_ushort].pack('s').unpack('S').first
            when TK_WCHAR
              rval = jany.extract_wchar
            when TK_ULONG
              rval = [jany.extract_ulong].pack('l').unpack('L').first
            when TK_LONGLONG
              rval = jany.extract_longlong
            when TK_ULONGLONG
              rval = [jany.extract_ulonglong].pack('q').unpack('Q').first
            when TK_OCTET
              rval = [jany.extract_octet].pack('c').unpack('C').first
            when TK_FLOAT
              rval = jany.extract_float
            when TK_DOUBLE
              rval = jany.extract_double
            when TK_LONGDOUBLE
              raise CORBA::NO_IMPLEMENT.new('LongDouble not supported', 0, CORBA::COMPLETED_NO)
            when TK_FIXED
              rval = BigDecimal(jany.extract_fixed.toString)
            when TK_CHAR
              rval = jany.extract_char.chr
            when TK_STRING
              rval = jany.extract_string
            when TK_WSTRING
              rval = jany.extract_wstring
            when TK_VALUE
              rval = jany.extract_Value
            when TK_VALUE_BOX
              rtc.get_type::Factory._check_factory(jorb || CORBA::ORB._orb) # make sure valuebox factory has been registered
              rval = jany.extract_Value
              rval = rval.value unless rval.nil?
            when TK_TYPECODE
              rval = CORBA::TypeCode.from_native(jany.extract_TypeCode)
            when TK_OBJREF
              rval = CORBA::Object._wrap_native(jany.extract_Object)
              rval = rtc.get_type._narrow(rval) if rval
            when TK_ABSTRACT_INTERFACE
              jobj = jany.create_input_stream.read_abstract_interface
              rval = if jobj.is_a?(CORBA::Native::Object)
                rtc.get_type._narrow(CORBA::Object._wrap_native(jobj))
              else
                jobj
              end
            when TK_PRINCIPAL
              raise CORBA::NO_IMPLEMENT.new('Principal not supported', 0, CORBA::COMPLETED_NO)
            ## TODO: TK_NATIVE
            else
              raise CORBA::MARSHAL.new("unknown kind [#{rtc.kind}]", 0, CORBA::COMPLETED_NO)
            end
          else
            dynFactory = CORBA::Native::Dynamic::DynAnyFactoryHelper.narrow(
                          (jorb || CORBA::ORB._orb).resolve_initial_references('DynAnyFactory'))
            jdynany = dynFactory.create_dyn_any(jany)
            begin
              restc = rtc.resolved_tc
              case restc.kind
              when TK_ENUM
                rval = jdynany.get_as_ulong
              when TK_ARRAY
                rval = rtc.get_type.new
                jdynany.get_elements.each { |e| rval << Any.from_java(e, jorb, restc.content_type) }
              when TK_SEQUENCE
                rval = rtc.get_type.new
                jdynany.get_elements.each { |e| rval << Any.from_java(e, jorb, restc.content_type) }
              when TK_STRUCT, TK_EXCEPT
                rval = rtc.get_type.new
                jdynany.get_members.each_with_index { |nvp, i| rval.__send__("#{nvp.id}=".intern, Any.from_java(nvp.value, jorb, restc.member_type(i))) }
              when TK_UNION
                rval = rtc.get_type.new
                if jdynany.get_discriminator.type.kind.value == CORBA::TK_OCTET
                  rdisc = jdynany.get_discriminator.get_octet
                  # Octet 0 designates default member
                  rdisc = rdisc == 0 ? :default : rdisc
                else
                  rdisc = Any.from_java(jdynany.get_discriminator.to_any, jorb, restc.discriminator_type)
                end
                rval.instance_variable_set('@discriminator', rdisc)
                unless jdynany.has_no_active_member
                  minx = rtc.label_index(rdisc)
                  rval.instance_variable_set('@value', Any.from_java(jdynany.member.to_any, jorb, restc.member_type(minx)))
                end
              else
                raise CORBA::MARSHAL.new("unknown kind [#{rtc.kind}]", 0, CORBA::COMPLETED_NO)
              end
            ensure
              jdynany.destroy
            end
          end
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
        return rval
      end # from_java
    end # Any
  end # CORBA
end # R2CORBA
