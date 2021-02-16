#--------------------------------------------------------------------
# ORB.rb - Common CORBA ORB definitions
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

    def CORBA.ORB_init(*args)
      # actual CORBA wrapper implementation implements
      # the ORB.init method
      self::ORB.init(*args)
    end

    module ORB
      @@wrapper_klass = Class.new do
        include ::R2CORBA::CORBA::ORB
        def initialize(norb)
          @orb_ = norb
        end
        attr_reader :orb_
      end

      def self._wrap_native(norb)
        raise ArgumentError, 'Expected org.omg.CORBA.ORB' unless norb.nil? || norb.is_a?(Native::ORB)
        norb.nil?() ? norb : @@wrapper_klass.new(norb)
      end

      ## init() or init(orb_id, prop = {}) or init(argv, orb_id, prop={}) or init(argv, prop={})
      def self.init(*args)
        raise ::CORBA::NO_IMPLEMENT
      end

      @@cached_orb = nil

      def self._orb
        @@cached_orb || _singleton_orb_init
      end

      def ==(other)
        self.class == other.class && self.orb_.eql?(other.orb_)
      end

      def hash
        self.orb_.hash
      end

      def dup
        self
      end

      def clone
        self
      end

      #obj ::CORBA::Object
      #ret ::String
      def object_to_string(obj)
        raise CORBA::BAD_PARAM.new('CORBA::Object required', 0, CORBA::COMPLETED_NO) unless obj.is_a?(CORBA::Object)
        begin
          self.orb_.object_to_string(obj.objref_)
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
      end

      #str ::String
      #ret ::CORBA::Object
      def string_to_object(str)
        begin
          Object._wrap_native(self.orb_.string_to_object(str))
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
      end

      #str ::Integer
      #ret ::CORBA::NVList
      def create_list(count)
        raise CORBA::NO_IMPLEMENT
      end

      #str OperationDef
      #ret ::CORBA::NVList
      def create_operation_list(oper)
        raise CORBA::NO_IMPLEMENT
      end

      #ret Context
      def get_default_context()
        raise CORBA::NO_IMPLEMENT
      end

      #req RequestSeq
      #ret void
      def send_multiple_request_oneway(req)
        raise CORBA::NO_IMPLEMENT
      end

      #req RequestSeq
      #ret void
      def send_multiple_request_deferred(req)
        raise CORBA::NO_IMPLEMENT
      end

      #ret boolean
      def poll_next_response()
        raise CORBA::NO_IMPLEMENT
      end

      #ret Request
      def get_next_response()
        raise CORBA::NO_IMPLEMENT
      end

      #  Service information operations

      # ServiceType service_type
      # ret [boolean, ServiceInformation]
      def get_service_information(service_type)
        raise CORBA::NO_IMPLEMENT
      end

      # ret [::String, ...]
      def list_initial_services()
        self.orb_.list_initial_services()
      end

=begin
// Initial reference operations
=end
      # ::String identifier
      # ret Object
      # raises InvalidName
      def resolve_initial_references(identifier)
        begin
          Object._wrap_native(self.orb_.resolve_initial_references(identifier))
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
      end

      # ::String identifier
      # CORBA::Object obj
      # ret void
      # raises InvalidName
      def register_initial_reference(identifier, obj)
        raise ::CORBA::NO_IMPLEMENT
      end

