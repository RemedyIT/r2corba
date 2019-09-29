#--------------------------------------------------------------------
# Streams.rb - C++/TAO Definition of CORBA CDR Streams
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

module R2CORBA
  module CORBA
    module Portable
      module InputStream
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
            raise CORBA::NO_IMPLEMENT.new('LongDouble not supported',0,CORBA::COMPLETED_NO)
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
          when TK_VALUE, TK_VALUE_BOX, TK_EVENT
            read_Value()
            ## TODO: TK_NATIVE
          end
          v
        end
      end

      module OutputStream
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
            raise CORBA::NO_IMPLEMENT.new('LongDouble not supported',0,CORBA::COMPLETED_NO)
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
          when TK_VALUE, TK_VALUE_BOX, TK_EVENT
            write_Value(value)
            ## TODO: TK_NATIVE
          end
        end
      end
    end
  end
end
