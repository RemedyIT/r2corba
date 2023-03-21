#--------------------------------------------------------------------
# Stub.rb - basic CORBA Stub definitions
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
    module Portable
      module Stub
        def self.included(klass)
          klass.class_eval do

            def init
              init_corba_portable_stub
            end

            def self.create_stub(obj)
              raise CORBA::INV_OBJREF.new unless obj.is_a?(CORBA::Object)

              obj.extend(self) unless obj.is_a?(self)
              obj.init
              return obj
            end

          end
        end

        Id  = 'IDL:omg.org/CORBA/Object:1.0'.freeze
        Ids = [ Id ].freeze

        protected
        def init_corba_portable_stub
          @ids ||= ['IDL:omg.org/CORBA/Object:1.0']
        end

        def _ids; @ids; end

        def _append_ids(*ids)
          @ids.concat(ids) unless ids.nil?
        end

        public
        def _narrow!(klass)
          raise CORBA::OBJECT_NOT_EXIST.new('Nil object narrowed!') if self._is_nil?
          raise(TypeError, "invalid object narrowed: #{self.class}") unless self.is_a?(CORBA::Stub) && self._is_a?(klass::Id)

          self.extend klass
          _append_ids(*klass::Ids)
          return self
        end

        def _unchecked_narrow!(klass)
          raise CORBA::OBJECT_NOT_EXIST.new('Nil object narrowed!') if self._is_nil?
          raise(TypeError, "invalid object narrowed: #{self.class}") unless self.is_a?(CORBA::Stub)

          self.extend klass
          _append_ids(*klass::Ids)
          return self
        end

        def _is_a?(str)
          _ids.include?(str) || super(str)
        end

        def inspect
          s = ''
          s << self.class.name.to_s << "\n" <<
               "type_id: \n" <<
               '  ' << @ids.join("\n  ") << "\n"
        end
      end # Stub
    end # Portable
  end # CORBA
end # R2CORBA
