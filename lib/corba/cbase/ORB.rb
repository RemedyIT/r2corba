#--------------------------------------------------------------------
# ORB.rb - C++/TAO CORBA ORB definitions
#
# Author: Martin Corino
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the R2CORBA LICENSE which is
# included with this program.
#
# Copyright (c) Remedy IT Expertise BV
#--------------------------------------------------------------------
require 'monitor'

module R2CORBA
  module CORBA

    module ORB

      class << self
        protected
        def _singleton_orb_init
          CORBA::Native::ORB.init
        end
      end

      @@_default_args = []
      unless R2CORBA::TAO::RUBY_THREAD_SUPPORT
        # to prevent problems with "green threads" model of Ruby <=1.8.x run TAO
        # without nested upcalls; preventing thread reuse and re-entrancy
        @@_default_args << '-ORBSvcConfDirective'
        @@_default_args << 'static Client_Strategy_Factory "-ORBClientConnectionHandler MT_NOUPCALL"'
      end

        ## init() or init(arg1, arg2, arg3[, ...]) or init(orb_id, prop = {}) or init(argv, orb_id, prop={}) or init(argv, prop={})
      def self.init(*args)
        n_orb = if args.empty? && @@_default_args.empty?
          _singleton_orb_init
        else
          argv = []
          orb_id = nil
          prop = nil
          a1, a2, a3 = args
          if Array === a1
            raise ArgumentError, "Incorrect nr. of arguments; #{args.size}" if args.size > 3
            argv = a1
            orb_id = (Hash === a2 ? nil : a2)
            prop = (Hash === a2 ? a2 : a3)
          elsif args.size == 1 || Hash === a2
            raise ArgumentError, "Incorrect nr. of arguments; #{args.size}" if args.size > 2
            orb_id = a1
            prop = a2
          else
            argv = args
          end
          raise ArgumentError, "Invalid argument #{prop.class}; expected Hash" unless prop.nil? || Hash === prop
          unless prop.nil?()
            prop.inject(argv) {|a, (k, v)| a << k; a << v; a}
          end
          @@cached_orb = CORBA::Native::ORB.init(argv.collect {|a| a.to_s }.concat(@@_default_args), orb_id.nil?() ? nil : orb_id.to_s)
        end
        unless n_orb.nil?() || @@vf_queue.empty?()
          @@vf_queue.process_all { |vfklass| vfklass._check_factory }
        end
        @@wrapper_klass.new(n_orb)
      end

=begin
// Thread related operations
=end

      # ret [boolean, <time left>] if !timeout.nil? else boolean
      def work_pending(timeout = nil)
        begin
          self.orb_.work_pending(timeout)
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
      end

      # ret <time left> if !timeout.nil? else void
      def perform_work(timeout = nil)
        begin
          self.orb_.perform_work(timeout)
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
      end

      # safe to run in thread; even in pre-1.9 MRI Ruby
      # ret <time left> if !timeout.nil? else void
      def run(timeout = nil)
        if R2CORBA::TAO::RUBY_THREAD_SUPPORT
          begin
            self.orb_.run(timeout)
          rescue ::NativeException
            CORBA::Exception.native2r($!)
          end
        else
          @running ||= true
          raise CORBA::BAD_INV_ORDER.new('ORB has been shutdown', 0, CORBA::COMPLETED_NO) if @shutdown
          while (timeout.nil? or timeout > 0) and !@shutdown
            to = timeout || 0.05
            f, to = self.work_pending(to)
            timeout = to unless timeout.nil?
            if f and !@shutdown and (timeout.nil? or timeout > 0)
              to = timeout || 0.05
              to = self.perform_work(to)
              timeout = to unless timeout.nil?
            end
            Thread.pass unless @shutdown
          end
        end
      end

      unless R2CORBA::TAO::RUBY_THREAD_SUPPORT
        # starts blocking ORB event loop in MRI Ruby 1.8, i.e. no thread support
        # ret <time left> if !timeout.nil? else void
        def run_blocked(timeout = nil)
          begin
            self.orb_.run(timeout)
          rescue ::NativeException
            CORBA::Exception.native2r($!)
          end
        end
      end

      # boolean wait_for_completion
      # ret void
      def shutdown(wait_for_completion = false)
        if R2CORBA::TAO::RUBY_THREAD_SUPPORT or !@running
          begin
            self.orb_.shutdown(wait_for_completion)
          rescue ::NativeException
            CORBA::Exception.native2r($!)
          end
        else
          @shutdown = true
        end
      end

      ## custom
      @@vf_queue = (Class.new(Monitor) do
        def initialize
          @q_ = []
          super
        end
        def push(vfklass)
          synchronize do
            @q_ << vfklass
          end
        end
        def process_all(&block)
          synchronize do
            @q_.each { |vf| block.call(vf) }
            @q_.clear
          end
        end
        def empty?()
          f = false
          synchronize do
            f = @q_.empty?
          end
          f
        end
      end).new

      def self._check_value_factory(vfklass)
        if @@cached_orb.nil?
          @@vf_queue.push(vfklass)
        else
          vfklass._check_factory
        end
      end

      # custom R2CORBA extension : IORMap

      def ior_map
        @iormap ||= R2CORBA::IORMap.new(self)
      end

    end # ORB

=begin
 Signal trapping
=end
   private
     @@sigreg = {}
     def CORBA.signal_numbers
      ([1, # HUP
        2, # INT
        3, # QUIT
        5, # TRAP
        6, # ABRT
        10, # USR1
        12, # USR2
        13, # SIGPIPE
        14, # ALRM
        15, # TERM
        17, # CHLD
        18, # CONT
        23, # URG
        30, # PWR
        31  # SYS
       ]) & Signal.list.values
     end

     def CORBA.handled_signals
       @@sigreg.clear
       sigs = self.signal_numbers.collect do |signum|
         sigcmd = Signal.trap(signum, 'DEFAULT')
         Signal.trap(signum, sigcmd)
         @@sigreg[signum] = sigcmd
         if sigcmd.respond_to?(:call) or ['IGNORE', 'SIG_IGN', 'EXIT'].include?(sigcmd.to_s)
           signum
         else
           nil
         end
       end.compact
       sigs
     end

     def CORBA.handle_signal(signum)
       if @@sigreg.has_key?(signum)
         if @@sigreg[signum].respond_to?(:call)
           if @@sigreg[signum].respond_to?(:parameters) && @@sigreg[signum].parameters.size > 0
             @@sigreg[signum].call(signum)
           else
             @@sigreg[signum].call
           end
         elsif @@sigreg[signum].to_s == 'EXIT'
           Kernel.exit!(signum)
         end
       end
     end
  end # CORBA
end # R2CORBA
