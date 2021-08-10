#--------------------------------------------------------------------
# Servant.rb - R2TAO CORBA Servant support
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

    class Servant

      module Intf
        Id  = 'IDL:omg.org/CORBA/Object:1.0'.freeze
        Ids = [ Id ].freeze
        Operations = {}.freeze
      end

      def Servant.include(*modules)
        modules.reverse_each { |mod|
          if mod.respond_to?(:superclass) && mod.superclass == R2CORBA::PortableServer::Servant
            include_srv(mod)
          elsif mod < CORBA::ValueBase && mod.const_defined?(:Intf)
            include_valuetype(mod)
          else
            super(mod)
          end
        }
      end

      def get_operation_signature(opsym)
        self.class::Operations[opsym]
      end

    private
      def Servant.include_interface(intf)
        self::Intf.module_eval(%Q{ include ::#{intf.name} })
        self::Intf::Operations.merge!(intf::Operations)
        self::Intf::Ids.concat(intf::Ids)
      end

      def Servant.include_srv(srv)
        if !self.const_defined?('Id')
          if self.superclass == R2CORBA::PortableServer::Servant || !self.constants.include?('Id')
            self.const_set('Id', srv::Id.dup.freeze)
          else
            self.const_set('Id', self::Id.dup.freeze)
          end
        end
        if !self.const_defined?('Ids')
          if self.superclass == R2CORBA::PortableServer::Servant || !self.constants.include?('Ids')
            self.const_set('Ids', [])
          else
            self.const_set('Ids', self::Ids.dup)
          end
        end
        if !self.const_defined?('Operations')
          if self.superclass == R2CORBA::PortableServer::Servant || !self.constants.include?('Operations')
            self.const_set('Operations', {})
          else
            self.const_set('Operations', self::Operations.dup)
          end
        end
        self.module_eval(%Q{ include ::#{srv.name}::Intf })
        self::Operations.merge!(srv::Operations)
        self::Ids.concat(srv::Ids).uniq!
      end
    end

    def Servant.include_valuetype(vt)
      self.module_eval do
        if vt < CORBA::Portable::CustomValueBase
          include CORBA::Portable::CustomValueBase unless self.include?(CORBA::Portable::CustomValueBase)
        else
          include CORBA::ValueBase unless self.include?(CORBA::ValueBase)
        end
        self.const_set(:TRUNCATABLE_IDS, vt::TRUNCATABLE_IDS)
        self.const_set(:VT_TC, vt._tc)
        # @@tc_vt_ = vt._tc
        def self._tc
          # @@tc_vt_
          self.const_get(:VT_TC)
        end
        include vt::Intf
      end
    end

    class DynamicImplementation < Servant
      def invoke(request)
        if self.class.const_defined?('OPTABLE') && self.class::OPTABLE.has_key?(request.operation)
          request.describe(self.class::OPTABLE[request.operation])
          return self.__send__(request.operation, *request.arguments) { request }
        else
          return self.__send__(request.operation) { request }
        end
      end
    end

  end

end
