#--------------------------------------------------------------------
# policies.rb - Java/JacORB R2CORBA Policy support loader
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

    module ORB
      def create_policy(type, val)
        raise CORBA::BAD_PARAM.new('Any expected',0,CORBA::COMPLETED_NO) unless CORBA::Any === val
        begin
          Policy._wrap_native(self.orb_.create_policy(type.to_i, val.to_java(self.orb_)))
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
      end
    end # ORB

    module Object
      def _get_policy(policy_type)
        raise CORBA::INV_OBJREF.new if self._is_nil?()
        begin
          pol = Policy._wrap_native(self.objref_._get_policy(policy_type))
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
        raise CORBA::INV_POLICY if CORBA.is_nil(pol) # provide spec compliance
      end

      def _get_policy_overrides(ts)
        raise CORBA::INV_OBJREF.new if self._is_nil?()
        ## currently JacORB does not support #_get_policy_overrides so we emulate it in that case
        unless self.objref_.respond_to?(:_get_policy_overrides)
          begin
            ts.collect { |pt| Policy._wrap_native(self.objref_._get_policy(pt)) }.compact
          rescue ::NativeException
            CORBA::Exception.native2r($!)
          end
        else
          begin
            jpolicies = self.objref_._get_policy_overrides(ts.to_java(:int))
          rescue ::NativeException
            CORBA::Exception.native2r($!)
          end
          jpolicies.collect {|jpol| Policy._wrap_native(jpol) }
        end
      end #of operation get_policy_overrides

      def _set_policy_overrides(policies, set_add)
        raise CORBA::INV_OBJREF.new if self._is_nil?()
        jpolicies = CORBA::Native::Reflect::Array.newInstance(CORBA::Native::Policy.java_class, policies.size)
        policies.each_with_index {|e,i| jpolicies[i] = e.objref_ }
        begin
          obj = self.objref_._set_policy_override(jpolicies, Native::SetOverrideType.from_int(set_add))
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
        CORBA::Object._wrap_native(obj)
      end

      ## Currently unsupported by JacORB
#      def _validate_connection(inconsistent_policies)
#        raise CORBA::INV_OBJREF.new if self._is_nil?()
#        jpollist = CORBA::Native::PolicyListHolder.new
#        ret = self.objref_._validate_connection(jpollist) rescue CORBA::Exception.native2r($!)
#        jpollist.value.each {|jpol| inconsistent_policies << Policy._wrap_native(jpol) }
#        ret
#      end
    end # Object

    module Policy
      def self._wrap_native(jpol)
        raise ArgumentError, 'Expected org.omg.CORBA.Policy' unless jpol.nil? || jpol.is_a?(Native::Policy)
        Policy._narrow(CORBA::Object._wrap_native(jpol))
      end

      #-------------------  "Policy Operations"

      def policy_type()
        begin
          self.objref_.policy_type()
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
      end #of attribute get_policy_type

      def copy()
        begin
          Policy._wrap_native(self.objref_.copy())
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
      end #of operation copy

      def destroy()
        begin
          self.objref_.destroy()
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
        @objref_ = nil
      end #of operation destroy
    end # Policy

    module PolicyManager
      #-------------------  "PolicyManager Operations"

      def get_policy_overrides(ts)
        begin
          jpolicies = self.objref_.get_policy_overrides(ts.to_java(:int))
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
        jpolicies.collect {|jpol| Policy._wrap_native(jpol) }
      end #of operation get_policy_overrides

      def set_policy_overrides(policies, set_add)
        jpolicies = CORBA::Native::Reflect::Array.newInstance(CORBA::Native::Policy.java_class, policies.size)
        policies.each_with_index {|e,i| jpolicies[i] = e.objref_ }
        begin
          self.objref_.set_policy_overrides(jpolicies, Native::SetOverrideType.from_int(set_add))
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
      end #of operation set_policy_overrides
    end # Policy

  end # CORBA

  module PortableServer

    module POA
      def create_thread_policy(value)
        begin
          PortableServer::ThreadPolicy._narrow(
            CORBA::Object._wrap_native(
                self.objref_.create_thread_policy(PortableServer::Native::ThreadPolicyValue.from_int(value))))
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
      end #of operation create_thread_policy

      def create_lifespan_policy(value)
        begin
          PortableServer::LifespanPolicy._narrow(
            CORBA::Object._wrap_native(
                self.objref_.create_lifespan_policy(PortableServer::Native::LifespanPolicyValue.from_int(value))))
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
      end #of operation create_lifespan_policy

      def create_id_uniqueness_policy(value)
        begin
          PortableServer::IdUniquenessPolicy._narrow(
            CORBA::Object._wrap_native(
                self.objref_.create_id_uniqueness_policy(PortableServer::Native::IdUniquenessPolicyValue.from_int(value))))
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
      end #of operation create_id_uniqueness_policy

      def create_id_assignment_policy(value)
        begin
          PortableServer::IdAssignmentPolicy._narrow(
            CORBA::Object._wrap_native(
                self.objref_.create_id_assignment_policy(PortableServer::Native::IdAssignmentPolicyValue.from_int(value))))
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
      end #of operation create_id_assignment_policy

      def create_implicit_activation_policy(value)
        begin
          PortableServer::ImplicitActivationPolicy._narrow(
            CORBA::Object._wrap_native(
                self.objref_.create_implicit_activation_policy(PortableServer::Native::ImplicitActivationPolicyValue.from_int(value))))
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
      end #of operation create_implicit_activation_policy

      def create_servant_retention_policy(value)
        begin
          PortableServer::ServantRetentionPolicy._narrow(
            CORBA::Object._wrap_native(
                self.objref_.create_servant_retention_policy(PortableServer::Native::ServantRetentionPolicyValue.from_int(value))))
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
      end #of operation create_servant_retention_policy

      def create_request_processing_policy(value)
        begin
          PortableServer::RequestProcessingPolicy._narrow(
            CORBA::Object._wrap_native(
                self.objref_.create_request_processing_policy(PortableServer::Native::RequestProcessingPolicyValue.from_int(value))))
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
      end #of operation create_request_processing_policy
    end # POA

    module ThreadPolicy  ## interface
      def value()
        begin
          self.objref_.value().value()
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
      end #of attribute get_value
    end #of interface ThreadPolicy

    module LifespanPolicy  ## interface
      def value()
        begin
          self.objref_.value().value()
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
      end #of attribute get_value
    end #of interface LifespanPolicy

    module IdUniquenessPolicy  ## interface
      def value()
        begin
          self.objref_.value().value()
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
      end #of attribute get_value
    end #of interface IdUniquenessPolicy

    module IdAssignmentPolicy  ## interface
      def value()
        begin
          self.objref_.value().value()
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
      end #of attribute get_value
    end #of interface IdAssignmentPolicy

    module ImplicitActivationPolicy  ## interface
      def value()
        begin
          self.objref_.value().value()
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
      end #of attribute get_value
    end #of interface ImplicitActivationPolicy

    module ServantRetentionPolicy  ## interface
      def value()
        begin
          self.objref_.value().value()
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
      end #of attribute get_value
    end #of interface RequestProcessingPolicy

    module RequestProcessingPolicy  ## interface
      def value()
        begin
          self.objref_.value().value()
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
      end #of attribute get_value
    end #of interface RequestProcessingPolicy

  end # PortableServer

  module BiDirPolicy

    module BidirectionalPolicy  ## interface
      def value()
        begin
          self.objref_.value().value()
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
      end #of attribute get_value
    end #of interface BidirectionalPolicy

  end # BiDirPolicy

end # R2CORBA
