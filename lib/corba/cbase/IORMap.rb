#--------------------------------------------------------------------
# iormap.rb - C++/TAO IORMap definitions
#
# Author: Martin Corino
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the R2CORBA LICENSE which is
# included with this program.
#
# Copyright (c) Remedy IT Expertise BV
#--------------------------------------------------------------------
require 'corba/idl/IORTableC'

module R2CORBA
  class IORMap
    def initialize(orb)
      obj = orb.resolve_initial_references('IORTable')
      @iortbl = IORTable::Table._narrow(obj)
    end

    def map_ior(object_key, ior)
      @iortbl.rebind(object_key, ior)
    end

    def unmap_ior(object_key)
      begin
        @iortbl.unbind(object_key)
      rescue IORTable::NotFound
      end
    end
  end
end
