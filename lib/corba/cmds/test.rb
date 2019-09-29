#--------------------------------------------------------------------
# test.rb - R2CORBA unit tester command
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

require File.join(File.dirname(__FILE__), '..', '..', '..', 'test', 'test_runner.rb')

module R2CORBA
  module Commands
    class Test
      def description
        'Run R2CORBA regression tests.'
      end

      def run
        TestFinder.run ARGV
      end
    end

    self.register('test', Test.new)
  end
end
