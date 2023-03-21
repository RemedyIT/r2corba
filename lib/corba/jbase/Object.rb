#--------------------------------------------------------------------
# Object.rb - Java/JacORB CORBA Object definitions
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
    module Object
      # ret InterfaceDef
      def _get_interface
        raise ::CORBA::NO_IMPLEMENT
        # ifdef_obj = self.objref_._get_interface_def rescue CORBA::Exception.native2r($!)
        # (ifdef_obj = CORBA::Native::InterfaceDefHelper.narrow(ifdef_obj) rescue CORBA::Exception.native2r($!)) unless ifdef_obj.nil?
      end

      # ::String logical_type_id
      # ret boolean
      def _is_a?(logical_type_id)
        raise CORBA::INV_OBJREF.new if self._is_nil?()
        ## JacORB's LocalObjects throw NO_IMPLEMENT on _is_a?() and _ids() is also not always defined
        return true if self.objref_.is_a?(CORBA::Native::LocalObject) &&
                        (!self.objref_.respond_to?(:_ids) || self.objref_._ids().include?(logical_type_id))

        begin
          self.objref_._is_a(logical_type_id)
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
      end

      # ret ::String
      def _repository_id
        raise CORBA::INV_OBJREF.new if self._is_nil?()
        ## if this object ref has already been narrowed
        return self._interface_repository_id if self.respond_to?(:_interface_repository_id)

        ## ask the remote side
        ## have to do this ourselves since JacORB only resolves this locally (never calling remote)
        req = self._request('_repository_id')
        req.set_return_type(CORBA._tc_string)
        return req.invoke
      end

      unless CORBA::Native::Portable::ObjectImpl.public_instance_methods.include?(:_get_component)
        # ret ::CORBA::Object
        def _get_component
          raise CORBA::INV_OBJREF.new if self._is_nil?()

          ## ask the remote side
          ## have to do this ourselves since JacORB does not support this remote method on Object
          ## and we can't use #invoke since this should work without narrowing
          req = self._request('_component')
          req.set_return_type(CORBA._tc_Object)
          return req.invoke
        end
      end

      # def PolicyType policy_type
      # ret Policy
      def _get_policy(policy_type)
        raise ::CORBA::NO_IMPLEMENT
      end

      # PolicyList policies
      # SetOverrideType set_add
      # ret ::CORBA::Object
      def _set_policy_overrides(policies, set_add)
        raise ::CORBA::NO_IMPLEMENT
      end

      # int[] types
      # ret PolicyList
      def _get_policy_overrides(types)
        raise ::CORBA::NO_IMPLEMENT
      end

      # PolicyList inconsistent_policies
      # ret bool
      def _validate_connection(inconsistent_policies)
        raise ::CORBA::NO_IMPLEMENT
      end

      def _request(operation)
        begin
          CORBA::Request._wrap_native(self.objref_._request(operation.to_s), self)
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
      end
    end # Object
  end # CORBA
end # R2CORBA
