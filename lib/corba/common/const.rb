#--------------------------------------------------------------------
# const.rb - Common constants
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
    BIG_ENDIAN, LTL_ENDIAN = 0, 1
    ENDIAN = ('Ruby'.unpack('i')[0] == 2036495698) ? LTL_ENDIAN : BIG_ENDIAN

    ARG_IN = 1
    ARG_OUT = 2
    ARG_INOUT = 3
  end
end
