#--------------------------------------------------------------------
# ccs_server.rb - Implementation of Climate Control System demo
#                 service from "Advanced CORBA Programming with C++"
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

require 'optparse'

require 'corba/poa'
CORBA.implement(File.join(File.dirname(__FILE__), 'CCS.idl'), {}, CORBA::IDL::SERVANT_INTF)
require 'corba/naming'

module CCS_Server

  OPTIONS = {
      :ins_ior => nil,
      :ins_port => 2345,
      :ins_host => 'localhost'
  }

  ORB_ARG = []

  module Default
    CONTROLLER_OID = 'Controller'
    MODEL = ''
    TEMPERATURE_RANGE = 40..90
  end

  class Thermometer < POA::CCS::Thermometer
    def initialize(anum, loc)
      @model = CCS_Server::Default::MODEL
      @asset_num = anum
      @location = loc
      @temperature = nil
    end

    def model()
    end #of attribute get_model

    def asset_num()
    end #of attribute get_asset_num

    def temperature()
    end #of attribute get_temperature

    def location()
    end #of attribute get_location

    def location=(val)
    end #of attribute set_location

    def remove()
    end
  end

  class Thermostat < Thermometer
    include POA::CCS::Thermostat

    def initialize(anum, loc, temp)
      super(anum, loc)
      @nominal_temp = temp
    end

    def get_nominal
      @nominal_temp
    end

    def set_nominal(new_temp)

    end
  end

  class Controller < POA::CCS::Controller
    def initialize(poa)
      @poa_ = poa
    end

    def create_thermometer(anum, loc)
    end

    def create_thermostat(anum, loc, temp)
    end

    def list()
    end

    def find(slist)
    end

    def change(tlist, delta)
    end
  end

  def self.parse_args
    # extract -ORBxxx aguments
    f_ = false
    ARGV.collect! { |a|
      if f_
        f_ = false
        ORB_ARG << a
        nil
      else
        f_ = /^-ORB/ =~ a
        ORB_ARG << a if f_
        f_ ? nil : a
      end
    }.compact!

    ARGV.options do |opts|
      script_name = File.basename($0)
      opts.banner = "Usage: ruby #{script_name} [options]"

      opts.separator ""

      opts.on("-h INSHOST",
              "Set NamingService host address.",
              "Default: localhost") { |v| OPTIONS[:ins_host]=v }

      opts.on("-p INSPORT",
              "Set NamingService port.", Integer,
              "Default: 2345") { |v| OPTIONS[:ins_port]=v }

      opts.on("-k IORFILE",
              "Set NamingService IOR filename.",
              "Default: none") { |v| OPTIONS[:ins_ior]=v }

      opts.separator ""

      opts.on("-h", "--help",
              "Show this help message.") { puts opts; exit }

      opts.parse!
    end
  end

  def self.init(orb)
    # determin NameService IOR
    ins_ior = OPTIONS[:ins_ior] || "corbaloc:iiop:#{OPTIONS[:ins_host]}:#{OPTIONS[:ins_port]}/NamingService"
    # resolve NamingContext
    obj = orb.string_to_object(ins_ior)
    nc = CosNaming::NamingContextExt._narrow(obj)

    # initialize POA
    obj = orb.resolve_initial_references('RootPOA')

    root_poa = PortableServer::POA._narrow(obj)

    poa_man = root_poa.the_POAManager

    # Create a POA for all CCS elements.
    ccs_poa = root_poa.create_POA("CCS_POA", poa_man, [])

    # create and activate controller servant
    ccs_srv = CCS_Server::Controller.new(ccs_poa)

    ccs_poa.activate_object_with_id(CCS_Server::Default::CONTROLLER_OID, ccs_srv)

    ccs_obj = ccs_poa.id_to_reference(CCS_Server::Default::CONTROLLER_OID)

    # Attempt to create CCS context; ignore exception if already exists.
    n = [CosNaming::NameComponent.new('CCS')]
    begin nc.bind_new_context(n); rescue CosNaming::NamingContext::AlreadyBound; end

    # Force binding of controller reference to make
    # sure it is always up-to-date.
    n << CosNaming::NameComponent.new('Controller')
    nc.rebind(n, ccs_obj)

    poa_man.activate
  end

  @@orb = nil

  def self.run
    parse_args

    @@orb = CORBA.ORB_init(ORB_ARG, 'ccsORB')

    init(@@orb)

    @@orb.run
  end

  def self.shutdown
    @@orb.shutdown(false)
  end
end

if $0 == __FILE__
  Signal.trap('INT') do
    puts "SIGINT - shutting down ORB..."
    CCS_Server.shutdown
  end

  Signal.trap('USR2', 'EXIT')

  CCS_Server.run
end
