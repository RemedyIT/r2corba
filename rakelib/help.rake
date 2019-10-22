#--------------------------------------------------------------------
# help.rake - build file
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
  HELP = <<__HELP_TXT

R2CORBA Rake based build system
-------------------------------

This build system provides commands for building, testing and installing R2CORBA.
Building R2CORBA requires a configure step to initialize build settings and check
all prerequisites for building the various variants of R2CORBA.

commands:

rake [rake-options] configure [-- --help]|[-- <configure options>]    # Configure R2CORBA build settings
rake [rake-options] show             # Show current R2CORBA build settings
rake [rake-options] build            # Build R2CORBA
rake [rake-options] clean            # Remove any temporary products.
rake [rake-options] clobber          # Remove any generated file.
rake [rake-options] help             # Provide help description about R2CORBA build system
rake [rake-options] test             # Run R2CORBA tests
rake [rake-options] package          # Build all the packages
rake [rake-options] repackage        # Force a rebuild of the package files
rake [rake-options] clobber_package  # Remove package products
rake [rake-options] install [-- --help]|[-- <install options>] [NO_HARM=1]  # Install R2CORBA
rake [rake-options] uninstall [-- --help]|[-- <uninstall options>] [NO_HARM=1]  # Uninstall R2CORBA
rake [rake-options] gem              # Build R2CORBA gem

__HELP_TXT
end

namespace :r2corba do
  task :help do
    puts R2CORBA::HELP
  end
end

desc 'Provide help description about R2CORBA build system'
task :help => 'r2corba:help'
