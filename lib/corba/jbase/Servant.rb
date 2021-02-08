#--------------------------------------------------------------------
# Servant.rb - R2TAO CORBA Servant support
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

  module PortableServer

    module DSI

      class Servant < PortableServer::Native::DynamicImplementation
        def self.new_instance(rsrv)
          srv = PortableServer::DSI::Servant.new
          srv.__send__(:init, rsrv)
          srv
        end

        private
        def init(rsrv)
          @rsrv = rsrv
        end

        public
        def rbServant
          @rsrv
        end

        def detach_rbServant()
          @rsrv = nil
        end

        def invoke(jsrvreq)
          begin
            raise CORBA::NO_IMPLEMENT.new('', 0, CORBA::COMPLETED_NO) unless @rsrv
            rsrvreq = CORBA::ServerRequest._wrap_native(jsrvreq, self._orb())
            begin
              case rsrvreq.srvreq_.operation()
              when '_is_a'
                rsrvreq.describe({:arg_list => [['', CORBA::ARG_IN, CORBA._tc_string]], :result_type => CORBA._tc_boolean})
                rc = self._is_a(*rsrvreq.arguments)
                jany = rsrvreq.orb_.create_any()
                jany.insert_boolean(rc == true)
                jsrvreq.set_result(jany)
              when '_non_existent'
                rsrvreq.describe({:arg_list => [], :result_type => CORBA._tc_boolean})
                rc = self._non_existent(*rsrvreq.arguments)
                jany = rsrvreq.orb_.create_any()
                jany.insert_boolean(rc == true)
                jsrvreq.set_result(jany)
              when '_repository_id'
                rsrvreq.describe({:arg_list => [], :result_type => CORBA._tc_string})
                rc = self._repository_id(*rsrvreq.arguments)
                jany = rsrvreq.orb_.create_any()
                jany.insert_string(rc)
                jsrvreq.set_result(jany)
              when '_component'
                rsrvreq.describe({:arg_list => [], :result_type => CORBA._tc_Object})
                rc = self._get_component(*rsrvreq.arguments)
                jany = rsrvreq.orb_.create_any()
                jany.insert_Object(rc)
                jsrvreq.set_result(jany)
              else
                @rsrv.is_a?(PortableServer::DynamicImplementation) ? self.invoke_DSI(rsrvreq) : self.invoke_SI(rsrvreq)
              end
            rescue NativeException => ex_
              CORBA::Exception.native2r(ex_)
            end
          rescue CORBA::UserException => ex_
            STDERR.puts "#{ex_}\n#{ex_.backtrace.join("\n")}" if $VERBOSE
            if rsrvreq.exc_list_.nil? || rsrvreq.exc_list_.any? {|extc| extc.id == ex_.class._tc.id }
              jsrvreq.set_exception(CORBA::Any.to_any(ex_).to_java(self._orb()))
            else
              STDERR.puts "#{ex_}\n#{ex_.backtrace.join("\n")}" unless $VERBOSE
              if jsrvreq.respond_to?(:setSystemException) # JacORB special
                jsrvreq.setSystemException(CORBA::Native::UNKNOWN.new("#{ex_}", 0, CORBA::Native::CompletionStatus.from_int(CORBA::COMPLETED_MAYBE)))
              else
                jsrvreq.set_exception(CORBA::Any.to_any(CORBA::UNKNOWN.new("#{ex_}", 0, CORBA::COMPLETED_MAYBE)).to_java(self._orb()))
              end
            end
          rescue CORBA::SystemException => ex_
            STDERR.puts "#{ex_}\n#{ex_.backtrace.join("\n")}" if $VERBOSE
            if jsrvreq.respond_to?(:setSystemException) # JacORB special
              jex_klass = CORBA::Native.const_get(ex_.class::Name)
              jsrvreq.setSystemException(jex_klass.new(ex_.reason, ex_.minor, CORBA::Native::CompletionStatus.from_int(ex_.completed)))
            else
              jsrvreq.set_exception(CORBA::Any.to_any(ex_).to_java(self._orb()))
            end
          rescue Exception => ex_
            STDERR.puts "#{ex_}\n#{ex_.backtrace.join("\n")}"
            if jsrvreq.respond_to?(:setSystemException) # JacORB special
              jsrvreq.setSystemException(CORBA::Native::UNKNOWN.new("#{ex_}", 0, CORBA::Native::CompletionStatus.from_int(CORBA::COMPLETED_MAYBE)))
            else
              jsrvreq.set_exception(CORBA::Any.to_any(CORBA::UNKNOWN.new("#{ex_}", 0, CORBA::COMPLETED_MAYBE)).to_java(self._orb()))
            end
          end
        end

        def _all_interfaces(poa, oid)
          if @rsrv.nil?
            return [].to_java(:string)
          elsif @rsrv.respond_to?(:_ids)
            return @rsrv._ids.to_java(:string)
          elsif @rsrv.class.constants.any? {|c| c.to_sym == :Ids }
            return @rsrv.class::Ids.to_java(:string)
          elsif @rsrv.respond_to?(:_primary_interface)
            return [@rsrv._primary_interface(oid, poa)].to_java(:string)
          else
            return [].to_java(:string)
          end
        end

        def _is_a(repo_id)
          if @rsrv.nil?
            return false
          elsif @rsrv.respond_to?('_is_a?'.to_sym)
            return @rsrv._is_a?(repo_id)
          else
            begin
              return @rsrv.class::Ids.include?(repo_id)
            rescue
              return super
            end
          end
        end

        def _repository_id
          if @rsrv.nil?
            return ''
          elsif @rsrv.respond_to?(:_repository_id)
            return @rsrv._repository_id
          else
            return (@rsrv.class.const_get(:Id) rescue '')
          end
        end

        def _non_existent()
          if @rsrv.nil?
            return true
          elsif @rsrv.respond_to?(:_non_existent)
            return @rsrv._non_existent
          else
            return super
          end
        end

        def _get_component()
          if @rsrv.nil?
            return nil
          elsif @rsrv.respond_to?(:_get_component)
            obj = @rsrv._get_component
            return obj ? obj.objref_ : nil
          else
            return super
          end
        end
        protected
        def invoke_SI(rsrvreq)
          opsym = rsrvreq.srvreq_.operation().to_sym
          opsig = @rsrv.get_operation_signature(opsym)
          # explicitly define empty (but not nil) exceptionlist if not yet specified
          opsig[:exc_list] = [] if (Hash === opsig) && !opsig.has_key?(:exc_list)
          rsrvreq.describe(opsig)
          alt_opsym = opsig[:op_sym]
          opsym = alt_opsym if alt_opsym && alt_opsym.is_a?(Symbol)
          results = @rsrv.__send__(opsym, *rsrvreq.arguments)
          unless rsrvreq.result_type_.nil?
            result_value = (rsrvreq.arg_out_ > 0 ? results.shift : results) unless rsrvreq.result_type_.kind == CORBA::TK_VOID
            if rsrvreq.arg_out_ > 0
              rsrvreq.nvlist_.count().times do |i|
                jnv = rsrvreq.nvlist_.item(i)
                if [CORBA::ARG_OUT, CORBA::ARG_INOUT].include?(jnv.flags)
                  rval = results.shift
                  rtc = rsrvreq.arg_list_[i][2]
                  CORBA::Any.to_any(rval, rtc).to_java(self._orb(), jnv.value())
                end
              end
            end
            unless rsrvreq.result_type_.kind == CORBA::TK_VOID
              rsrvreq.srvreq_.set_result(CORBA::Any.to_any(result_value, rsrvreq.result_type_).to_java(self._orb()))
            end
          end
        end

        def invoke_DSI(rsrvreq)
          results = @rsrv.invoke(rsrvreq)
          unless rsrvreq.result_type_.nil?
            result_value = (rsrvreq.arg_out_ > 0 ? results.shift : results) unless rsrvreq.result_type_.kind == CORBA::TK_VOID
            if rsrvreq.arg_out_ > 0
              rsrvreq.nvlist_.count().times do |i|
                jnv = rsrvreq.nvlist_.item(i)
                if [CORBA::ARG_OUT, CORBA::ARG_INOUT].include?(jnv.flags)
                  rval = results.shift
                  rtc = rsrvreq.arg_list_[i][2]
                  CORBA::Any.to_any(rval, rtc).to_java(self._orb(), jnv.value())
                end
              end
            end
            unless rsrvreq.result_type_.kind == CORBA::TK_VOID
              rsrvreq.srvreq_.set_result(CORBA::Any.to_any(result_value, rsrvreq.result_type_).to_java(self._orb()))
            end
          end
        end
      end # Servant

    end # DSI

    class Servant
      def srvref_
        @srvref_ ||= PortableServer::DSI::Servant.new_instance(self)
      end

      def _default_POA()
        begin
          return PortableServer::POA._narrow(CORBA::Object._wrap_native(self.srvref_._default_POA()))
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
      end

      def _this()
        unless @srvref_.nil?
          begin
            return CORBA::Object._wrap_native(self.srvref_._this_object())
          rescue NativeException
            # not in call context or not associated with ORB yet
          end
        end
        raise CORBA::BAD_INV_ORDER.new('no ORB initialized', 0, CORBA::COMPLETED_NO) if CORBA::ORB._orb.nil?
        begin
          return CORBA::Object._wrap_native(self.srvref_._this_object(CORBA::ORB._orb))
        rescue ::NativeException
          CORBA::Exception.native2r($!)
        end
      end
    end # Servant

  end # PortableServer

end # R2CORBA
