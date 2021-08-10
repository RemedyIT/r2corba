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
  def initialize(val = nil)
    self.value_ = val
  end

  def do_print(loc)
    STDERR.puts("@#{loc} (value #{self.value_})")
  end
end

class Event_factory < EventFactory
  def _create_default
    Event_impl.new
  end
end
