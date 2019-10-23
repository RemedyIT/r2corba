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

[ 'version',
  'const',
  'IDL',
  'exception',
  'Stub',
  'Struct',
  'Union',
  'Typecode',
  'Values',
  'Any',
  'Object',
  'ORB',
  'Request'
].each { |f| require "corba/common/#{f}.rb" }
