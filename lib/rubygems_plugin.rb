#--------------------------------------------------------------------
# rubygems_plugin.rb - Devkit faker
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

# this is simply a fake Windows Ruby Devkit loader to satisfy the stupid
# pre-install hook provided with RubyInstaller Ruby installations

module Kernel

  alias :r2corba_devkit_load :load

  def load(file, wrap=false)
    return true if file == 'devkit'
    r2corba_devkit_load(file, wrap)
  end

end