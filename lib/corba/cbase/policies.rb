#--------------------------------------------------------------------
# policies.rb - C++/TAO R2CORBA Policy support loader
#
# Author: Martin Corino
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the R2CORBA LICENSE which is
# included with this program.
#
# Copyright (c) Remedy IT Expertise BV
#--------------------------------------------------------------------
require 'corba/idl/TAO_ExtC'

begin
  require 'librpol'
rescue LoadError
  $stderr.puts $!.to_s if $VERBOSE
  raise
end

module R2CORBA
  module CORBA
    module ORB
      def create_policy(type, val)
        raise CORBA::BAD_PARAM.new('Any expected', 0, CORBA::COMPLETED_NO) unless CORBA::Any === val
        begin
          self.orb_.create_policy(type.to_i, val)
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
      end
    end # ORB

    module Object
      def _get_policy(policy_type)
        raise CORBA::INV_OBJREF.new if self._is_nil?()
        begin
          pol = self.objref_._get_policy(policy_type)
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
        raise CORBA::INV_POLICY if CORBA.is_nil(pol) # provide spec compliance
      end

      def _set_policy_overrides(policies, set_add)
        raise CORBA::INV_OBJREF.new if self._is_nil?()
        begin
          CORBA::Object._wrap_native(self.objref_._set_policy_overrides(policies, set_add))
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
      end

      def _get_policy_overrides(types)
        raise CORBA::INV_OBJREF.new if self._is_nil?()
        begin
          self.objref_._get_policy_overrides(types)
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
      end

      def _validate_connection(inconsistent_policies)
        raise CORBA::INV_OBJREF.new if self._is_nil?()
        begin
          self.objref_._validate_connection(inconsistent_policies)
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
      end
    end # Object
  end # CORBA
end # R2CORBA
