#--------------------------------------------------------------------
# poa.rb - C++/TAO R2CORBA POA loader
#
# Author: Martin Corino
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the R2CORBA LICENSE which is
# included with this program.
#
# Copyright (c) Remedy IT Expertise BV
#--------------------------------------------------------------------

require 'corba/common/Servant.rb'
require 'corba/idl/POAC.rb'
require 'corba/idl/IORTableC'

begin
  require 'librpoa'
rescue LoadError
  $stderr.puts $!.to_s if $VERBOSE
  raise
end
