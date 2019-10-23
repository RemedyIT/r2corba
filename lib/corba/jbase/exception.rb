#--------------------------------------------------------------------
# exception.rb - Java/JacORB specific CORBA Exception definitions
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
      def self.native2r(jex)
        if ::NativeException === jex
          if jex.cause.is_a? Native::SystemException
            SystemException._raise(jex)
          elsif jex.cause.is_a? Native::UserException
            UserException._raise(jex)
          else
            raise CORBA::InternalError.new(jex)
          end
        else
          raise jex
        end
      end
    end

    class UserException
      def self._raise(jex)
        STDERR.puts "#{jex}\n#{jex.backtrace.join("\n")}" if $VERBOSE and (NativeException === jex)
        if (NativeException === jex and jex.cause.is_a?(Native::UnknownUserException)) or jex.is_a?(Native::UnknownUserException)
          java_ex = jex.is_a?(Native::UnknownUserException) ? jex : jex.cause
          ex = Any.from_java(java_ex.except)
          ex.set_backtrace(jex.backtrace) if NativeException === jex
          raise ex
        elsif (NativeException === jex and jex.cause.is_a?(Native::UserException)) or jex.is_a?(Native::UserException)
          java_ex = jex.is_a?(Native::UserException) ? jex : jex.cause
          exname = java_ex.class.name.split('::').last
          tcs = CORBA::TypeCode.typecodes_for_name(exname) || []
          extc = tcs.detect {|tc| tc.is_a?(TypeCode::Except) && tc.is_compatible?(java_ex)}
          if extc
            ex = extc.from_java(java_ex)
            ex.set_backtrace(jex.backtrace) if NativeException === jex
            raise ex
          end
        end
        raise CORBA::UNKNOWN.new("#{jex}", 0, CORBA::COMPLETED_MAYBE)
      end
    end

    class InternalError
      def initialize(jex)
        @ex_ = jex
        super(@ex_.message)
        self.set_backtrace(@ex_.backtrace)
      end
    end

    class SystemException
      def self._raise(jex)
        raise ArgumentError unless (NativeException === jex and jex.cause.is_a?(Native::SystemException)) or jex.is_a?(Native::SystemException)
        java_ex = jex.is_a?(Native::SystemException) ? jex : jex.cause
        exname = java_ex.class.name.split('::').last
        exklass = CORBA.const_get(exname.to_sym)
        unless exklass
          # define hitherto unknown CORBA system exception
          CORBA.define_system_exception(exname)
          CORBA.const_get(exname.to_sym) || InternalError
        end
        raise exklass.new(jex)
      end
      def initialize(*args)
        if (NativeException === args.first and args.first.cause.is_a? Native::SystemException) or args.first.is_a?(Native::SystemException)
          java_ex = args.first.is_a?(Native::SystemException) ? args.first : args.first.cause
          super(java_ex.getMessage)
          @minor = java_ex.minor
          @completed = java_ex.completed.value
          self.set_backtrace(args.first.backtrace) if NativeException === args.first
        else
          super(args.shift.to_s)
          @minor, @completed = (args + [0,0][args.size..2])
        end
      end
    end
  end # CORBA
end # R2CORBA

# extend Ruby wrapper for Native java exceptions
class NativeException
  alias method_missing_corba_backup method_missing
  def method_missing(method, *args)
    if self.cause.is_a?(R2CORBA::CORBA::Native::SystemException) and args.empty?
        return self.cause.minor if method == :minor
        return self.cause.completed.value if method == :completed
        return self.cause.getMessage if method == :reason
    elsif self.cause.is_a? R2CORBA::CORBA::Native::UserException
        return self.cause.send(method, *args)
    end
    self.method_missing_corba_backup
  end
end
