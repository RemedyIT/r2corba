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
require 'corba'
CORBA.implement('supports.idl')

module BalancedAccount_support
  def initialize(start_balance = 0.0)
    self.amount = start_balance
    self.total_deposited = 0.0
    self.total_withdrawn = 0.0
    super()
  end

  def deposit(amount)
    self.amount += amount
    self.total_deposited += amount
  end

  def withdraw(amount)
    self.amount -= amount
    self.total_withdrawn += amount
  end

  def get_balance
    self
  end

  def print_it()
    print_balance('client')
  end

  def print_balance(location)
    STDERR.puts %Q{
      Account balance @ #{location}
      -----------------------------
      Amount:      #{'%.2f' % self.amount}
      Deposited:   #{'%.2f' % self.total_deposited}
      Withdrawn:   #{'%.2f' % self.total_withdrawn}
    }
  end
end

class BalancedAccount_impl < BalancedAccount
  include BalancedAccount_support
end

class BalancedAccount_factory < BalancedAccountFactory
  def _create_default
    BalancedAccount_impl.new
  end
end
