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

require 'corba/common/require'
require "corba/#{defined?(JRUBY_VERSION) ? 'jbase' : 'cbase'}/require"
require 'corba/idl/require'
require "corba/#{defined?(JRUBY_VERSION) ? 'jbase' : 'cbase'}/post_require"
