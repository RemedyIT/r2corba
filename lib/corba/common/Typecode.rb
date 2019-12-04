#--------------------------------------------------------------------
# Typecode.rb - Common CORBA TypeCode definitions
#
# Author: Martin Corino
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the R2CORBA LICENSE which is
# included with this program.
#
# Copyright (c) Remedy IT Expertise BV
#--------------------------------------------------------------------
require 'monitor'

module R2CORBA
  module CORBA
    class TypeCode
      def initialize
        raise 'not allowed'
      end

      @@wrapper_klass = Class.new(CORBA::TypeCode) do
        def initialize(ntc)
          @tc_ = ntc
        end
      end

      attr_reader :tc_

      def self._wrap_native(ntc)
        raise ArgumentError, 'Expected org.omg.CORBA.TypeCode' unless ntc.nil? || ntc.is_a?(Native::TypeCode)
        ntc.nil?() ? ntc : @@wrapper_klass.new(ntc)
      end

      def TypeCode._tc
        CORBA::_tc_TypeCode
      end

      OctetRange     = (0..0xFF).freeze
      UShortRange    = (0..0xFFFF).freeze
      ULongRange     = (0..0xFFFFFFFF).freeze
      ULongLongRange = (0..0xFFFFFFFFFFFFFFFF).freeze
      ShortRange     = (-0x8000...0x8000).freeze
      LongRange      = (-0x80000000...0x80000000).freeze
      LongLongRange  = (-0x8000000000000000...0x8000000000000000).freeze

      @@typecode_registry = (Class.new(Monitor) do
        def initialize
          @id_types = {}
          @name_types = {}
          super
        end
        def []=(id, tc)
          synchronize do
            @id_types[id] = tc
            types_for_name_ = @name_types[tc.name] || []
            types_for_name_ << tc
            @name_types[tc.name] = types_for_name_
          end
        end
        def [](id)
          tc = nil
          synchronize do
            tc = @id_types[id]
          end
          tc
        end
        def types_for_name(name)
          tcs = nil
          synchronize do
            tcs = @name_types[name]
          end
          tcs
        end
      end).new

      def TypeCode.register_id_type(id, tc)
        @@typecode_registry[id] = tc
      end

      def TypeCode.typecode_for_id(id)
        @@typecode_registry[id]
      end

      def TypeCode.typecodes_for_name(name)
        @@typecode_registry.types_for_name(name)
      end

      # native to ruby

      def TypeCode.native_kind(ntc)
        ntc.kind
      end

      def TypeCode.from_native(ntc)
        if [TK_NULL,TK_VOID,TK_ANY,TK_BOOLEAN,TK_SHORT,TK_LONG,TK_USHORT,
            TK_WCHAR,TK_ULONG,TK_LONGLONG,TK_ULONGLONG,TK_OCTET,
            TK_FLOAT,TK_DOUBLE,TK_LONGDOUBLE,TK_CHAR,
            TK_TYPECODE,TK_PRINCIPAL].include?(native_kind(ntc))
          ## primitive typecode; wrap it
          return TypeCode._wrap_native(ntc)
        else
          rtc = nil
          case native_kind(ntc)
          when TK_STRING
            rtc = TypeCode::String.new(ntc)
          when TK_WSTRING
            rtc = TypeCode::WString.new(ntc)
          when TK_FIXED
            rtc = TypeCode::Fixed.new(ntc)
          when TK_ALIAS
            rtc = TypeCode.typecode_for_id(ntc.id)
            unless rtc
              rtc = TypeCode::Alias.new(ntc)
            end
          when TK_ENUM
            rtc = TypeCode.typecode_for_id(ntc.id)
            unless rtc
              rtc = TypeCode::Enum.new(ntc)
            end
          when TK_ARRAY
            rtc = TypeCode::Array.new(ntc)
          when TK_SEQUENCE
            rtc = TypeCode::Sequence.new(ntc)
          when TK_STRUCT
            rtc = TypeCode.typecode_for_id(ntc.id)
            unless rtc
              rtc = TypeCode::Struct.new(ntc)
            end
          when TK_EXCEPT
            rtc = TypeCode.typecode_for_id(ntc.id)
            unless rtc
              rtc = TypeCode::Except.new(ntc)
            end
          when TK_UNION
            rtc = TypeCode.typecode_for_id(ntc.id)
            unless rtc
              rtc = TypeCode::Union.new(ntc)
            end
          when TK_OBJREF
            rtc = TypeCode.typecode_for_id(ntc.id)
            unless rtc
              rtc = TypeCode::ObjectRef.new(ntc)
            end
          when TK_ABSTRACT_INTERFACE
            rtc = TypeCode.typecode_for_id(ntc.id)
            unless rtc
              rtc = TypeCode::AbstractInterface.new(ntc)
            end
          when TK_VALUE_BOX
            rtc = TypeCode.typecode_for_id(ntc.id)
            unless rtc
              rtc = TypeCode::Valuebox.new(ntc)
            end
          when TK_VALUE
            rtc = TypeCode.typecode_for_id(ntc.id)
            unless rtc
              rtc = TypeCode::Valuetype.new(ntc)
            end
          when TK_NATIVE
            raise CORBA::NO_IMPLEMENT.new('typecode #{native_kind(ntc)} not supported',0,CORBA::COMPLETED_NO)
          else
            raise CORBA::MARSHAL.new("unknown kind [#{native_kind(ntc)}]",0,CORBA::COMPLETED_NO)
          end
          return rtc
        end
      end

      # instance methods

      def resolved_tc
        self
      end

      def is_recursive_tc?
        false
      end

      def kind
        raise CORBA::NO_IMPLEMENT
      end

      def get_compact_typecode
        CORBA::TypeCode.from_native(self.tc_.get_compact_typecode)
      end

      def equal?(tc)
        raise ArgumentError, "expected CORBA::TypeCode" unless tc.is_a?(CORBA::TypeCode)
        begin
          self.tc_.equal(tc.tc_)
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
      end

      def equivalent?(tc)
        raise ArgumentError, "expected CORBA::TypeCode" unless tc.is_a?(CORBA::TypeCode)
        begin
          self.tc_.equivalent(tc.tc_)
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
      end

      def id
        begin
          self.tc_.id()
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
      end

      def name
        begin
          self.tc_.name()
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
      end

      def member_count
        begin
          self.tc_.member_count()
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
      end

      def member_name(index)
        begin
          self.tc_.member_name(index.to_i)
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
      end

      def member_type(index)
        begin
          CORBA::TypeCode.from_native(self.tc_.member_type(index.to_i))
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
      end

      def member_label(index)
        raise CORBA::NO_IMPLEMENT
      end

      def discriminator_type
        CORBA::TypeCode.from_native(self.tc_.discriminator_type)
      end

      def default_index
        begin
          self.tc_.default_index()
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
      end

      def length
        begin
          self.tc_.length()
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
      end

      def content_type
        CORBA::TypeCode.from_native(self.tc_.content_type)
      end

      def fixed_digits
        begin
          self.tc_.fixed_digits()
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
      end

      def fixed_scale
        begin
          self.tc_.fixed_scale()
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
      end

      def member_visibility(index)
        begin
          self.tc_.member_visibility(index.to_i)
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
      end

      def type_modifier
        begin
          self.tc_.type_modifier()
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
      end

      def concrete_base_type
        ntc = self.tc_.concrete_base_type
        ntc.nil? ? nil : CORBA::TypeCode.from_native(ntc)
      end

      def get_type
        @type ||= case self.kind
          when TK_SHORT, TK_LONG, TK_USHORT, TK_ULONG
            ::Fixnum
          when TK_LONGLONG, TK_ULONGLONG
            ::Bignum
          when TK_FLOAT, TK_DOUBLE
            ::Float
          when TK_LONGDOUBLE
            ::CORBA::LongDouble
          when TK_BOOLEAN
            ::TrueClass
          when TK_CHAR, TK_STRING
            ::String
          when TK_WCHAR, TK_OCTET
            ::Fixnum
          when TK_VOID, TK_NULL
            ::NilClass
          when TK_ANY
            ::Object
          when TK_TYPECODE
            CORBA::TypeCode
          when TK_OBJREF
            CORBA::Object
          when TK_ABSTRACT_INTERFACE
            ::Object
          else
            nil
        end
      end

      def validate(val)
        case self.kind
        when TK_ANY
          return CORBA::Any === val ? val : Any.to_any(val)
        when TK_BOOLEAN
          return val if ((val.is_a? TrueClass) || (val.is_a? FalseClass))
        when TK_SHORT
          return val.to_int if val.respond_to?(:to_int) && ShortRange === val.to_int
        when TK_LONG
          return val.to_int if val.respond_to?(:to_int) && LongRange === val.to_int
        when TK_USHORT, TK_WCHAR
          return val.to_int if val.respond_to?(:to_int) && UShortRange === val.to_int
        when TK_ULONG
          return val.to_int if val.respond_to?(:to_int) && ULongRange === val.to_int
        when TK_LONGLONG
          return val.to_int if val.respond_to?(:to_int) && LongLongRange === val.to_int
        when TK_ULONGLONG
          return val.to_int if val.respond_to?(:to_int) && ULongLongRange === val.to_int
        when TK_OCTET
          return val.to_int if val.respond_to?(:to_int) && OctetRange === val.to_int
        when TK_FLOAT, TK_DOUBLE
          return val if val.is_a?(::Float)
        when TK_LONGDOUBLE
          return val if val.is_a?(::CORBA::LongDouble)
        when TK_CHAR
          if (val.respond_to?(:to_str) && (val.to_str.size == 1)) ||
              (val.respond_to?(:to_int) && OctetRange === val.to_int)
            return val.respond_to?(:to_str) ? val.to_str : val.to_int.chr
          end
        else
          return val if (val.nil? || val.is_a?(self.get_type))
        end
        raise CORBA::MARSHAL.new(
          "value does not match type: value = #{val}, value type == #{val.class.name}, type == #{get_type.name}",
          1, CORBA::COMPLETED_NO)
      end

      def needs_conversion(val)
        case self.kind
        when TK_SHORT, TK_LONG,
              TK_USHORT, TK_WCHAR,
              TK_ULONG, TK_LONGLONG, TK_ULONGLONG,
              TK_OCTET
          return !(::Integer === val)
        when TK_CHAR
          return !(::String === val)
        end
        false
      end

      class Recursive < CORBA::TypeCode

        def initialize(id)
          raise 'overload required'
        end

        def recursed_tc
          @recursive_tc ||= TypeCode.typecode_for_id(self.id)
          @recursive_tc || ::CORBA::TypeCode.new(TK_NULL)
        end
        def resolved_tc
          recursed_tc.resolved_tc
        end
        def is_recursive_tc?
          true
        end
        def get_type
          @recursive_tc ||= TypeCode.typecode_for_id(self.id)
          if @recursive_tc.nil? then nil; else @recursive_tc.get_type; end
        end
        def validate(val)
          recursed_tc.validate(val)
        end
        def needs_conversion(val)
          recursed_tc.needs_conversion(val)
        end
      end # Recursive

      class String < CORBA::TypeCode

        def initialize(*args)
          raise 'overload required'
        end

        def get_type
          ::String
        end

        def validate(val)
          return val if val.nil?
          super(val) unless ::String === val || val.respond_to?(:to_str)
          val = ::String === val ? val : val.to_str
          raise ::CORBA::MARSHAL.new(
            "string size exceeds bound: #{self.length.to_s}",
            1, ::CORBA::COMPLETED_NO) unless (self.length==0 || val.size<=self.length)
          val
        end

        def needs_conversion(val)
          !(::String === val)
        end
      end # String

      class WString < CORBA::TypeCode

        def initialize(*args)
          raise 'overload required'
        end

        def get_type
          ::Array
        end

        def validate(val)
          return val if val.nil?
          super(val) unless ::Array === val || val.respond_to?(:to_str) || val.respond_to?(:to_ary)
          val = if ::Array === val
            val
          elsif val.respond_to?(:to_ary)
            val.to_ary
          else
            a = []
            val.to_str.each_byte { |c| a << c }
            a
          end
          raise ::CORBA::MARSHAL.new(
            "widestring size exceeds bound: #{self.length.to_s}",
            1, ::CORBA::COMPLETED_NO) unless (self.length==0 || val.size<=self.length)
          raise ::CORBA::MARSHAL.new(
            "invalid widestring element(s)",
            1, ::CORBA::COMPLETED_NO) if val.any? { |el| !(UShortRange === (el.respond_to?(:to_int) ? el.to_int : el)) }
          val.any? { |el| !(::Integer === el) } ? val.collect { |el| el.to_int } : val
        end

        def needs_conversion(val)
          !(::Array === val) ? true : val.any? { |el| !(::Integer === el) }
        end

        def in_value(val)
          if val.respond_to?(:to_str)
            a = []
            val.to_str.each_byte { |c| a << c }
            a
          else
            ::Array === val ? val : val.to_ary
          end
        end
      end # WString

      class Fixed < CORBA::TypeCode

        def initialize(*args)
          raise 'overload required'
        end

        def get_type
          ::BigDecimal
        end

        def validate(val)
          return val if val.nil?
          super(val) unless ::BigDecimal === val || val.respond_to?(:to_str)
          val = ::BigDecimal === val ? val : BigDecimal(val.to_str)
          val
        end

        def needs_conversion(val)
          !(::BigDecimal === val)
        end
      end # Fixed

      class Sequence < CORBA::TypeCode

        def initialize(*args)
          raise 'overload required'
        end

        def get_type
          self.content_type.kind == TK_OCTET || self.content_type.kind == TK_CHAR ? ::String : ::Array
        end

        def validate(val)
          return val if val.nil?
          super(val) unless val.respond_to?(:to_str) || val.respond_to?(:to_ary)
          val = if self.content_type.kind == TK_OCTET || self.content_type.kind == TK_CHAR
            if val.respond_to?(:to_str)
              ::String === val ? val : val.to_str
            else
              s = ''
              val.to_ary.each { |e| s << (e.respond_to?(:to_int) ? e.to_int.chr : e.to_str) }
              s
            end
          elsif val.respond_to?(:to_ary)
            ::Array === val ? val : val.to_ary
          else
              a = []
              val.to_str.each_byte { |c| a << c }
              a
          end
          raise ::CORBA::MARSHAL.new(
            "sequence size exceeds bound: #{self.length.to_s}",
            1, ::CORBA::COMPLETED_NO) unless (self.length==0 || val.size<=self.length)
          if ::Array === val
            if val.any? { |e| self.content_type.needs_conversion(e) }
              val.collect { |e| self.content_type.validate(e) }
            else
              val.each { |e| self.content_type.validate(e) }
            end
          else
            val
          end
        end

        def needs_conversion(val)
          if self.content_type.kind == TK_OCTET || self.content_type.kind == TK_CHAR
            !(::String === val)
          else
            !(::Array === val) ? true : val.any? { |el| self.content_type.needs_conversion(el) }
          end
        end

        def inspect
          "#{self.class.name}: "+
              "length=#{if self.length.nil? then ""; else  self.length.to_s; end}; "+
              "content=#{self.content_type.inspect}"
        end
      end

      class Array < CORBA::TypeCode

        def initialize(*args)
          raise 'overload required'
        end

        def get_type
          ::Array
        end

        def validate(val)
          return val if val.nil?
          super(val)
          raise ::CORBA::MARSHAL.new(
            "array size exceeds bound: #{self.length.to_s}",
            1, ::CORBA::COMPLETED_NO) unless val.nil? || val.size<=self.length
          raise ::CORBA::MARSHAL.new(
            "array size too small: #{self.length.to_s}",
            1, ::CORBA::COMPLETED_NO) unless val.nil? || val.size>=self.length
          val.any? { |e| self.content_type.needs_conversion(e) } ? val.collect { |e| self.content_type.validate(e) } : val.each { |e| self.content_type.validate(e) }
        end

        def needs_conversion(val)
          val.any? { |e| self.content_type.needs_conversion(e) }
        end
      end # Array

      class IdentifiedTypeCode < CORBA::TypeCode

        def initialize(id)
          CORBA::TypeCode.register_id_type(id.to_s, self)
        end
      end # IdentifiedTypeCode

      class Alias < IdentifiedTypeCode
        def initialize(*args)
          raise 'overload required'
        end

        def get_type
          @type || self.content_type.get_type
        end
        def validate(val)
          self.content_type.validate(val)
        end

        def needs_conversion(val)
          self.content_type.needs_conversion(val)
        end

        def resolved_tc
          self.content_type.resolved_tc
        end
      end # Alias

      class Valuetype < IdentifiedTypeCode
        attr_reader :members
        def initialize(*args)
          raise 'overload required'
        end
        def add_member(name, tc, access)
          raise ArgumentError, 'expected CORBA::TypeCode' unless tc.is_a?(CORBA::TypeCode)
          @members << [name, tc, access]
        end

        def Valuetype.define_type(tc)
          trunc_ids = [tc.id]
          rtc = tc
          while rtc != nil && rtc.type_modifier == CORBA::VM_TRUNCATABLE
            rtc = rtc.concrete_base_type
            trunc_ids << rtc.id unless rtc.nil?
          end
          code = %Q{
            class #{tc.name} < ::CORBA::ValueBase
              TRUNCATABLE_IDS = ['#{trunc_ids.join("', '")}'].freeze
              def self._tc
                @@tc_#{tc.name} ||= TypeCode.typecode_for_id('#{tc.id}')
              end
              module Intf
              end
              include Intf
            end
            #{tc.name}
          }
          value_type = ::Object.module_eval(code)
          tc.members.each do |nm_, tc_, access_|
            value_type::Intf.module_eval(%Q{attr_accessor :#{nm_}})
            value_type::Intf.__send__(:private, nm_.intern)
            value_type::Intf.__send__(:private, (nm_+'=').intern)
          end
          value_type
        end

        def get_type
          @type ||= CORBA::TypeCode::Valuetype.define_type(self)
        end

        def validate(val)
          return val if val.nil?
          super(val)
          if needs_conversion(val)
            vorg = val
            val = vorg.class.new
            @members.each { |name, tc| val.__send__((name+'=').intern, tc.validate(vorg.__send__(name.intern))) }
          else
            @members.each { |name, tc| tc.validate(val.__send__(name.intern)) }
          end
          val
        end

        def needs_conversion(val)
          return false if val.nil?
          @members.any? { |name,tc| tc.needs_conversion(val.__send__(name.intern)) }
        end

        def member_count
          @members.size
        end
        def member_name(index)
          raise ::CORBA::TypeCode::Bounds.new if (index<0) || (index>=@members.size)
          @members[index][0]
        end
        def member_type(index)
          raise ::CORBA::TypeCode::Bounds.new if (index<0) || (index>=@members.size)
          @members[index][1]
        end

        def inspect
          s = "#{self.class.name}: #{name} - #{id}\n"
          @members.each { |n, t| s += "  #{n} = "+t.inspect+"\n" }
          s
        end
      end # Valuetype

      class Eventtype < Valuetype
      end # Eventtype

      class Valuebox < IdentifiedTypeCode
        def initialize(*args)
          raise 'overload required'
        end

        def Valuebox.define_type(tc)
          code = %Q{
            class #{tc.name} < ::CORBA::Portable::BoxedValueBase
              def self._tc
                @@tc_#{tc.name} ||= TypeCode.typecode_for_id('#{tc.id}')
              end
              attr_accessor :value
              def initialize(val)
                @value = val
              end
            end
            #{tc.name}
          }
          ::Object.module_eval(code)
        end

        def get_type
          @type || CORBA::TypeCode::Valuebox.define_type(self)
        end

        def validate(val)
          return val if val.nil?
          if CORBA::Portable::BoxedValueBase === val
            super(val)
            val.value = self.content_type.validate(val.value)
          else
            val = self.content_type.validate(val)
          end
          val
        end

        def needs_conversion(val)
          return false if val.nil?
          if CORBA::Portable::BoxedValueBase === val
            self.content_type.needs_conversion(val.value)
          else
            self.content_type.needs_conversion(val)
          end
        end
      end # Valuebox

      class ObjectRef < IdentifiedTypeCode
        def initialize(*args)
          raise 'overload required'
        end

        def get_type
          @type
        end
      end # ObjectRef

      class AbstractInterface < IdentifiedTypeCode
        def initialize(*args)
          raise 'overload required'
        end

        def get_type
          @type
        end
      end # AbstractInterface

      class Struct < IdentifiedTypeCode
        attr_reader :members
        def initialize(*args)
          raise 'overload required'
        end
        def add_member(name, tc)
          raise ArgumentError, 'expected CORBA::TypeCode' unless tc.is_a?(CORBA::TypeCode)
          @members << [name, tc]
        end

        def Struct.define_type(tc)
          code = %Q{
            class #{tc.name} < ::CORBA::Portable::Struct
              def self._tc
                @@tc_#{tc.name} ||= TypeCode.typecode_for_id('#{tc.id}')
              end
              def initialize(*param_)
                #{tc.members.collect {|n,t| "@#{n}"}.join(', ')} = param_
              end
            end
            #{tc.name}
          }
          struct_type = ::Object.module_eval(code)
          tc.members.each do |nm_, tc_|
            struct_type.module_eval(%Q{attr_accessor :#{nm_}})
          end
          struct_type
        end

        def get_type
          @type ||= CORBA::TypeCode::Struct.define_type(self)
        end

        def validate(val)
          return val if val.nil?
          super(val)
          if needs_conversion(val)
            vorg = val
            val = vorg.class.new
            @members.each { |name, tc| val.__send__((name+'=').intern, tc.validate(vorg.__send__(name.intern))) }
          else
            @members.each { |name, tc| tc.validate(val.__send__(name.intern)) }
          end
          val
        end

        def needs_conversion(val)
          @members.any? { |name,tc| tc.needs_conversion(val.__send__(name.intern)) }
        end

        def member_count
          @members.size
        end
        def member_name(index)
          raise ::CORBA::TypeCode::Bounds.new if (index<0) || (index>=@members.size)
          @members[index][0]
        end
        def member_type(index)
          raise ::CORBA::TypeCode::Bounds.new if (index<0) || (index>=@members.size)
          @members[index][1]
        end

        def inspect
          s = "#{self.class.name}: #{name} - #{id}\n"
          @members.each { |n, t| s += "  #{n} = "+t.inspect+"\n" }
          s
        end
      end # Struct

      class SysExcept < Struct
        def initialize(id, name)
          members_ = [['minor', CORBA::_tc_long], ['completed', CORBA::_tc_CompletionStatus]]
          super(id, name, members_)
        end

        def SysExcept.define_type(tc)
          tc.get_type
        end

        def get_type
          CORBA.const_get(self.name.to_sym)
        end
      end

      class Except < Struct
        def Except.define_type(tc)
          except_type = ::Object.module_eval(%Q{
            class #{tc.name} < CORBA::UserException
              def _tc
                @@tc_#{tc.name} ||= TypeCode.typecode_for_id('#{tc.id}')
              end
              def initialize(*param_)
                #{tc.members.collect {|n,t| "@#{n}"}.join(',')} = param_
              end
            end
            #{tc.name}
          })
          tc.members.each do |mname, mtc|
            except_type.module_eval(%Q{attr_accessor :#{mname}})
          end
          except_type
        end

        def get_type
          @type ||= CORBA::TypeCode::Except.define_type(self)
        end
      end # Except

      class Union < IdentifiedTypeCode
        attr_reader :members
        attr_reader :switchtype
        attr_reader :implicit_default
        def initialize(*args)
          raise 'overload required'
        end
        # because creating the native tc involves creating Any's we postpone until actually needed
        def tc_
          raise 'overload required'
        end
        def id
          @id
        end
        def name
          @name
        end
        def add_member(label, name, tc)
          raise ArgumentError, 'expected CORBA::TypeCode' unless tc.is_a?(CORBA::TypeCode)
          @switchtype.validate(label) unless label == :default
          @labels[label] = @members.size
          @members << [label, name.to_s, tc]
        end

        def Union.define_type(tc)
          union_type = ::Object.module_eval(%Q{
            class #{tc.name} < ::CORBA::Portable::Union
              def _tc
                @@tc_#{tc.name} ||= TypeCode.typecode_for_id('#{tc.id}')
              end
            end
            #{tc.name}
          })
          accessors = {}
          tc.members.each_with_index do |_m, ix|
            accessors[_m[1]] = ix unless accessors.has_key?(_m[1])
          end
          accessors.each do |mname, ix|
            union_type.module_eval(%Q{
              def #{mname}; @value; end
              def #{mname}=(val); _set_value(#{ix.to_s}, val); end
            })
          end
          if tc.implicit_default
            union_type.module_eval(%Q{
              def _default; @discriminator = #{tc.implicit_default}; @value = nil; end
            })
          end
          union_type
        end

        def get_type
          @type ||= CORBA::TypeCode::Union.define_type(self)
        end

        def validate(val)
          return val if val.nil?
          super(val)
          @switchtype.validate(val._disc) unless val._disc == :default
          #raise CORBA::MARSHAL.new(
          #  "invalid discriminator value (#{val._disc.to_s}) for union #{name}",
          #  1, CORBA::COMPLETED_NO) unless @labels.has_key?(val._disc)
          if @labels.has_key?(val._disc)  # no need to check for implicit defaults
            if needs_conversion(val)
              vorg = val
              val = vorg.class.new
              val.__send__((@members[@labels[vorg._disc]][1]+'=').intern,
                            @members[@labels[vorg._disc]][2].validate(vorg._value))
            else
              @members[@labels[val._disc]][2].validate(val._value)
            end
          end
          val
        end

        def needs_conversion(val)
          @members[@labels[val._disc]][2].needs_conversion(val._value)
        end

        def member_count
          @members.size
        end
        def member_name(index)
          raise CORBA::TypeCode::Bounds.new if (index<0) || (index>=@members.size)
          @members[index][1]
        end
        def member_type(index)
          raise CORBA::TypeCode::Bounds.new if (index<0) || (index>=@members.size)
          @members[index][2]
        end
        def member_label(index)
          raise CORBA::TypeCode::Bounds.new if (index<0) || (index>=@members.size)
          @members[index][0]
        end
        def discriminator_type
          @switchtype
        end
        def default_index
          if @labels.has_key? :default then @labels[:default]; else -1; end
        end

        def label_index(val)
          val = @switchtype.validate(val) unless val == :default
          #raise CORBA::MARSHAL.new(
          #  "invalid discriminator value (#{val}) for union #{name}",
          #  1, CORBA::COMPLETED_NO) unless val == :default || @labels.has_key?(val) || @labels.has_key?(:default)
          if val == :default then @labels[:default]; elsif @labels.has_key?(val) then @labels[val] else nil end
        end

        def label_member(val)
          return nil unless (lbl_ix = label_index(val))
          member_name(lbl_ix)
        end

        def inspect
          s = "#{self.class.name}: #{name} - #{id}\n"
          @members.each { |l, n, t| s += "  case #{l.to_s}: #{n} = "+t.inspect+"\n" }
          s
        end
      end # Union

      class Enum < IdentifiedTypeCode
        attr_reader :members
        def initialize(*args)
          raise 'overload required'
        end
        def get_type
          ::Integer
        end

        def validate(val)
          super(val) if !val.respond_to?(:to_int)
          raise CORBA::MARSHAL.new(
            "value (#{val}) out of range (#{@range}) for enum: #{name}",
            1, CORBA::COMPLETED_NO) unless @range === (::Integer === val ? val : val.to_int)
          (::Integer === val ? val : val.to_int)
        end

        def needs_conversion(val)
          !(::Integer === val)
        end

        def member_count
          @members.size
        end
        def member_name(index)
          raise CORBA::TypeCode::Bounds.new if (index<0) || (index>=@members.size)
          @members[index]
        end
      end # Enum

      class Bounds < CORBA::UserException
        def Bounds._tc
          @@tc_Bounds ||= CORBA::TypeCode::Except.new('IDL:omg.org/CORBA/TypeCode/Bounds:1.0'.freeze, 'Bounds', [], self)
        end
      end

      class BadKind < CORBA::UserException
        def BadKind._tc
          @@tc_BadKind ||= CORBA::TypeCode::Except.new('IDL:omg.org/CORBA/TypeCode/BadKind:1.0'.freeze, 'BadKind', [], self)
        end
      end

      def TypeCode.get_primitive_tc(kind)
        raise 'overload required'
      end

      private

      def TypeCode._init

        Bounds._tc

        BadKind._tc
      end

    end # TypeCode

    # define typecode constants for primitive types
    [ 'null', 'void',
      'short', 'long', 'ushort', 'ulong', 'longlong', 'ulonglong',
      'float', 'double', 'longdouble',
      'boolean',
      'char', 'octet',
      'wchar',
      'any',
    ].each do |tck|
      CORBA.module_eval %Q{
        def CORBA._tc_#{tck}
          @@tc_#{tck} ||= TypeCode.get_primitive_tc(CORBA::TK_#{tck.upcase})
        end
      }
    end

    def CORBA._tc_string
      @@tc_string ||= TypeCode::String.new()
    end

    def CORBA._tc_wstring
      @@tc_wstring ||= TypeCode::WString.new()
    end

    # define special typecode constants

    def CORBA._tc_TypeCode
      @@tc_TypeCode ||= TypeCode.get_primitive_tc(CORBA::TK_TYPECODE)
    end

    def CORBA._tc_Principal
      @@tc_Principal ||= TypeCode.get_primitive_tc(CORBA::TK_PRINCIPAL)
    end

    def CORBA._tc_Object
      @@tc_Object ||= TypeCode.get_primitive_tc(CORBA::TK_OBJREF)
    end

    def CORBA._tc_CCMObject
      @@tc_CCMObject ||= TypeCode::Component.new("IDL:omg.org/CORBA/CCMObject:1.0", "CCMObject", CORBA::Object).freeze
    end

    def CORBA._tc_CCHome
      @@tc_CCHome ||= TypeCode::Home.new("IDL:omg.org/CORBA/CCHome:1.0", "CCHome", CORBA::Object).freeze
    end

    # define system exception related typecode constants

    def CORBA._tc_CompletionStatus
      @@tc_CompletionStatus ||= TypeCode::Enum.new("IDL:omg.org/CORBA/CompletionStatus:1.0", "CompletionStatus",
                                                   CORBA::COMPLETED_TXT.collect {|t| "COMPLETED_#{t}"})
    end

    class LongDouble
      def to_d(precision)
        BigDecimal(self.to_s(precision))
      end
      def LongDouble._tc
        CORBA._tc_longdouble
      end
    end

  end ## module CORBA
end ## module R2CORBA
