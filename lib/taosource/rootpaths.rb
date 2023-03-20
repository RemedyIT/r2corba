#--------------------------------------------------------------------
# rootpaths.rb - Source paths
#
# Author: Martin Corino
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the R2CORBA LICENSE which is
# included with this program.
#
# Copyright (c) Remedy IT Expertise BV
#--------------------------------------------------------------------

module TAOGem

  ENV['ACE_ROOT'] = File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'src', 'ACE_wrappers'))
  ENV['TAO_ROOT'] = File.join(ENV['ACE_ROOT'], 'TAO')
  ENV['MPC_ROOT'] = File.join(ENV['ACE_ROOT'], 'MPC')

end
