#--------------------------------------------------------------------
# Values.rb - Java/JacORB CORBA Value and ValueBox support
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
          include CORBA::Native::Portable::StreamableValue unless self.include?(CORBA::Native::Portable::StreamableValue)
          # this defines the following methods to be implemented
          # String[] _truncatable_ids();
          # TypeCode _type();
          # void _read(org.omg.CORBA.portable.InputStream is);
          # void _write(org.omg.CORBA.portable.OutputStream os);
          include CORBA::AbstractValueBase unless self.include?(CORBA::AbstractValueBase)

          def _truncatable_ids
            self.class::TRUNCATABLE_IDS.to_java(:string)
          end

          def _type
            self.class._tc.tc_ # return Java TypeCode here
          end

          def _read(jis)
            do_unmarshal(CORBA::Portable::InputStream._wrap_native(jis))
          end

          def _write(jos)
            do_marshal(CORBA::Portable::OutputStream._wrap_native(jos))
          end

          def kind_of?(mod)
            if mod < CORBA::AbstractValueBase && mod.const_defined?(:Intf)
              super(mod::Intf)
            else
              super
            end
          end
          alias :is_a? :kind_of?
        end
      end

      def _marshal_with(os, &block)
        self.instance_eval(&block)
      end

      def _unmarshal_with(is, &block)
        self.instance_eval(&block)
      end
    end # ValueBase

    module Portable
      class ValueFactoryBase
        include CORBA::Native::Portable::ValueFactory
        ## defines: java.io.Serializable read_value(InputStream is)

        def self.inherited(value_factory_base)
          # value_factory_base is the <valuetype>Factory base class
          # generated from IDL
          value_factory_base.module_eval do
            def self.value_id
              self::VALUE_ID
            end

            # overload
            def read_value(jis)
              vt = self._create_default
              vt._read(jis)
              vt
            end
          end
        end
      end # ValueFactoryBase

      module CustomValueBase
        def self.included(mod)
          mod.module_eval do
            include CORBA::ValueBase unless self.include?(CORBA::ValueBase)

            def do_marshal(os)
              self.marshal(os)
            end

            def do_unmarshal(is)
              self.unmarshal(is)
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

            def _write(jos)
              CORBA::Portable::OutputStream._wrap_native(jos).write_member(
                self.class._tc.content_type.resolved_tc, self.value)
            end

            def _read(jis)
              self.value = CORBA::Portable::InputStream._wrap_native(jis).read_member(
                self.class._tc.content_type.resolved_tc)
            end

            self.const_set(:Factory, Class.new(CORBA::Portable::BoxedValueBase::FactoryBase))
            self::Factory.class_eval(%Q{
              @@_reg = false
              def self._check_factory(jorb)
                return if @@_reg
                self.get_factory(jorb)
                @@_reg = true
              end

              def self.value_id
                #{self.name}::TRUNCATABLE_IDS.first
              end

              def _create_default
                #{self.name}.new
              end
            })

            self.const_set(:Helper, Class.new)
            self::Helper.class_eval(%Q{
              include CORBA::Native::Portable::BoxedValueHelper unless self.include?(CORBA::Native::Portable::BoxedValueHelper)

              def get_id()
                #{self.name}::TRUNCATABLE_IDS.first
              end

              def read_value(jis)
                #{self.name}.new._read(jis)
              end

              def write_value(jos, value)
                value._write(jos)
              end
            })

            def self.boxedvalue_helper
              @@helper ||= Helper.new
            end
          end
        end
      end
    end # Portable
  end # CORBA
end # R2CORBA
