#--------------------------------------------------------------------
# Request.rb - C++/TAO CORBA Request definitions
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

      def add_in_arg(tc, val, nm='')
        self._arguments << [nm, CORBA::ARG_IN, tc, val]
        self._arguments.size
      end

      def add_out_arg(tc, nm='')
        self._arguments << [nm, CORBA::ARG_OUT, tc]
        self._arguments.size
      end

      def add_inout_arg(tc, val, nm='')
        self._arguments << [nm, CORBA::ARG_INOUT, tc, val]
        self._arguments.size
      end

      def arguments
        self._arguments
      end

      def arguments=(*args)
        if args.size == 1
          raise ArgumentError, 'invalid argument list' unless ::Array === args.first && args.first.all? {|a| ::Array === a }
          args = args.first
        else
          raise ArgumentError, 'invalid argument list' unless args.all? {|a| ::Array === a }
        end
        # clear current arguments
        self._arguments.clear
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
        self._exceptions
      end

      def exceptions=(exl)
        self._exceptions.clear
        begin
          self._exceptions.concat(exl)
        rescue
          raise CORBA::BAD_PARAM.new(0, CORBA::COMPLETED_NO)
        end
      end

      def set_return_type(tc)
        @_rettc = tc
      end

      def return_value
        return nil if @_rettc.nil? || @_rettc.kind == CORBA::TK_VOID || @_rettc.kind == CORBA::TK_NULL
        self._return_value(@_rettc)
      end

      def invoke
        self._invoke({
          :arg_list => self._arguments,
          :result_type => @_rettc,
          :exc_list => self._exceptions
          })
      end

      def send_oneway
        self._send_oneway(self._arguments)
      end

      def send_deferred
        self._send_deferred({
          :arg_list => self._arguments,
          :result_type => @_rettc,
          :exc_list => self._exceptions
          })
      end

      def poll_response
        begin
          ret = self._poll_response
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
        @_args = self._get_arguments(@_args || []) if ret
        ret
      end

      def get_response
        begin
          ret = self._get_response
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
        @_args = self._get_arguments(@_args || [])
        ret
      end

      protected

      def _arguments
        @_args ||= []
      end

      def _exceptions
        @_excl ||= []
      end

    end

  end # CORBA
end # R2CORBA
