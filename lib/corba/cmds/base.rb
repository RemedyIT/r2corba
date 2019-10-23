#--------------------------------------------------------------------
# base.rb - R2CORBA base command handler
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

module R2CORBA
  module Commands

    @@commands = Hash.new do |hash, key|
      $stderr.puts "Unknown command #{key} specified."
      exit(1)
    end

    @@options = {
      :verbose => false
    }

    def self.register(cmdid, cmdhandler)
      @@commands[cmdid.to_s] = cmdhandler
    end

    def self.describe_all
      puts 'R2CORBA commands:'
      puts "\tlist\t\tlist all r2corba commands"
      @@commands.each do |id, cmd|
        desc = cmd.description.split('\n')
        puts "\t#{id}\t\t#{desc.join('\t\t\t')}"
      end
    end

    def self.run(cmdid)
      @@commands[cmdid.to_s].run
    end

    def self.options
      @@options
    end

    def self.parse_args(args)
      opts = OptionParser.new
      opts.banner = "Usage: r2corba [global options] command [command options]\n\n" +
          "    command\t\tSpecifies R2CORBA command to execute.\n"+
          "           \t\tDefault = list :== list commands\n"
      opts.separator ''
      opts.on('-v', '--verbose',
              'Show verbose output') { |v| ::R2CORBA::Commands.options[:verbose] = true }
      opts.on('-h', '--help',
               'Show this message.') { |v| puts opts; exit(0) }
      opts.parse!(args)
    end
  end
end

Dir[File.join(File.dirname(__FILE__), '*.rb')].each do |file|
  require file unless File.basename(file) == File.basename(__FILE__)
end

# extract global options and command
args = []
while cmd = ARGV.shift
  if cmd.start_with? '-'
    args << cmd
    cmd = nil
  else
    break
  end
end

R2CORBA::Commands.parse_args(args)

if cmd && cmd.downcase != 'list'
  R2CORBA::Commands.run(cmd)
else
  R2CORBA::Commands.describe_all
end
