#--------------------------------------------------------------------
# Values.rb - Definition of CORBA Valuetype base classes for all
#             IDL defined valuetypes
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
    module AbstractBase
      Id = 'IDL:omg.org/CORBA/AbstractBase:1.0'.freeze
      Ids = [Id].freeze
    end

    module AbstractValueBase
    end

    module ValueBase
      def do_marshal(os)
        self.marshal(os)
      end

      def do_unmarshal(is)
        self.unmarshal(is)
      end
    end

    class ValueFactory
    end

    module Portable
      module BoxedValueBase
      end

      module CustomValueBase
        def marshal(os)
          raise CORBA::NO_IMPLEMENT
        end

        def unmarshal(is)
          raise CORBA::NO_IMPLEMENT
        end
      end

      class ValueFactoryBase < CORBA::ValueFactory
        def _create_default
          raise CORBA::NO_IMPLEMENT
        end

        def value_id
          self.class.value_id # derived classes define this
        end

        def self.register_factory(orb)
          orb.register_value_factory(self.value_id, self.new)
        end

        def self.get_factory(orb)
          f = orb.lookup_value_factory(self.value_id)
          self.register_factory(orb) if f.nil?
          f || orb.lookup_value_factory(self.value_id)
        end

        def self.unregister_factory(orb)
          orb.unregister_value_factory(self.value_id)
        end
      end
    end # Portable

    VM_NONE = 0
    VM_CUSTOM = 1
    VM_ABSTRACT = 2
    VM_TRUNCATABLE = 3

    VT_MODIFIERS = {
      none: VM_NONE,
      abstract: VM_ABSTRACT,
      truncatable: VM_TRUNCATABLE,
      custom: VM_CUSTOM
    }.freeze

    PRIVATE_MEMBER = 0
    PUBLIC_MEMBER = 1
  end # CORBA
end # R2CORBA
