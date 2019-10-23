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

OPTIONS = {
  :debug_opt => '',
  :use_implement => '--use-implement'
}

require 'optparse'

ARGV.options do |opts|
    script_name = File.basename($0)
    opts.banner = "Usage: ruby #{script_name} [options]"

    opts.separator ""

    opts.on("-d",
            "Run with debugging output.",
            "Default: false") { OPTIONS[:debug_opt] = '--d 10' }
    opts.on("--use-stubs",
            "Use stubs generated by RIDL.",
            "Default: false (uses embedded IDL)") { OPTIONS[:use_implement] = '' }

    opts.separator ""

    opts.on("-h", "--help",
            "Show this help message.") { puts opts; exit }

    opts.parse!
end

require 'lib/test.rb'
include TestUtil

clt = Test.new

if !clt.run('client.rb', "#{OPTIONS[:debug_opt]} #{OPTIONS[:use_implement]}")
  exit(255)
end

exrc = clt.wait(400)

exit(exrc)
