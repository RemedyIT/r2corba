#--------------------------------------------------------------------
# poa.rb - Java/JacORB R2CORBA POA loader
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
  module PortableServer
    module Native
      include_package 'org.omg.PortableServer'
    end
  end
end

require 'corba/common/Servant.rb'
require 'corba/idl/POAC.rb'
require 'corba/jbase/Servant.rb'
require 'corba/jbase/ServerRequest.rb'

module R2CORBA
  module PortableServer
    def self.string_to_ObjectId(s)
      raise CORBA::NO_IMPLEMENT
    end

    def self.ObjectId_to_string(oid)
      raise CORBA::NO_IMPLEMENT
    end

    module POA
      def destroy(etherealize_objects, wait_for_completion)
        begin
          self.objref_.destroy(etherealize_objects != false, wait_for_completion != false)
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
      end #of operation destroy

      def the_name()
        begin
          self.objref_.the_name()
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
      end #of attribute get_the_name

      def the_POAManager()
        begin
          PortableServer::POAManager._narrow(CORBA::Object._wrap_native(self.objref_.the_POAManager()))
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
      end #of attribute get_the_POAManager

      def the_parent()
        begin
          PortableServer::POA._narrow(CORBA::Object._wrap_native(self.objref_.the_parent()))
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
      end #of attribute get_the_parent

      def the_children()
        begin
          self.objref_.the_children().collect {|c| PortableServer::POA._narrow(CORBA::Object._wrap_native(c)) }
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
      end #of attribute get_the_children

      def activate_object(p_servant)
        begin
          String.from_java_bytes(self.objref_.activate_object(p_servant.srvref_))
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
      end #of operation activate_object

      def activate_object_with_id(r_id, p_servant)
        begin
          self.objref_.activate_object_with_id(r_id.to_s.to_java_bytes, p_servant.srvref_)
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
      end #of operation activate_object_with_id

      def deactivate_object(oid)
        begin
          self.objref_.deactivate_object(oid.to_s.to_java_bytes)
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
      end #of operation deactivate_object

      def create_reference(intf)
        begin
          CORBA::Object._wrap_native(self.objref_.create_reference(intf.to_s))
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
      end #of operation create_reference

      def create_reference_with_id(oid, intf)
        begin
          CORBA::Object._wrap_native(self.objref_.create_reference_with_id(oid.to_s.to_java_bytes, intf.to_s))
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
      end #of operation create_reference_with_id

      def servant_to_id(p_servant)
        begin
          String.from_java_bytes(self.objref_.servant_to_id(p_servant.srvref_))
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
      end #of operation servant_to_id

      def servant_to_reference(p_servant)
        begin
          CORBA::Object._wrap_native(self.objref_.servant_to_reference(p_servant.srvref_))
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
      end #of operation servant_to_reference

      def reference_to_servant(reference)
        begin
          self.objref_.reference_to_servant(reference.objref_).rbServant
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
      end #of operation reference_to_servant

      def reference_to_id(reference)
        begin
          String.from_java_bytes(self.objref_.reference_to_id(reference.objref_))
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
      end #of operation reference_to_id

      def id_to_servant(oid)
        begin
          self.objref_.id_to_servant(oid.to_s.to_java_bytes).rbServant
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
      end #of operation id_to_servant

      def id_to_reference(oid)
        begin
          CORBA::Object._wrap_native(self.objref_.id_to_reference(oid.to_s.to_java_bytes))
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
      end #of operation id_to_reference

      def create_POA(adapter_name, a_POAManager, policies)
        raise CORBA::BAD_PARAM.new('expected POAManager', 0, CORBA::COMPLETED_NO) unless a_POAManager.is_a?(PortableServer::POAManager)
        CORBA::PolicyList._tc.validate(policies) unless policies.nil? || policies.empty?
        jpolicies = CORBA::Native::Reflect::Array.newInstance(CORBA::Native::Policy.java_class, policies.nil? ? 0 : policies.size)
        policies.each_with_index {|p,i| jpolicies[i] = p.objref_ } unless policies.nil?
        begin
          PortableServer::POA._narrow(CORBA::Object._wrap_native(self.objref_.create_POA(adapter_name, a_POAManager.objref_, jpolicies)))
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
      end #of operation create_POA

      def find_POA(adapter_name, activate_it)
        begin
          PortableServer::POA._narrow(CORBA::Object._wrap_native(self.objref_.find_POA(adapter_name, activate_it)))
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
      end #of operation find_POA
    end # POA

    module POAManager
      def activate()
        begin
          self.objref_.activate()
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
      end # activate

      def hold_requests(wait_for_completion)
        begin
          self.objref_.hold_requests(wait_for_completion)
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
      end # hold_requests

      def discard_requests(wait_for_completion)
        begin
          self.objref_.discard_requests(wait_for_completion)
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
      end # discard_requests

      def deactivate(etherealize_objects, wait_for_completion)
        begin
          self.objref_.deactivate(etherealize_objects, wait_for_completion)
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
      end # deactivate

      def get_state()
        begin
          self.objref_.get_state().value()
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
      end # get_state
    end # POAManager
  end
end
