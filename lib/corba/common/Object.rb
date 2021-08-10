#--------------------------------------------------------------------
# Object.rb - Common CORBA Object definitions
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

    def CORBA.is_nil(obj)
      if obj.nil?
        return true
      elsif obj.is_a?(R2CORBA::CORBA::Object) || obj.respond_to?(:_is_nil?)
        return obj._is_nil?()
      end
      false
    end

    module Object
      @@wrapper_klass = Class.new do
        include CORBA::Object
        def initialize(nobj)
          @objref_ = nobj
        end
        def _free_ref
          self._release
        end
        attr_reader :objref_
        def self.name
          'CORBA::Object'
        end
      end

      def self._wrap_native(nobj)
        raise ArgumentError, 'Expected org.omg.CORBA.Object' unless nobj.nil? || nobj.is_a?(Native::Object)
        (nobj.nil? || (nobj.respond_to?(:_is_nil) && nobj._is_nil)) ? nil : @@wrapper_klass.new(nobj)
      end

      def self._narrow(obj)
        raise CORBA::BAD_PARAM.new('not an object reference', 0, CORBA::COMPLETED_NO) unless obj.nil? || obj.is_a?(CORBA::Object) || obj.is_a?(Native::Object)
        obj = self._wrap_native(obj) if obj.is_a?(Native::Object)
        obj
      end

      def self._tc
        CORBA._tc_Object
      end

      #-------------------  4.3 "Object Reference Operations"

      def ==(other)
        self.class == other.class && self.objref_.eql?(other.objref_)
      end

      def hash
        self.objref_.hash
      end

      def dup
        self
      end

      def clone
        self
      end

      #ret InterfaceDef
      def _get_interface()
        raise ::CORBA::NO_IMPLEMENT
      end

      #ret boolean
      def _is_nil?()
        self.objref_.nil? || (self.objref_.respond_to?(:_is_nil) && self.objref_._is_nil)
      end

      #ret ::CORBA::Object
      def _duplicate()
        return nil if self._is_nil?()
        begin
          self._wrap_native(self.objref_._duplicate)
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
      end

      # ret void
      def _release()
        self.objref_._release unless self.objref_.nil?
        @objref_ = nil
      end

      # ::String logical_type_id
      # ret boolean
      def _is_a?(logical_type_id)
        return false if self._is_nil?()
        begin
          self.objref_._is_a(logical_type_id)
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
      end

      # ret boolean
      def _non_existent?()
        raise CORBA::INV_OBJREF.new if self._is_nil?()
        begin
          self.objref_._non_existent
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
      end

      # ::CORBA::Object other_object
      # ret boolean
      def _is_equivalent?(other_object)
        raise CORBA::INV_OBJREF.new if self._is_nil?()
        begin
          self.objref_._is_equivalent(other_object)
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
      end

      # Integer(ulong) maximum
      # ret unsigned long
      def _hash(maximum)
        raise CORBA::INV_OBJREF.new if self._is_nil?()
        begin
          self.objref_._hash(maximum)
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
      end

      # ret ::String
      def _repository_id()
        raise CORBA::INV_OBJREF.new if self._is_nil?()
        ## if this object ref has already been narrowed
        return self._interface_repository_id if self.respond_to?(:_interface_repository_id)
        ## ask the remote side
        begin
          self.objref_._repository_id()
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
      end

      #def PolicyType policy_type
      # ret Policy
      def _get_policy(policy_type)
        raise ::CORBA::NO_IMPLEMENT
      end

      #PolicyList policies
      #SetOverrideType set_add
      #ret ::CORBA::Object
      def _set_policy_overrides(policies, set_add)
        raise ::CORBA::NO_IMPLEMENT
      end

      #int[] types
      #ret PolicyList
      def _get_policy_overrides(types)
        raise ::CORBA::NO_IMPLEMENT
      end

      #PolicyList inconsistent_policies
      #ret bool
      def _validate_connection(inconsistent_policies)
        raise ::CORBA::NO_IMPLEMENT
      end

      #ret ::CORBA::Object
      def _get_component()
        raise CORBA::INV_OBJREF.new if self._is_nil?()
        begin
          CORBA::Object._wrap_native(self.objref_._get_component())
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
      end

      # ret CORBA::ORB
      def _get_orb()
        raise CORBA::INV_OBJREF.new if self._is_nil?()
        begin
          CORBA::ORB._wrap_native(self.objref_._get_orb)
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
      end

      def _request(operation)
        raise CORBA::INV_OBJREF.new if self._is_nil?()
        begin
          self.objref_._request(operation.to_s)
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
      end

    end # Object
  end # CORBA
end # R2CORBA
