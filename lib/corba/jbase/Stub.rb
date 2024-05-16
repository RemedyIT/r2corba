#--------------------------------------------------------------------
# Stub.rb - Java/JacORB CORBA Stub definitions
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
    module Stub
      include R2CORBA::CORBA::Portable::Stub

      protected

      ##
      # Handle IDL generated invocation
      def _invoke(operation, param = {})
        raise ArgumentError, 'expected Hash' unless ::Hash === param

        req = self._request(operation)
        req.arguments = param[:arg_list] if param.has_key?(:arg_list)
        req.exceptions = param[:exc_list] if param.has_key?(:exc_list)
        if param.has_key?(:result_type)
          req.set_return_type(param[:result_type])
          return req.invoke
        else
          req.send_oneway
          return nil
        end
      end
    end # Stub
  end # CORBA
end # R2CORBA
