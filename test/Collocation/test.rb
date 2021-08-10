#--------------------------------------------------------------------
#
# Author: Martin Corino
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the R2CORBA LICENSE which is
# included with this program.
#
# Copyright (c) Remedy IT Expertise BV
#--------------------------------------------------------------------

require 'optparse'

OPTIONS = {
  :use_implement => false
}

ORB_ARG = []

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

    opts.separator ''

    opts.on('--d LVL',
            'Set ORBDebugLevel value.',
            'Default: 0') { |dlvl| ORB_ARG << '-ORBDebugLevel' << dlvl }
    opts.on('--use-implement',
            'Load IDL through CORBA.implement() instead of precompiled code.',
            'Default: off') { |v| OPTIONS[:use_implement] = v }

    opts.separator ''

    opts.on('-h', '--help',
            'Show this help message.') { puts opts; exit }

    opts.parse!
end

if OPTIONS[:use_implement]
  require 'corba/poa'
  CORBA.implement('Diamond.idl', OPTIONS, CORBA::IDL::SERVANT_INTF)
else
  require 'DiamondS.rb'
end


class Top < POA::Diamond::Top
  def shape
    'a point.'
  end
end

class Left < POA::Diamond::Left
  def shape
    'the left line'
  end

  def color
    'black'
  end
end

class Right < POA::Diamond::Right
  def shape
    'the right line'
  end

  def color
    'red'
  end

  def width
    0
  end
end

class Buttom < POA::Diamond::Buttom
  def shape
    'a diamond'
  end

  def color
    'translucent'
  end

  def name
    'Jubilee'
  end

  def width
    100
  end

  def area(unit)
    case unit
      when Diamond::Buttom::MM
        [100 * 100]
      when Diamond::Buttom::CM
        [10 * 10]
    end
  end
end

class Collocation_Test
  def initialize
    @top_servant = Top.new
    @left_servant = Left.new
    @right_servant = Right.new
    @diamond_servant = Buttom.new
  end

  def shutdown
    @root_poa.destroy(1, 1)
    @orb.destroy
  end

  def init(args = [])
    @orb = CORBA.ORB_init(['-ORBDebugLevel', OPTIONS[:orb_debuglevel]], 'myORB')

    obj = @orb.resolve_initial_references('RootPOA')

    @root_poa = PortableServer::POA._narrow(obj)

    @poa_man = @root_poa.the_POAManager

    id = @root_poa.activate_object(@top_servant)

    @top_obj = @root_poa.id_to_reference(id)

    id = @root_poa.activate_object(@diamond_servant)

    @diamond_obj = @root_poa.id_to_reference(id)

    id = @root_poa.activate_object(@left_servant)

    @left_obj = @root_poa.id_to_reference(id)

    id = @root_poa.activate_object(@right_servant)

    @right_obj = @root_poa.id_to_reference(id)

    puts "Diamond servant activated:\n#{@orb.object_to_string(@diamond_obj)}"
    puts "Top servant activated:\n#{@orb.object_to_string(@top_obj)}"
    puts "Left servant activated:\n#{@orb.object_to_string(@left_obj)}"
    puts "Right servant activated:\n#{@orb.object_to_string(@right_obj)}"
  end

  def test_narrow
    top = Diamond::Top._narrow(@diamond_obj)
    left = Diamond::Left._narrow(@diamond_obj)
    right = Diamond::Right._narrow(@diamond_obj)
    buttom = Diamond::Buttom._narrow(@diamond_obj)

    puts "Calling diamond_top.shape: #{top.shape}"
    puts "Calling diamond_left.shape: #{left.shape}"
    puts "Calling diamond_right.shape: #{right.shape}"
    puts "Calling diamond_buttom.shape: #{buttom.shape}"
    puts "Calling diamond_buttom.area(MM): #{buttom.area(Diamond::Buttom::MM)}"
    puts "Calling diamond_buttom.area(CM): #{buttom.area(Diamond::Buttom::CM)}"
  end

  def run
    @poa_man.activate

    top = Diamond::Top._narrow(@top_obj)
    left = Diamond::Left._narrow(@left_obj)
    right = Diamond::Right._narrow(@right_obj)
    puts "Calling top.shape: #{top.shape}"
    puts "Calling left.shape: #{left.shape}"
    puts "Calling right.shape: #{right.shape}"

    test_narrow
  end
end

test = Collocation_Test.new

test.init(ORB_ARG)

test.run

test.shutdown

exit(0)
