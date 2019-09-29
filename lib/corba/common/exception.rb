#--------------------------------------------------------------------
# exception.rb - Common CORBA Exception definitions
#
# Author: Martin Corino
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the R2CORBA LICENSE which is
# included with this program.
#
# Copyright (c) Remedy IT Expertise BV
# Chamber of commerce Rotterdam nr.276339, The Netherlands
#--------------------------------------------------------------------

module R2CORBA
  module CORBA
    COMPLETED_YES, COMPLETED_NO, COMPLETED_MAYBE = (0..2).to_a
    COMPLETED_TXT = ["YES", "NO", "MAYBE"].freeze
    class Exception < StandardError
    end

    class UserException < CORBA::Exception
    end

    class InternalError < StandardError
    end

    class SystemException < CORBA::Exception
      private_class_method :new
      attr_accessor :minor, :completed
      def reason
        self.message
      end
      def to_s
        "CORBA::#{self.class::Name}(#{super}) [minor=#{@minor};completed=#{COMPLETED_TXT[@completed.to_i]}]"
      end
    end

    def CORBA.define_system_exception(name)
      self.module_eval %Q^
        class #{name} < SystemException
          public_class_method :new
          def initialize(*args)
            super(*args)
          end
          Id = "IDL:omg.org/CORBA/#{name}:1.0"
          Name = "#{name}"
          def self._tc
            @@tc_ ||= TypeCode::SysExcept.new(self::Id, self::Name)
          end
        end
      ^
    end

    # SystemException derivatives
    [
      'UNKNOWN', 'BAD_PARAM', 'NO_MEMORY', 'IMP_LIMIT', 'COMM_FAILURE', 'INV_OBJREF',
      'OBJECT_NOT_EXIST', 'NO_PERMISSION', 'INTERNAL', 'MARSHAL', 'INITIALIZE', 'NO_IMPLEMENT',
      'BAD_TYPECODE', 'BAD_OPERATION', 'NO_RESOURCES', 'NO_RESPONSE', 'PERSIST_STORE',
      'BAD_INV_ORDER', 'TRANSIENT', 'FREE_MEM', 'INV_IDENT', 'INV_FLAG', 'INTF_REPOS', 'BAD_CONTEXT',
      'OBJ_ADAPTER', 'DATA_CONVERSION', 'INV_POLICY', 'REBIND', 'TIMEOUT',
      'TRANSACTION_UNAVAILABLE', 'TRANSACTION_MODE', 'TRANSACTION_REQUIRED', 'TRANSACTION_ROLLEDBACK',
      'INVALID_TRANSACTION', 'CODESET_INCOMPATIBLE', 'BAD_QOS', 'INVALID_ACTIVITY',
      'ACTIVITY_COMPLETED', 'ACTIVITY_REQUIRED', 'THREAD_CANCELLED'
    ].each do |s|
      define_system_exception(s)
    end
  end # CORBA
end # R2CORBA
