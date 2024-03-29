#--------------------------------------------------------------------
# policies.rb - R2CORBA Policy support loader
#
# Author: Martin Corino
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the R2CORBA LICENSE which is
# included with this program.
#
# Copyright (c) Remedy IT Expertise BV
#--------------------------------------------------------------------

require 'corba'
require 'corba/poa'
require 'corba/idl/BiDirPolicyC'
require 'corba/idl/MessagingC'
require "corba/#{defined?(JRUBY_VERSION) ? 'jbase' : 'cbase'}/policies.rb"
