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
require 'lib/assert.rb'
include TestUtil::Assertions

OPTIONS = {
  :use_implement => false,
  :orb_debuglevel => 0,
  :iorfile => 'file://server.ior'
}

ARGV.options do |opts|
    script_name = File.basename($0)
    opts.banner = "Usage: ruby #{script_name} [options]"

    opts.separator ''

    opts.on('--k IORFILE',
            'Set IOR.',
            "Default: 'file://server.ior'") { |v| OPTIONS[:iorfile] = v }
    opts.on('--d LVL',
            'Set ORBDebugLevel value.',
            'Default: 0') { |v| OPTIONS[:orb_debuglevel] = v }
    opts.on('--use-implement',
            'Load IDL through CORBA.implement() instead of precompiled code.',
            'Default: off') { |v| OPTIONS[:use_implement] = v }

    opts.separator ''

    opts.on('-h', '--help',
            'Show this help message.') { puts opts; exit }

    opts.parse!
end

if OPTIONS[:use_implement]
  require 'corba'
  CORBA.implement('Test.idl', OPTIONS)
else
  require 'TestC.rb'
end

class MyMsg
  def initialize(txt)
    @txt = txt
  end

  def to_str
    @txt
  end
end

class MyLong
  def initialize(i)
    @i = i
  end

  def to_int
    @i
  end
end

class MyArray
  def initialize(len)
    @arr = []
    len.times {|i| @arr << MyLong.new(i) }
  end

  def to_ary
    @arr
  end
end

orb = CORBA.ORB_init(['-ORBDebugLevel', OPTIONS[:orb_debuglevel]], 'myORB')

begin

  obj = orb.string_to_object(OPTIONS[:iorfile])

  hello_obj = Test::Hello._narrow(obj)

  the_string = hello_obj.echo(msg = MyMsg.new('Hello, this is an echo.'))

  puts "string returned <#{the_string}>"

  assert 'echo failed', the_string == msg.to_str

  the_seq = hello_obj.echo_seq(arr = MyArray.new(10))

  puts 'sequence returned ' + the_seq.inspect

  assert 'echo_seq failed' do
    [arr.to_ary.collect {|l| l.to_int }, the_seq].transpose.all? {|t| t.first == t.last}
  end

  hello_obj.shutdown()

ensure

  orb.destroy()

end
