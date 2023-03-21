#--------------------------------------------------------------------
# require.rb - R2CORBA loader
#
# Author: Martin Corino
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the R2CORBA LICENSE which is
# included with this program.
#
# Copyright (c) Remedy IT Expertise BV
#--------------------------------------------------------------------

require 'corba/idl/IDL'
require 'corba/idl/r2c_orb'

## fake Ruby into believing 'orb.rb' has already been loaded
## which is what the IDL compiler will generate for
## '#include "orb.idl"'
$" << 'orb.rb'
