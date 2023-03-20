#--------------------------------------------------------------------
# Union.rb - Definition of CORBA Union class as baseclass for all
#             IDL defined unions
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
      class Union
        def initialize
          @discriminator = nil
          @value = nil
        end

        def _is_at_default?
          @discriminator == :default
        end

        def _value_tc
          ix = self.class._tc.label_index(@discriminator)
          self.class._tc.member_type(ix)
        end

        def _disc
          @discriminator
        end

        def _disc=(val)
          m_cur = self.class._tc.label_member(@discriminator) unless @discriminator.nil?
          m_new = self.class._tc.label_member(val)
          raise ::CORBA::BAD_PARAM.new(
            "discriminator value (#{val.to_s}) outside current member for union #{self.class._tc.name}",
            1, ::CORBA::COMPLETED_NO) unless @discriminator.nil? || m_cur == m_new
          disc_ = @discriminator
          @discriminator = val
          disc_
        end

        def _value
          @value
        end
        protected
        def _set_value(ix, val)
          oldval = @value
          @discriminator = self.class._tc.member_label(ix)
          @value = val
          oldval
        end
      end
    end
  end
end
