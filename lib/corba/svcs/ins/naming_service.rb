#--------------------------------------------------------------------
# naming_service.rb - Implementation of Naming Service
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

require 'corba'
require 'corba/svcs/ins/cos_naming'

module R2CORBA
  module INS
    class Service
      # default options
      OPTIONS = {
        :iorfile => 'ins.ior',
        :debug => 0,
        :threads => 5,
        :orbprop => {},
        :port => 0
      }

      def initialize(options = {})
        @options = OPTIONS.merge(options)
        raise RuntimeError, 'nr. of threads must >= 1' if @options[:threads] < 1
      end

      def setup
        # process options
        #
        if defined?(JRUBY_VERSION)
          @options[:orbprop]['jacorb.poa.thread_pool_min'] = @options[:threads]
          @options[:orbprop]['jacorb.poa.thread_pool_max'] = @options[:threads]*4
          if @options[:debug] > 0
            @options[:orbprop]['jacorb.log.default.verbosity'] = case
            when @options[:debug] < 2
              1
            when (2...4) === @options[:debug]
              2
            when (5...7) === @options[:debug]
              3
            when @options[:debug] > 7
              4
            end
          end
          if @options[:port] > 0
            @options[:orbprop]['OAPort'] = @options[:port]
          end
        else
          if @options[:debug] > 0
            @options[:orbprop]['-ORBDebugLevel'] = @options[:debug]
          end
          if @options[:port] > 0
            @options[:orbprop]['-ORBListenEndpoints'] = "iiop://:#{@options[:port]}"
          end
        end

        # initialize ORB and POA.
        #
        @orb = CORBA.ORB_init('INS_ORB', @options[:orbprop])

        obj = @orb.resolve_initial_references('RootPOA')

        root_poa = PortableServer::POA._narrow(obj)

        poa_man = root_poa.the_POAManager

        poa_man.activate

        # create and activate root Naming context
        #
        @naming_srv = INS::NamingContext.new(@orb)

        naming_obj = @naming_srv._this()

        naming_ior = @orb.object_to_string(naming_obj)

        # simplify Corbaloc urls (corbaloc:iiop:[host][:port]/NamingService)
        #
        @orb.ior_map.map_ior('NamingService', naming_ior)

        # save INS IOR to file
        #
        open(@options[:iorfile], 'w') { |io|
          io.write naming_ior
        }
      end

      def run
        STDERR.puts "INS - starting service run" if @options[:verbose]
        if (defined?(JRUBY_VERSION) or !R2CORBA::TAO::RUBY_THREAD_SUPPORT)
          STDERR.puts "INS - running ORB" if @options[:verbose]
          @orb.run
        else
          STDERR.puts "INS - starting #{@options[:threads]} ORB threads" if @options[:verbose]
          @threads = []
          @options[:threads].times do
            @threads << Thread.new(@orb) { |orb| orb.run }
          end
          STDERR.puts "INS - joining ORB threads" if @options[:verbose]
          @threads.each { |t| t.join }
        end
        STDERR.puts "INS - service run ended" if @options[:verbose]
      end

      def shutdown
        STDERR.puts "INS - shutting down ORB" if @options[:verbose]
        @orb.shutdown if @orb
        STDERR.puts "INS - shutdown finished" if @options[:verbose]
      end
    end
  end
end
