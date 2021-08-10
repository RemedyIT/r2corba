#--------------------------------------------------------------------
# iormap.rb - Java/JacORB IORMap definitions
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
  class IORMap
    def initialize(orb)
      @orb = orb
    end

    def map_ior(object_key, ior)

        @orb.orb_.addObjectKey(object_key, ior)
      rescue ::NativeException
        CORBA::Exception.native2r($!)

    end

    def unmap_ior(object_key)

        @orb.orb_.addObjectKey(object_key, nil)
      rescue ::NativeException
        CORBA::Exception.native2r($!)

    end
  end
end
