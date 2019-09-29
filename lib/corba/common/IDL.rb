#--------------------------------------------------------------------
# IDL.rb - inline IDL loading support
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

# hardwire RIDL to embedded state for Ruby language mapping
module IDL
  @@embedded = true
  @@be_name = :ruby
end

begin
  require 'rubygems'
rescue LoadError
  # ignore error, RIDL may be installed locally not as gem
end
require 'ridl/ridl'

module R2CORBA

  module CORBA

    module IDL
      CLIENT_STUB = 1.freeze
      SERVANT_INTF = 2.freeze

      @@loaded_idls = {}

      def IDL.implement(idlfile, params = {}, genbits = CLIENT_STUB)
        idlreg = @@loaded_idls[idlfile]
        if idlreg.nil? || ((idlreg & genbits) != genbits)
          idlreg ||= 0
          if block_given?
            @@loaded_idls[idlfile] = idlreg | genbits
            yield
          else
            params[:includepaths] ||= $:
            fp = find_include(idlfile, params[:includepaths])
            begin
              f = File.open(fp, 'r')
              params.store(:stubs_only, !gen_servant_intf?(idlreg, genbits))
              params.store(:client_stubs, gen_client_stubs?(idlreg, genbits))
              ## check for forced stub generation
              genbits |= CLIENT_STUB if params[:client_stubs]
              @@loaded_idls[idlfile] = (idlreg | genbits)
              ::IDL::RIDL.eval(f, params)
            ensure
              f.close
            end
          end
        end
      end
      private
      def IDL.find_include(fname, paths)
        fpath = if File.file?(fname) && File.readable?(fname)
          fname
        else
          fp = paths.find do |p|
            f = p + "/" + fname
            File.file?(f) && File.readable?(f)
          end
          fp += '/' + fname if !fp.nil?
          fp
        end
        if not fpath.nil?
          return fpath
        end
        raise "Cannot open IDL file '#{fname}'"
      end

      def IDL.gen_servant_intf?(idlreg, genbits)
        if (genbits & SERVANT_INTF) == SERVANT_INTF
          (idlreg & SERVANT_INTF) != SERVANT_INTF
        else
          false
        end
      end

      def IDL.gen_client_stubs?(idlreg, genbits)
        if (idlreg & CLIENT_STUB) == CLIENT_STUB
          false
        else
          if (genbits & CLIENT_STUB) == CLIENT_STUB
            true
          else
            ## if servant intf need to be generated we *require* client stubs too
            gen_servant_intf?(idlreg, genbits)
          end
        end
      end

    end

  end

end
