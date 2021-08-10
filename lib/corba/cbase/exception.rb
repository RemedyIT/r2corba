#--------------------------------------------------------------------
# exception.rb - C++/TAO ORB specific CORBA Exception definitions
#
# Author: Martin Corino
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the R2CORBA LICENSE which is
# included with this program.
#
# Copyright (c) Remedy IT Expertise BV
#--------------------------------------------------------------------

# import all java CORBA exceptions into the R2CORBA::CORBA namespace
module R2CORBA
  module CORBA

    class Exception
      def self.native2r(nex)
        raise nex
      end
    end

    class InternalError
      def initialize(ex_or_str)
        if ex_or_str.is_a?(String)
          super(ex_or_str)
        else
          @ex_ = ex_or_str
          super(@ex_.message)
          self.set_backtrace(@ex_.backtrace)
        end
      end
    end

    class SystemException
      def SystemException._raise(id, reason, minor, completed)
        name = id.to_s.split(':')[1]
        exklass = name.split('/').last
        exklass = CORBA.const_defined?(exklass) ? CORBA.const_get(exklass) : nil
        if exklass.nil? || !(CORBA::SystemException > exklass)
          Kernel.raise InternalError,
                'Unknown SystemException raised: ' +
                id.to_s + ' [' + reason.to_s + ']'
        else
          Kernel.raise exklass.new(reason, minor, completed)
        end
      end

      def initialize(reason = '', minor = 0, completed = nil)
        super(reason)
        @minor = minor
        @completed = completed
        @ids = [self.class::Id]
      end
      attr_accessor :ids
      def _ids; @ids; end

      def _interface_repository_id
        self.class::Id
      end
    end

  end # CORBA
end # R2CORBA

# NativeException mockup for JRuby compatibility
NativeException = Exception
