#--------------------------------------------------------------------
# poa.rb - R2CORBA POA loader
#
# Author: Martin Corino
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the R2CORBA LICENSE which is
# included with this program.
#
# Copyright (c) Remedy IT Expertise BV
#--------------------------------------------------------------------

require 'corba.rb'
require "corba/#{defined?(JRUBY_VERSION) ? 'jbase' : 'cbase'}/poa.rb"
