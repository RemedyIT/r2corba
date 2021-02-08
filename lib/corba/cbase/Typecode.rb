#--------------------------------------------------------------------
# Typecode.rb - C++/TAO specific CORBA TypeCode definitions
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
    class TypeCode

      def kind
        begin
          self.tc_.kind
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
      end

      def member_label(index)
        begin
          self.tc_.member_label(index.to_i)
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
      end

      class Recursive < CORBA::TypeCode

        def initialize(id)
          begin
            @tc_ = CORBA::Native::TypeCode.create_recursive_tc(id)
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
              @tc_ = CORBA::Native::TypeCode.create_tc(TK_STRING, args.shift.to_i)
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
              @tc_ = CORBA::Native::TypeCode.create_tc(TK_WSTRING, args.shift.to_i)
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
              @tc_ = CORBA::Native::TypeCode.create_tc(TK_FIXED, digits.to_i, scale.to_i)
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
              @tc_ = CORBA::Native::TypeCode.create_tc(TK_SEQUENCE, bound.to_i, element_tc.tc_)
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
              @tc_ = CORBA::Native::TypeCode.create_tc(TK_ARRAY, this_len.to_i, content_tc.tc_)
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
              @tc_ = CORBA::Native::TypeCode.create_tc(TK_ALIAS, id.to_s, name.to_s, orig_tc.tc_)
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
            n_members = @members.collect do |n, tc, access|
              [n.to_s, tc.tc_, access == :public ? CORBA::PUBLIC_MEMBER : CORBA::PRIVATE_MEMBER]
            end
            @tc_ = _create_tc(id, name, modifier, base, n_members)
            super(id)
          end
        end

        protected

        def _create_tc(id, name, modifier, base, members)
          begin
            CORBA::Native::TypeCode.create_tc(TK_VALUE, id.to_s, name.to_s,
                                              CORBA::VT_MODIFIERS[modifier],
                                              base.nil? ? nil : base.tc_,
                                              members)
          rescue ::NativeException
            CORBA::Exception.native2r($!)
          end
        end

      end # Valuetype

      class Eventtype < Valuetype

        protected

        def _create_tc(id, name, modifier, base, members)
          begin
            CORBA::Native::TypeCode.create_tc(TK_EVENT, id.to_s, name.to_s,
                                              CORBA::VT_MODIFIERS[modifier],
                                              base.nil? ? nil : base.tc_,
                                              members)
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
              @tc_ = CORBA::Native::TypeCode.create_tc(TK_VALUE_BOX, id.to_s, name.to_s, boxed_tc.tc_)
            rescue ::NativeException
              CORBA::Exception.native2r($!)
            end
            @type = type
            super(id)
            ## autoregister
            CORBA::ORB._check_value_factory(@type::Factory) if @type < CORBA::Portable::BoxedValueBase
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
              @tc_ = CORBA::Native::TypeCode.create_tc(TK_OBJREF, id.to_s, name.to_s)
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
              @tc_ = CORBA::Native::TypeCode.create_tc(TK_ABSTRACT_INTERFACE, id.to_s, name.to_s)
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
            n_members = @members.collect {|n, tc| [n.to_s(), tc.tc_] }
            @tc_ = _create_tc(id, name, n_members)
            super(id)
          end
        end

        protected

        def _create_tc(id, name, members)
          begin
            CORBA::Native::TypeCode.create_tc(TK_STRUCT, id.to_s, name.to_s, members)
          rescue ::NativeException
            CORBA::Exception.native2r($!)
          end
        end

      end # Struct

      class Except < Struct

        protected

        def _create_tc(id, name, members)
          begin
            CORBA::Native::TypeCode.create_tc(TK_EXCEPT, id.to_s, name.to_s, members)
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
                ml_ = @tc_.member_label(i)
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
            n_members = @members.collect do |ml, mn, mtc|
              [ml, mn.to_s, mtc.tc_]
            end
            @tc = _create_tc(@id, @name, @switchtype, n_members)
            super(id)
          end
        end

        def tc_
          @tc
        end

        protected

        def _create_tc(id, name, disctc, members)
          begin
            CORBA::Native::TypeCode.create_tc(TK_UNION, id.to_s, name.to_s, disctc.tc_, members)
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
              @tc_ = CORBA::Native::TypeCode.create_tc(TK_ENUM, id.to_s, name.to_s, @members)
            rescue ::NativeException
              CORBA::Exception.native2r($!)
            end
            super(id)
          end
        end

      end # Enum

      def TypeCode.get_primitive_tc(kind)
        TypeCode._wrap_native(CORBA::Native::TypeCode.get_primitive_tc(kind.to_i))
      end

      # final initialization
      self._init()

    end # TypeCode

  end ## module CORBA
end ## module R2CORBA
