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

class Event_impl < Event
  def initialize(val = nil, msg = nil)
    self.value_ = val
    self.msg_ = msg
  end

  def do_print(loc)
    STDERR.puts("@#{loc} (value=#{self.value_}; msg=#{self.msg_})")
  end

  def marshal(os)
    os.write_long(self.value_)
    os.write_string(self.msg_)
  end

  def unmarshal(is)
    self.value_ = is.read_long
    self.msg_ = is.read_string
  end
end

class Event_factory < EventFactory
  def _create_default
    Event_impl.new
  end

  def init(msg, val)
    Event_impl.new(val, msg)
  end
end
