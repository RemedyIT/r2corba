#--------------------------------------------------------------------
# Typecode.rb - Java/JacORB specific CORBA TypeCode definitions
#
# Author: Martin Corino
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the R2CORBA LICENSE which is
# included with this program.
#
# Copyright (c) Remedy IT Expertise BV
#--------------------------------------------------------------------
require 'corba/jbase/Any.rb'
require 'bigdecimal'

module R2CORBA
  module CORBA

    # define typecode kind constants
    ['tk_null',
      'tk_void',
      'tk_short',
      'tk_long',
      'tk_ushort',
      'tk_ulong',
      'tk_float',
      'tk_double',
      'tk_boolean',
      'tk_char',
      'tk_octet',
      'tk_any',
      'tk_TypeCode',
      'tk_Principal',
      'tk_objref',
      'tk_struct',
      'tk_union',
      'tk_enum',
      'tk_string',
      'tk_sequence',
      'tk_array',
      'tk_alias',
      'tk_except',
      'tk_longlong',
      'tk_ulonglong',
      'tk_longdouble',
      'tk_wchar',
      'tk_wstring',
      'tk_fixed',
      'tk_value',
      'tk_value_box',
      'tk_native',
      'tk_abstract_interface'].each do |tk|
      CORBA.const_set(tk.upcase.to_sym, CORBA::Native::TCKind.send("_#{tk}".to_sym))
    end

    class TypeCode

      def TypeCode.native_kind(ntc)
        ntc.kind.value
      end

      def kind
        begin
          self.tc_.kind.value
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
      end

      def member_label(index)
        begin
          Any.from_java(self.tc_.member_label(index.to_i))
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
      end

      class Recursive < CORBA::TypeCode

        def initialize(id)
          begin
            @tc_ = CORBA::ORB._orb.create_recursive_tc(id)
          rescue ::NativeException
            CORBA::Exception.native2r($!)
          end
        end

      end # Recursive

      class String < CORBA::TypeCode

        def initialize(*args)
          if CORBA::Native::TypeCode === args.first
            @tc_ = args.first
          else
            begin
              @tc_ = CORBA::ORB._orb.create_string_tc(args.shift.to_i)
            rescue ::NativeException
              CORBA::Exception.native2r($!)
            end
          end
        end

      end # String

      class WString < CORBA::TypeCode

        def initialize(*args)
          if CORBA::Native::TypeCode === args.first
            @tc_ = args.first
          else
            begin
              @tc_ = CORBA::ORB._orb.create_wstring_tc(args.shift.to_i)
            rescue ::NativeException
              CORBA::Exception.native2r($!)
            end
          end
        end

      end # WString

      class Fixed < CORBA::TypeCode

        def initialize(*args)
          if CORBA::Native::TypeCode === args.first
            @tc_ = args.first
          else
            digits, scale = args
            begin
              @tc_ = CORBA::ORB._orb.create_fixed_tc(digits.to_i, scale.to_i)
            rescue ::NativeException
              CORBA::Exception.native2r($!)
            end
          end
        end

      end # Fixed

      class Sequence < CORBA::TypeCode

        def initialize(*args)
          if CORBA::Native::TypeCode === args.first
            @tc_ = args.first
          else
            element_tc, bound = args
            raise ArgumentError, 'expected CORBA::TypeCode' unless element_tc.is_a?(CORBA::TypeCode)
            begin
              @tc_ = CORBA::ORB._orb.create_sequence_tc(bound.to_i, element_tc.tc_)
            rescue ::NativeException
              CORBA::Exception.native2r($!)
            end
          end
        end

      end

      class Array < CORBA::TypeCode

        def initialize(*args)
          if CORBA::Native::TypeCode === args.first
            @tc_ = args.first
          else
            content_tc = args.shift
            length = args
            raise ArgumentError, 'expected CORBA::TypeCode' unless content_tc.is_a?(CORBA::TypeCode)
            if length.size > 1
              this_len = length.shift
              content_tc = self.class.new(content_tc, *length)
            else
              this_len = length.first
            end
            begin
              @tc_ = CORBA::ORB._orb.create_array_tc(this_len.to_i, content_tc.tc_)
            rescue ::NativeException
              CORBA::Exception.native2r($!)
            end
          end
        end

      end # Array

      class IdentifiedTypeCode < CORBA::TypeCode

        def initialize(id)
          CORBA::TypeCode.register_id_type(id.to_s, self)
        end

      end # IdentifiedTypeCode

      class Alias < IdentifiedTypeCode

        def initialize(*args)
          if CORBA::Native::TypeCode === args.first
            @tc_ = args.first
            @type = nil
            super(@tc_.id)
          else
            id, name, orig_tc, type = args
            raise ArgumentError, 'expected CORBA::TypeCode' unless orig_tc.is_a?(CORBA::TypeCode)
            begin
              @tc_ = CORBA::ORB._orb.create_alias_tc(id.to_s, name.to_s, orig_tc.tc_)
            rescue ::NativeException
              CORBA::Exception.native2r($!)
            end
            @type = type
            super(id)
          end
        end

      end # Alias

      class Valuetype < IdentifiedTypeCode

        def initialize(*args)
          if CORBA::Native::TypeCode === args.first
            @tc_ = args.first
            @type = nil
            @members = []
            @tc_.member_count.times do |i|
              @members << [@tc_.member_name(i), TypeCode.from_native(@tc_.member_type(i))]
            end
            super(id)
          else
            id, name, modifier, base, members_, type_ = args
            raise ArgumentError, 'expected CORBA::Typecode' unless base.nil? || base.is_a?(CORBA::TypeCode)
            raise ArgumentError, 'expected members Array' unless members_.is_a?(::Array) || type_.nil?
            if type_.nil? && !members_.is_a?(::Array)
              type_ = members_
              members_ = []
            end
            @type = type_
            @members = []
            members_.each { |n, tc, access| add_member(n, tc, access) }
            jmembers = CORBA::Native::Reflect::Array.newInstance(CORBA::Native::ValueMember.java_class, @members.size)
            @members.each_with_index do |(mn, mtc, access), i|
              m_id = mtc.is_a?(IdentifiedTypeCode) ? mtc.id : 'IDL:*primitive*:1.0'
              jmembers[i] = CORBA::Native::ValueMember.new(mn.to_s, m_id,
                                                           name, id.split(':').last,
                                                           mtc.tc_, nil,
                                                           access == :public ?
                                                              CORBA::PUBLIC_MEMBER :
                                                              CORBA::PRIVATE_MEMBER)
            end
            @tc_ = _create_tc(id, name, modifier, base, jmembers)
            super(id)
          end
        end

        protected

        def _create_tc(id, name, modifier, base, jmembers)
          begin
            CORBA::ORB._orb.create_value_tc(id.to_s,
                                            name.to_s,
                                            CORBA::VT_MODIFIERS[modifier],
                                            base.nil? ? nil : base.tc_,
                                            jmembers)
          rescue ::NativeException
            CORBA::Exception.native2r($!)
          end
        end

      end # Valuetype

      class Eventtype < Valuetype

        protected

        def _create_tc(id, name, modifier, base, jmembers)
          # JaCORB 2.3.1' does not support tk_event typecodes yet;
          # so just let it be a regular valuetype
          # NOTE: this will not be interoperable between jR2CORBA and R2CORBA
          begin
            CORBA::ORB._orb.create_value_tc(id.to_s,
                                            name.to_s,
                                            CORBA::VT_MODIFIERS[modifier],
                                            base.nil? ? nil : base.tc_,
                                            jmembers)
          rescue ::NativeException
            CORBA::Exception.native2r($!)
          end
        end

      end # Eventtype

      class Valuebox < IdentifiedTypeCode

        def initialize(*args)
          if CORBA::Native::TypeCode === args.first
            @tc_ = args.first
            @type = nil
            super(@tc_.id)
          else
            id, name, boxed_tc, type = args
            raise ArgumentError, 'expected CORBA::TypeCode' unless boxed_tc.is_a?(CORBA::TypeCode)
            begin
              @tc_ = CORBA::ORB._orb.create_value_box_tc(id.to_s, name.to_s, boxed_tc.tc_)
            rescue ::NativeException
              CORBA::Exception.native2r($!)
            end
            @type = type
            super(id)
          end
        end

      end # Valuebox

      class ObjectRef < IdentifiedTypeCode

        def initialize(*args)
          if CORBA::Native::TypeCode === args.first
            @tc_ = args.first
            @type = CORBA::Object
            super(@tc_.id)
          else
            id, name, type = args
            begin
              @tc_ = CORBA::ORB._orb.create_interface_tc(id.to_s, name.to_s)
            rescue ::NativeException
              CORBA::Exception.native2r($!)
            end
            @type = type
            super(id)
          end
        end

      end # ObjectRef

      class AbstractInterface < IdentifiedTypeCode

        def initialize(*args)
          if CORBA::Native::TypeCode === args.first
            @tc_ = args.first
            @type = CORBA::AbstractBase
            super(@tc_.id)
          else
            id, name, type = args
            begin
              @tc_ = CORBA::ORB._orb.create_abstract_interface_tc(id.to_s, name.to_s)
            rescue ::NativeException
              CORBA::Exception.native2r($!)
            end
            @type = type
            super(id)
          end
        end

      end # AbstractInterface

      class Struct < IdentifiedTypeCode

        def initialize(*args)
          if CORBA::Native::TypeCode === args.first
            @tc_ = args.first
            @type = nil
            @members = []
            @tc_.member_count.times do |i|
              @members << [@tc_.member_name(i), TypeCode.from_native(@tc_.member_type(i))]
            end
            super(id)
          else
            id, name, members_, type_ = args
            raise ArgumentError, 'expected members Array' unless members_.is_a?(::Array) || type_.nil?
            if type_.nil? && !members_.is_a?(::Array)
              type_ = members_
              members_ = []
            end
            @type = type_
            @members = []
            members_.each { |n, tc| add_member(n, tc) }
            jmembers = CORBA::Native::Reflect::Array.newInstance(CORBA::Native::StructMember.java_class, @members.size)
            @members.each_with_index {|(mn, mtc), i| jmembers[i] = CORBA::Native::StructMember.new(mn.to_s, mtc.tc_, nil) }
            @tc_ = _create_tc(id, name, jmembers)
            super(id)
          end
        end

        protected

        def _create_tc(id, name, jmembers)
          begin
            CORBA::ORB._orb.create_struct_tc(id.to_s, name.to_s, jmembers)
          rescue ::NativeException
            CORBA::Exception.native2r($!)
          end
        end

      end # Struct

      class Except < Struct

        def from_java(jex)
          raise CORBA::BAD_PARAM.new('org.om.CORBA.UserException expected', 0, CORBA::COMPLETED_NO) unless jex.is_a?(CORBA::Native::UserException)
          ex = get_type.new
          members.each {|mname, mtc| ex.__send__("#{mname}=".to_sym, jex.__send__(mname.to_sym)) }
          ex
        end

        def is_compatible?(jex)
          raise CORBA::BAD_PARAM.new('org.om.CORBA.UserException expected', 0, CORBA::COMPLETED_NO) unless jex.is_a?(CORBA::Native::UserException)
          members.all? {|mname, mtc| jex.respond_to?(mname.to_sym) }
        end

        protected

        def _create_tc(id, name, jmembers)
          begin
            CORBA::ORB._orb.create_exception_tc(id.to_s, name.to_s, jmembers)
          rescue ::NativeException
            CORBA::Exception.native2r($!)
          end
        end

      end # Except

      class Union < IdentifiedTypeCode

        def initialize(*args)
          if CORBA::Native::TypeCode === args.first
            @tc_ = args.first
            @type = nil
            @switchtype = TypeCode.from_native(@tc_.discriminator_type)
            @labels = {}
            @members = []
            def_inx = @tc_.default_index
            @tc_.member_count.times do |i|
              if def_inx < 0 || def_inx != i
                ml_ = Any.from_java(@tc_.member_label(i))
              else
                ml_ = :default
              end
              @labels[ml] = i
              @members << [ml, @tc_.member_name(i), TypeCode.from_native(@tc_.member_type(i))]
            end
            super(id)
          else
            id, name, switchtype_, members_, type_, implicit_default_ = args
            raise ::CORBA::BAD_PARAM unless members_.is_a? ::Array
            raise ::CORBA::BAD_PARAM unless switchtype_.is_a?(CORBA::TypeCode)
            @type = type_
            @implicit_default = implicit_default_
            @switchtype = switchtype_.resolved_tc
            @labels = {}
            @members = []
            members_.each { |mlabel, mname, mtc|
              add_member(mlabel, mname, mtc)
            }
            @id = id
            @name = name
            super(id)
          end
        end
        # because creating the native tc involves creating Any's we postpone until actually needed
        def tc_
          @tc_ ||= begin
            jmembers = CORBA::Native::Reflect::Array.newInstance(CORBA::Native::UnionMember.java_class, @members.size)
            @members.each_with_index {|(ml, mn, mt), i|
              if ml == :default
                # label octet:0 means default label
                jmembers[i] = CORBA::Native::UnionMember.new(mn, Any.to_any(0, CORBA._tc_octet).to_java, mt.tc_, nil)
              else
                jmembers[i] = CORBA::Native::UnionMember.new(mn, Any.to_any(ml, @switchtype).to_java, mt.tc_, nil)
              end
            }
            _create_tc(@id, @name, @switchtype, jmembers)
          end
        end

        protected

        def _create_tc(id, name, disctc, jmembers)
          begin
            CORBA::ORB._orb.create_union_tc(id.to_s, name.to_s, disctc.tc_, jmembers)
          rescue ::NativeException
            CORBA::Exception.native2r($!)
          end
        end

      end # Union

      class Enum < IdentifiedTypeCode

        def initialize(*args)
          if CORBA::Native::TypeCode === args.first
            @tc_ = args.first
            @range = (0..@tc_.member_count).freeze
            @members = @range.to_a.collect {|i| @tc_.member_name(i) }
            super(@tc_.id)
          else
            id, name, members_ = args
            raise CORBA::BAD_PARAM unless members_.is_a? ::Array
            @members = members_.collect {|m| m.to_s}
            @range = (0...@members.size).freeze
            begin
              @tc_ = CORBA::ORB._orb.create_enum_tc(id.to_s, name.to_s, @members.to_java(:string))
            rescue ::NativeException
              CORBA::Exception.native2r($!)
            end
            super(id)
          end
        end

      end # Enum

      def TypeCode.get_primitive_tc(kind)
        case kind
        when CORBA::TK_OBJREF
          TypeCode::ObjectRef.new('IDL:omg.org/CORBA/Object:1.0', 'Object', CORBA::Object).freeze
        else
          TypeCode._wrap_native(CORBA::ORB._orb.get_primitive_tc(CORBA::Native::TCKind.from_int(kind.to_i)))
        end
      end

      # final initialization
      self._init()

    end # TypeCode

  end ## module CORBA
end ## module R2CORBA
