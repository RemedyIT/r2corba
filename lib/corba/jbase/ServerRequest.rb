#--------------------------------------------------------------------
# ServerRequest.rb - R2TAO CORBA ServerRequest support
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
    module ServerRequest
      @@wrapper_klass = Class.new do
        include CORBA::ServerRequest
        def initialize(jsrvreq, jorb)
          @srvreq_ = jsrvreq
          @orb_ = jorb
          @nvlist_ = nil
          @result_type_ = nil
          @arg_list_ = nil
          @exc_list_ = nil
          @arg_ = nil
          @arg_index_ = nil
          @arg_out_ = 0
        end
        attr_reader :srvreq_
        attr_reader :orb_
        attr_reader :arg_list_
        attr_reader :result_type_
        attr_reader :exc_list_
        attr_reader :nvlist_
        attr_reader :arg_out_
      end

      def self._wrap_native(jsrvreq, jorb)
        raise ArgumentError, 'Expected org.omg.CORBA.ServerRequest' unless jsrvreq.is_a?(Native::ServerRequest)
        raise ArgumentError, 'Expected org.omg.CORBA.ORB' unless jorb.is_a?(Native::ORB)

        @@wrapper_klass.new(jsrvreq, jorb)
      end

      def operation
        begin
          self.srvreq_.operation
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
      end

      def describe(opsig)
        raise CORBA::BAD_INV_ORDER.new('', 0, CORBA::COMPLETED_NO) if @nvlist_
        raise CORBA::NO_IMPLEMENT.new('', 0, CORBA::COMPLETED_NO) unless opsig && (Hash === opsig)

        @arg_list_ = opsig[:arg_list]
        @result_type_ = opsig[:result_type]
        @exc_list_ = opsig[:exc_list]
        raise CORBA::BAD_PARAM.new('', 0, CORBA::COMPLETED_NO) unless (@arg_list_.nil? || @arg_list_.is_a?(Array)) &&
                                                                    (@result_type_.nil? || @result_type_.is_a?(CORBA::TypeCode)) &&
                                                                    (@exc_list_.nil? || @exc_list_.is_a?(Array))

        @nvlist_ = extract_arguments_(@arg_list_)
        self
      end

      def arguments
        raise CORBA::BAD_INV_ORDER.new('', 0, CORBA::COMPLETED_NO) unless @nvlist_

        unless @arg_
          @arg_ = []
          @nvlist_.count.times do |i|
            jnv = @nvlist_.item(i)
            @arg_ << CORBA::Any.from_java(jnv.value, self.orb_, @arg_list_[i][2]) if [CORBA::ARG_IN, CORBA::ARG_INOUT].include?(jnv.flags)
            @arg_out_ += 1 if [CORBA::ARG_OUT, CORBA::ARG_INOUT].include?(jnv.flags)
          end
        end
        @arg_
      end

      def [](key)
        self.arguments # make sure the @arg_ member has been initialized
        key = arg_index_from_name(key) if String === key
        key = key.to_i if key
        raise CORBA::BAD_PARAM.new('', 0, CORBA::COMPLETD_NO) unless key && (key >= 0) && (key < @arg_.size)

        @arg_[key]
      end

      def []=(key, val)
        self.arguments # make sure the @arg_ member has been initialized
        key = arg_index_from_name(key) if String === key
        key = key.to_i if key
        raise CORBA::BAD_PARAM.new('', 0, CORBA::COMPLETD_NO) unless key && (key >= 0) && (key < @arg_.size)

        jnv = @nvlist_.item(key)
        rtc = @arg_list_[key][2]
        CORBA::Any.to_any(val, rtc).to_java(self.orb_, jnv.value)
        @arg_[key] = val
      end

      protected
      def arg_index_from_name(arg_name)
        unless @arg_index_
          @arg_index_ = {}
          @nvlist_.count.times do |i|
            jnv = @nvlist_.item(i)
            @arg_index_[jnv.name] = i
          end
        end
        @arg_index_[arg_name]
      end

      def extract_arguments_(arg_list)
        jnvlist = self.orb_.create_list(0)
        unless arg_list.nil?
          arg_list.each do |argnm, argf, argtc|
            raise CORBA::BAD_PARAM.new('', 0, CORBA::COMPLETED_NO) if argf.nil? || argtc.nil? || !argtc.is_a?(CORBA::TypeCode)

            jnvlist.add_value(argnm.to_s, Any.to_any(nil, argtc).to_java(@orb_), argf.to_i)
          end
          self.srvreq_.arguments(jnvlist)
        end
        jnvlist
      end
    end # ServerRequest
  end # CORBA
end # R2CORBA
