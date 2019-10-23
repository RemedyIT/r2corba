#--------------------------------------------------------------------
# require.rb - C++/TAO R2CORBA loader
#
# Author: Martin Corino
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the R2CORBA LICENSE which is
# included with this program.
#
# Copyright (c) Remedy IT Expertise BV
#--------------------------------------------------------------------

begin
  _ext_dir = File.expand_path(File.join(File.dirname(__FILE__), '../../../ext'))
  $: << _ext_dir unless $:.include?(_ext_dir) || !File.directory?(_ext_dir)
  require RUBY_PLATFORM =~ /mingw32/ ? "libr2taow" : "libr2tao"
rescue LoadError
  $stderr.puts $!.to_s if $VERBOSE
  raise
end

[ 'exception',
  'ORB',
  'Request',
  'Typecode',
  'Stub',
  'Values',
  'Streams'
].each { |f| require "corba/cbase/#{f}.rb" }
