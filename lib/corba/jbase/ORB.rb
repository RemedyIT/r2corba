#--------------------------------------------------------------------
# ORB.rb - Java/JacORB CORBA ORB definitions
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
  module CORBA
    module ORB
      class << self
        protected
        def _singleton_orb_init
          begin
            CORBA::Native::ORB.init
          rescue ArgumentError
            # this will happen if java.endorsed.dirs is used with JacORB
            # in that case just directly init on the singleton class itself
            CORBA::Native::ORBSingleton.init
          end
        end
      end

      ## init() or init(arg1, arg2[, ...]) or init(orb_id, prop = {}) or init(argv, orb_id, prop={}) or init(argv, prop={})
      def self.init(*args)
        n_orb = if args.empty?
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

          jprop = Java::JavaUtil::Properties.new
          jprop.setProperty('ORBid', orb_id) if orb_id
          prop.each { |k, v| jprop.setProperty(k.to_s, v.to_s) } if prop
          @@cached_orb = CORBA::Native::ORB.init(argv.collect { |a| a.to_s }.to_java(:string), jprop)
        end
        @@wrapper_klass.new(n_orb)
      end

      # str ::String
      # ret ::CORBA::Object
      def string_to_object(str)
        begin
          begin
            Object._wrap_native(self.orb_.string_to_object(str))
          rescue ::NativeException
            CORBA::Exception.native2r($!)
          end
        rescue CORBA::BAD_PARAM ## JacORB throws MARSHAL exception on invalid IORs which is not spec compliant
          return nil
        end
      end

      # boolean wait_for_completion
      # ret void
      def shutdown(wait_for_completion = false)
        if wait_for_completion
          # need to start this in separate thread otherwise this will lead to deadlock
          # (JacORB problem)
          (Thread.new do
            begin
              self.orb_.shutdown(wait_for_completion)
            rescue ::NativeException
              CORBA::Exception.native2r($!)
            end
          end).join()
        else
          # need to start a shutdown *with* waiting in a thread because JacORB
          # occasionally fails with a comm error when #shutdown(false) is called
          # from within a servant callback
          Thread.new do
            begin
              self.orb_.shutdown(true)
            rescue ::NativeException
              CORBA::Exception.native2r($!)
            end
          end
        end
      end

      # custom R2CORBA extension : IORMap

      def ior_map
        @iormap ||= R2CORBA::IORMap.new(self)
      end
    end
  end # CORBA
end # R2CORBA
