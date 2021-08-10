#--------------------------------------------------------------------
# Any.rb - Common definitions for CORBA Any support
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
    class Any

      def Any.typecode_for_value(val)
        case val
          when CORBA::Any
            return val._tc
          when ::NilClass
            return CORBA._tc_null
          when ::Bignum
            return CORBA._tc_longlong
          when ::Integer
            return CORBA._tc_long
          when ::Float
            return CORBA._tc_double
          when ::TrueClass, ::FalseClass
            return CORBA._tc_boolean
          when ::String
            return CORBA._tc_string
          else
            if val.class.respond_to?(:_tc)
              begin
                tc = val.class._tc
                if tc.is_a? CORBA::TypeCode
                  return tc
                end
              rescue
              end
            else
              if val.is_a? CORBA::Object
                return CORBA._tc_Object
              elsif val.is_a? CORBA::TypeCode
                return CORBA._tc_TypeCode
              end
            end
        end
        return nil
      end

      def Any.value_for_any(any)
        case any
          when CORBA::Any
            return any._value
          else
            return any
        end
      end

      def Any.to_any(o, tc = nil)
        if tc.nil?
          tc = self.typecode_for_value(o)
          if tc.is_a?(CORBA::TypeCode)
            return new(o, tc)
          end
          raise CORBA::MARSHAL.new('missing TypeCode', 0, CORBA::COMPLETED_NO)
        end
        return new(o, tc)
      end

      def _tc
        @__tc
      end
      def _value
        @__value
      end

      private_class_method :new

      protected

      def initialize(o, tc)
        @__tc = tc
        @__value = o
      end

    end # Any
  end # CORBA
end # R2CORBA
