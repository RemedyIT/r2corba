#--------------------------------------------------------------------
# IDL.rb - R2CORBA inline IDL support
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
    def CORBA.implement(idlfile, params={}, genbits = IDL::CLIENT_STUB, &block)
      IDL.implement(idlfile, params, genbits, &block)
    end
  end

end
