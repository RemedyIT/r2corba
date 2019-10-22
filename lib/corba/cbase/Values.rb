#--------------------------------------------------------------------
# Values.rb - C++/Value CORBA Value and ValueBox support
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
    module AbstractValueBase
      def self.included(mod)
        mod.module_eval do
          def self.===(obj)
            obj.kind_of?(self)
          end
        end
      end
    end
    module ValueBase
      def self.included(mod)
        mod.module_eval do
          include CORBA::AbstractValueBase unless self.include?(CORBA::AbstractValueBase)

          alias :org_kind_of? :kind_of?
          def kind_of?(mod)
            if mod < CORBA::AbstractValueBase && mod.const_defined?(:Intf)
              org_kind_of?(mod::Intf)
              #super(mod::Intf)   ## problematic with Ruby 1.9.2 (known bug)
            else
              org_kind_of?(mod)
              #super              ## problematic with Ruby 1.9.2 (known bug)
            end
          end
          alias :is_a? :kind_of?
        end
      end

      def _marshal_with(os, &block)
        self.pre_marshal(os)
        self.instance_eval(&block)
        self.post_marshal(os)
      end

      def _unmarshal_with(is, &block)
        self.pre_unmarshal(is)
        self.instance_eval(&block)
        self.post_unmarshal(is)
      end
    end # ValueBase

    module Portable
      class ValueFactoryBase

        def self.inherited(value_factory_base)
          # value_factory_base is the <valuetype>Factory base class
          # generated from IDL
          value_factory_base.module_eval do
            def self.value_id
              self::VALUE_ID
            end
          end
        end

        def self._check_factory
          f = self._lookup_value_factory(self.value_id)
          self._register_value_factory(self.value_id(), self.new) if f.nil?
        end

      end # ValueFactoryBase

      module CustomValueBase
        def self.included(mod)
          mod.module_eval do
            include CORBA::ValueBase unless self.include?(CORBA::ValueBase)

            def do_marshal(os)
              self.pre_marshal(os)
              self.marshal(os)
              self.post_marshal(os)
            end

            def do_unmarshal(is)
              self.pre_unmarshal(is)
              self.unmarshal(is)
              self.post_unmarshal(is)
            end
          end
        end
      end # CustomValueBase

      module BoxedValueBase
        class FactoryBase < CORBA::Portable::ValueFactoryBase
          ## generic factory base
        end
        def self.included(mod)
          mod.module_eval do
            include CORBA::ValueBase unless self.include?(CORBA::ValueBase)

            def marshal(os)
              os.write_member(self.class._tc.content_type.resolved_tc, self.value)
            end

            def unmarshal(is)
              self.value = is.read_member(self.class._tc.content_type.resolved_tc)
            end

            self.const_set(:Factory, Class.new(CORBA::Portable::BoxedValueBase::FactoryBase))
            self::Factory.class_eval(%Q{
              def self.value_id
                #{self.name}::TRUNCATABLE_IDS.first
              end

              def _create_default
                #{self.name}.new
              end
            })
          end
        end
      end

    end # Portable
  end # CORBA
end # R2CORBA
