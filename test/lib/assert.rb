#--------------------------------------------------------------------
# assert.rb - simple assertion testers
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

module TestUtil

  module Assertions
    def assert(message = 'Assertion failed', boolean = nil, &block)
      raise ArgumentError, '#assert requires a boolean or a block' unless !boolean.nil? or block_given?
      boolean = yield if boolean.nil?
      raise message unless boolean
    end

    def assert_not(message = 'Assertion failed', boolean = nil, &block)
      raise ArgumentError, '#assert_not requires a boolean or a block' unless !boolean.nil? or block_given?
      boolean = yield if boolean.nil?
      raise message unless !boolean
    end

    def assert_except(message = 'Assertion failed', exception = Exception, &block)
      raise ArgumentError, '#assert_except requires a block' unless block_given?
      begin
        yield
      rescue exception => ex_
        return # this should happen
      rescue
        raise "caught #{$!}\n#{message}"
      end
      raise message
    end
  end

end