=begin
// Type code creation operations
=end
      # String id
      # String name
      # [] members
      # ret TypeCode
      def create_struct_tc(id, name, *members)
        return CORBA::TypeCode::Struct.new(id.to_s.freeze, name.to_s, nil, members)
      end

      # String id
      # String name
      # [] members
      # ret TypeCode
      def create_exception_tc(id, name, *members)
        return CORBA::TypeCode::Except.new(id.to_s.freeze, name.to_s, nil, members)
      end

      # String id
      # String name
      # TypeCode discriminator_type
      # [] members
      # ret TypeCode
      def create_union_tc(id, name, discriminator_type, *members)
        return CORBA::TypeCode::Union.new(id.to_s.freeze, name.to_s, nil, discriminator_type, members)
      end

      # String id
      # String name
      # [] members
      # ret TypeCode
      def create_enum_tc(id, name, *members)
        return CORBA::TypeCode::Enum.new(id.to_s.freeze, name.to_s, members)
      end

      # String id
      # String name
      # TypeCode original_type
      # ret TypeCode
      def create_alias_tc(id, name, original_type)
        return CORBA::TypeCode::Alias.new(id.to_s.freeze, name.to_s, nil, original_type)
      end

      # String id
      # String name
      # ret TypeCode
      def create_interface_tc(id, name)
        return CORBA::TypeCode::ObjectRef.new(id.to_s.freeze, name.to_s, nil)
      end

      # Integer bound
      # ret TypeCode
      def create_string_tc(bound=nil)
        return CORBA::TypeCode::String.new(bound)
      end

      # Integer bound
      # ret TypeCode
      def create_wstring_tc(bound=nil)
        return CORBA::TypeCode::WString.new(bound)
      end

      # Integer(ushort) digits
      # Integer(short) scale
      # ret TypeCode
      def create_fixed_tc(digits, scale)
        return CORBA::TypeCode::Fixed.new(digits, scale)
      end

      # Integer bound
      # TypeCode element_type
      # ret TypeCode
      def create_sequence_tc(bound, element_type)
        return CORBA::TypeCode::Sequence.new(element_type, bound)
      end

      # Integer length
      # TypeCode element_type
      # ret TypeCode
      def create_array_tc(length, element_type)
        return CORBA::TypeCode::Array.new(element_type, length)
      end

      # String id
      # ret TypeCode
      def create_recursive_tc(id)
        return CORBA::TypeCode::Recursive.new(id.to_s.freeze)
      end

      # RepositoryId id
      # Identifier name
      # ValueModifier type_modifier
      # TypeCode concrete_base
      # ValueMemberSeq members
      # ret TypeCode
      def create_value_tc(id, name, type_modifier, concrete_base, members)
        return CORBA::TypeCode::Valuetype.new(id, name, type_modifier, concrete_base, members)
      end

      # RepositoryId id
      # Identifier name
      # TypeCode boxed_type
      # ret TypeCode
      def create_value_box_tc(id, name, boxed_type)
        return CORBA::TypeCode::Valuebox.new(id, name, boxed_type)
      end

      # RepositoryId id
      # Identifier name
      # ret TypeCode
      def create_native_tc(id, name)
        # TODO ORB::create_native_tc
        raise ::CORBA::NO_IMPLEMENT
      end

      # RepositoryId id
      # Identifier name
      # ret TypeCode
      def create_abstract_interface_tc(id, name)
        return CORBA::TypeCode::AbstractInterface.new(id.to_s.freeze, name.to_s, nil)
      end

=begin
// Thread related operations
=end

      # ret boolean
      def work_pending()
        begin
          self.orb_.work_pending()
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
      end

      # ret void
      def perform_work()
        begin
          self.orb_.perform_work()
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
      end

      # ret void
      def run()
        begin
          self.orb_.run()
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
      end

      # boolean wait_for_completion
      # ret void
      def shutdown(wait_for_completion = false)
        begin
          self.orb_.shutdown(wait_for_completion)
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
      end

      # ret void
      def destroy()
        begin
          self.orb_.destroy()
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
      end

=begin
// Policy related operations
=end

      # PolicyType type
      # any val
      #ret Policy
      #raises PolicyError
      def create_policy(type, val)
        raise ::CORBA::NO_IMPLEMENT
      end

=begin
// Value factory operations
=end
      # RepositoryId id
      # ValueFactory factory
      #ret ValueFactory
      def register_value_factory(id, factory)
        self.orb_().register_value_factory(id, factory)
      end

      # RepositoryId id
      # ret void
      def unregister_value_factory(id)
        self.orb_().unregister_value_factory(id)
      end

      # RepositoryId id
      #ret ValueFactory
      def lookup_value_factory(id)
        self.orb_().lookup_value_factory(id)
      end
    end # ORB

  end # CORBA
end # R2CORBA
