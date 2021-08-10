#--------------------------------------------------------------------
# Request.rb - Java/JacORB CORBA Request definitions
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

    module Request
      @@wrapper_klass = Class.new do
        include CORBA::Request
        def initialize(nreq, target)
          @req_ = nreq
          @target = target
        end
        attr_reader :req_
        attr_reader :target
      end

      def self._wrap_native(nreq, target)
        raise ArgumentError, 'Expected org.omg.CORBA.Request' unless nreq.nil? || nreq.is_a?(Native::Request)
        nreq.nil?() ? nreq : @@wrapper_klass.new(nreq, target)
      end

      def operation

          self.req_.operation()
        rescue ::NativeException
          CORBA::Exception.native2r($!)

      end

      def add_in_arg(tc, val, nm='')
        begin
          self.req_.arguments.add_value(nm, Any.to_any(val, tc).to_java(self.req_.target._orb), CORBA::ARG_IN)
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
        self.req_.arguments.count
      end

      def add_out_arg(tc, nm='')
        begin
          self.req_.arguments.add_value(nm, Any.to_any(nil, tc).to_java(self.req_.target._orb), CORBA::ARG_OUT)
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
        self.req_.arguments.count
      end

      def add_inout_arg(tc, val, nm='')
        begin
          self.req_.arguments.add_value(nm, Any.to_any(val, tc).to_java(self.req_.target._orb), CORBA::ARG_INOUT)
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
        self.req_.arguments.count
      end

      def arguments

          nvl = self.req_.arguments
          (0..nvl.count).to_a.collect do |i|
            nv = nvl.item(i)
            [nv.name,
             nv.flags,
             CORBA::TypeCode.from_java(nv.value.type),
             Any.from_java(nv.value, self.req_.target._orb)]
          end
        rescue
          CORBA::Exception.native2r($!)

      end

      def arguments=(*args)
        if args.size == 1
          raise ArgumentError, 'invalid argument list' unless ::Array === args.first && args.first.all? {|a| ::Array === a }
          args = args.first
        else
          raise ArgumentError, 'invalid argument list' unless args.all? {|a| ::Array === a }
        end
        # clear current arguments
        begin
          nvl = self.req_.arguments
          nvl.remove(0) while nvl.count > 0
        rescue
          CORBA::Exception.native2r($!)
        end
        # add new arguments
        args.each do |nm, flag, tc, val|
          case flag
          when CORBA::ARG_IN
            self.add_in_arg(tc, val, nm)
          when CORBA::ARG_OUT
            self.add_out_arg(tc, nm)
          when CORBA::ARG_INOUT
            self.add_inout_arg(tc, val, nm)
          end
        end
      end

      def exceptions

          exl = self.req_.exceptions
          (0..exl.count).to_a.collect do |i|
            CORBA::TypeCode.from_java(exl.item(i))
          end
        rescue
          CORBA::Exception.native2r($!)

      end

      def exceptions=(exl)

          # clear current exceptions
          jexl = self.req_.exceptions
          jexl.remove(0) while jexl.count > 0
          # add new exceptions
          exl.each do |extc|
            jexl.add(extc.tc_)
          end
        rescue
          CORBA::Exception.native2r($!)

      end

      def set_return_type(tc)
        @return_type = tc
        begin
          self.req_.set_return_type(tc.tc_)
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
      end

      def return_value

          Any.from_java(self.req_.return_value, self.req_.target._orb, @return_type)
        rescue ::NativeException
          CORBA::Exception.native2r($!)

      end

      def invoke
        begin
          self.req_.invoke
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
        jex = self.req_.env().exception()
        unless jex.nil?
          STDERR.puts "#{jex}\n#{jex.backtrace.join("\n")}" if $VERBOSE
          if jex.is_a?(CORBA::Native::SystemException)
            CORBA::SystemException._raise(jex)
          elsif jex.is_a?(CORBA::Native::UnknownUserException)
            CORBA::UserException._raise(jex)
          else
            raise CORBA::UNKNOWN.new(jex.getMessage(), 0, CORBA::COMPLETED_MAYBE)
          end
        end
        self.result
      end

      def send_oneway

          self.req_.send_oneway
        rescue ::NativeException
          CORBA::Exception.native2r($!)

      end

      def send_deferred

          self.req_.send_deferred
        rescue ::NativeException
          CORBA::Exception.native2r($!)

      end

      def poll_response

          self.req_.poll_response
        rescue ::NativeException
          CORBA::Exception.native2r($!)

      end

      def get_response

          self.req_.get_response
        rescue ::NativeException
          CORBA::Exception.native2r($!)

      end

      protected

      def result
        rc = self.req_.return_value.type.kind.value == CORBA::TK_VOID ? [] : [self.return_value]
        begin
          nvl = self.req_.arguments
          nvl.count.times do |i|
            nv = nvl.item(i)
            rc << Any.from_java(nv.value, self.req_.target._orb) unless nv.flags == CORBA::ARG_IN
          end
        rescue
          CORBA::Exception.native2r($!)
        end
        if rc.size < 2
          return rc.shift
        else
          return *rc
        end
      end

    end

  end # CORBA
end # R2CORBA
