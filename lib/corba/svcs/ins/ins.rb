#--------------------------------------------------------------------
# ins.rb - main file for R2CORBA INS service
#
# Author: Martin Corino
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the R2CORBA LICENSE which is
# included with this program.
#
# Copyright (c) Remedy IT Expertise BV
#--------------------------------------------------------------------

require 'corba/svcs/ins/naming_service'
require 'optparse'

module R2CORBA
  module INS
    INS_VERSION_MAJOR = 0
    INS_VERSION_MINOR = 1
    INS_VERSION_RELEASE = 1
    INS_COPYRIGHT = "Copyright (c) 2011-#{Time.now.year} Remedy IT Expertise BV, The Netherlands".freeze

    IS_WIN32 = (RUBY_PLATFORM =~ /win32/ || RUBY_PLATFORM =~ /mingw32/ || ENV['OS'] =~ /windows/i) ? true : false
    IS_JRUBY = defined?(JRUBY_VERSION)

    @@daemons_installed = false

    unless IS_WIN32 || IS_JRUBY
      begin
        require 'rubygems'
        require 'daemons'
        @@daemons_installed = true
      rescue LoadError
        STDERR.puts 'Daemon functionality requires installed "daemons" GEM.'
      end
    end

    def INS.daemons_installed
      @@daemons_installed
    end

    class Controller
      def initialize(options)
        @options = options
      end

      def report(msg)
        STDERR.puts msg if @options[:verbose]
      end
    end

    if IS_WIN32 || IS_JRUBY || !INS.daemons_installed
      class Controller
        def start
          report 'INS - initializing service'

          if self.pidfile_exists?
            rc, pid = self.check_pidfile
            if rc
              STDERR.puts "ERROR: INS - existing PID file #{self.pidfile} found; service may still be alive"
              exit 1
            else
              File.delete(self.pidfile)
            end
          end

          begin
            File.open(self.pidfile, File::CREAT|File::EXCL|File::WRONLY) do |f|
              f.write Process.pid
            end
            report "INS - PID \##{Process.pid} written to '#{self.pidfile}'"
          rescue ::Exception
            STDERR.puts "ERROR: INS - failed to write PID file #{self.pidfile}"
            exit 1
          end

          $ins_service_pid_file = self.pidfile
          at_exit {
            File.delete($ins_service_pid_file)
          }

          # initialize service
          ins_svc = INS::Service.new(@options)

          report 'INS - running service'

          stop_proc = Proc.new do
            report 'INS - shutting down'
            begin; ins_svc.shutdown; rescue ::Exception; STDERR.puts "#{$!}\n#{$!.backtrace.join("\n")}"; end
          end
          Signal.trap('INT', stop_proc)
          Signal.trap('TERM', stop_proc)

          ins_svc.setup

          ins_svc.run

          report 'INS - stopped'
        end

        def stop
          report 'INS - stopping service'

          rc, pid = self.check_pidfile()

          if pid
            report 'INS - signalling service'
            if IS_WIN32
              Kernel.system("taskkill /PID #{pid} /F")
              File.delete(self.pidfile)
            else
              Process.kill(:TERM, pid) rescue nil
            end
          end
        end

        def status
          report 'INS - retrieving service status'

          rc, pid = self.check_pidfile()

          if pid
            if rc
              STDERR.puts "found PID #{pid} in file #{pidfile} : process is alive"
            else
              STDERR.puts "found PID #{pid} in file #{pidfile} : process is not running"
              exit 1
            end
          end
        end

        protected
        def pidfile
          @pidfile ||= File.join(@options[:piddir], 'ins.rb.pid')
        end

        def pidfile_exists?
          File.exist?(self.pidfile)
        end

        def check_pidfile
          pid = nil
          begin
            File.open(self.pidfile, 'r') do |f|
              pid = f.read.to_i
            end
          rescue ::Exception
            STDERR.puts "ERROR: INS - failed to read PID file #{self.pidfile}"
            return [false, nil]
          end

          begin
            Process.kill(0, pid)
            return [true, pid]
          rescue ::Exception
            return [false, pid]
          end
        end
      end # Controller
    else
      # Service controller for *nix platforms
      #
      require 'rubygems'
      require 'daemons'

      class ::Daemons::Application
        def exit
          # make exit() call a NOOP here
          # Daemons calls this when shutting down and that messes up our clean shutdown
          # STDERR.puts 'exit NOOP'
        end
      end

      class Controller
        def start
          report 'INS - initializing service'
          # initialize service
          ins_svc = INS::Service.new(@options)

          if @options[:daemon]
            report 'INS - starting daemon mode'

            daemon_opt = {
              :app_name => 'rins',
              :ARGV => ['start'],
              :dir_mode => :normal,
              :dir => @options[:piddir],
              :multiple => true,
              :log_dir => @options[:logdir] || @options[:piddir],
              :log_output => true,
              :stop_proc => Proc.new do
                report 'INS - shutting down'
                ins_svc.shutdown
              end
            }

            Daemons.run_proc('ins.rb', daemon_opt) do
              report 'INS - daemon started'

              ins_svc.setup

              ins_svc.run

              report 'INS - stopped'
            end
          else
            report 'INS - running service in foreground'

            if self.pidfile_exists?
              rc, pid = self.check_pidfile
              if rc
                STDERR.puts "ERROR: INS - existing PID file #{self.pidfile} found; service may still be alive"
                exit 1
              else
                File.delete(self.pidfile)
              end
            end

            begin
              File.open(self.pidfile, File::CREAT|File::EXCL|File::WRONLY) do |f|
                f.write Process.pid
              end
              report "INS - PID \##{Process.pid} written to '#{self.pidfile}'"
            rescue ::Exception
              STDERR.puts "ERROR: INS - failed to write PID file #{self.pidfile}"
              exit 1
            end

            $ins_service_pid_file = self.pidfile
            at_exit {
              File.delete($ins_service_pid_file)
            }

            stop_proc = Proc.new do
              report 'INS - shutting down'
              begin; ins_svc.shutdown; rescue ::Exception; STDERR.puts "#{$!}\n#{$!.backtrace.join("\n")}"; end
            end
            Signal.trap('INT', stop_proc)
            Signal.trap('TERM', stop_proc)

            ins_svc.setup

            ins_svc.run

            report 'INS - stopped'

            exit(0)
          end
        end

        def stop
          report 'INS - stopping service'
          if @options[:daemon]
            daemon_opt = {
              :app_name => 'rins',
              :ARGV => ['stop'],
              :dir_mode => :normal,
              :dir => @options[:piddir],
              :multiple => true,
            }

            Daemons.run_proc('ins.rb', daemon_opt) {}
          else
            rc, pid = self.check_pidfile()

            if pid
              report 'INS - signalling service'
              Process.kill(:TERM, pid) rescue nil
            end
          end
        end

        def restart
          if @options[:daemon]
            report 'INS - initializing service'
            # initialize service
            ins_svc = INS::Service.new(@options)

            report 'INS - restarting daemon mode'

            daemon_opt = {
              :app_name => 'rins',
              :ARGV => ['restart'],
              :dir_mode => :normal,
              :dir => @options[:piddir],
              :multiple => true,
              :log_dir => @options[:logdir] || @options[:piddir],
              :log_output => true,
              :stop_proc => Proc.new do
                report 'INS - shutting down'
                ins_svc.shutdown
              end
            }

            Daemons.run_proc('ins.rb', daemon_opt) do
              report 'INS - daemon started'

              ins_svc.setup

              ins_svc.run

              report 'INS - stopped'
            end
          else
            STDERR.puts "INS - restart command is only functional in daemon mode"
            exit 1
          end
        end

        def status
          report 'INS - retrieving service status'
          daemon_opt = {
            :app_name => 'rins',
            :ARGV => ['status'],
            :dir_mode => :normal,
            :dir => @options[:piddir],
            :multiple => true,
          }

          Daemons.run_proc('ins.rb', daemon_opt) {}
        end

        protected
        def pidfile
          @pidfile ||= File.join(@options[:piddir], 'ins.rb.pid')
        end

        def pidfile_exists?
          File.exist?(self.pidfile)
        end

        def check_pidfile
          pid = nil
          begin
            File.open(self.pidfile, 'r') do |f|
              pid = f.read.to_i
            end
          rescue ::Exception
            STDERR.puts "ERROR: INS - failed to read PID file #{self.pidfile}"
            return [false, nil]
          end

          begin
            Process.kill(0, pid)
            return [true, pid]
          rescue ::Exception
            return [false, pid]
          end
        end
      end # Controller
    end

    OPTIONS = {
      :piddir => Dir.getwd,
      :iorfile => 'ins.ior',
      :debug => 0,
      :logdir => nil,
      :threads => 5,
      :orbprop => {},
      :port => 0,
    }

    COMMANDS = [
      :start,
      :stop,
      :restart,
      :status,
      :help,
      :version
      ]
    if IS_JRUBY
      COMMANDS.delete(:restart)
    end
    if IS_WIN32
      COMMANDS << :install
      COMMANDS << :remove
    end

    @@command = nil

    def INS.command
      @@command
    end

    def INS.parse_arg
      script_name = File.basename($0, '.bat')
      if not script_name =~ /rins/
        script_name = "ruby "+$0
      end

      @@command = ARGV.shift.to_sym unless ARGV.empty?
      unless COMMANDS.include?(@@command)
        STDERR.puts "ERROR: Invalid command [#{command}]!\n"+
                    "Usage: #{script_name} #{COMMANDS.join('|')} [options]\n"
        exit 1
      end

      # extract -ORBxxx aguments
      f_ = false
      ARGV.collect! { |a|
        if f_
          f_ = false
          OPTIONS[:orbprop] << a
          nil
        else
          f_ = /^-ORB/ =~ a
          OPTIONS[:orbprop] << a if f_
          f_ ? nil : a
        end
      }.compact!

      case @@command
      when :help
        puts "Usage: #{script_name} #{COMMANDS.join('|')} [options]\n"
        puts "\n"
        puts "       #{script_name} #{(COMMANDS - [:help, :version]).join('|')} --help\n"
        puts "          provides help for the specified command\n\n"
        exit
      when :version
        puts "R2CORBA Interoprable Naming Service (INS) #{INS_VERSION_MAJOR}.#{INS_VERSION_MINOR}.#{INS_VERSION_RELEASE}"
        puts INS_COPYRIGHT
        puts ''
        exit
      when :start, :restart
        ARGV.options do |opts|
            opts.banner = "Usage: #{script_name} start [options]"

            opts.separator ""

            opts.on("-i FILE", "--ior=FILE", String,
                    "Specifies filename (incl. path) to write IOR to.",
                    "Default: ./ins.ior") { |v| OPTIONS[:iorfile]=v }
            unless IS_WIN32
              opts.on("-p DIR", "--pid=DIR", String,
                      "Specifies path to write pidfile to.",
                      "Default: ./") { |v| OPTIONS[:piddir]=v }
              unless IS_JRUBY
                opts.on("-o DIR", "--output=DIR", String,
                        "Specifies filename to write logfile to.",
                        "Default: <piddir>") { |v| OPTIONS[:logdir]=v }
              end
            else
              opts.on("-o DIR", "--output=DIR", String,
                      "Specifies path to write logfile to.",
                      "Default: ./") { |v| OPTIONS[:logdir]=v }
            end
            opts.on("-l PORTNUM", "--listen=PORTNUM", Integer,
                    "Specifies port number for service endpoint.",
                    "Default: none") { |v| OPTIONS[:port]=v }
            if (IS_JRUBY or R2CORBA::TAO::RUBY_THREAD_SUPPORT)
              opts.on("-t THREADNUM", "--threads=THREADNUM", Integer,
                      "Specifies (minimum) number of threads for service.",
                      "Default: 5") { |v| OPTIONS[:threads]=v }
            end

            unless IS_JRUBY || !INS.daemons_installed
              opts.on("-d", "--daemon",
                      "Run as daemon.",
                      "Default: off") { |v| OPTIONS[:daemon]=v }
            end
            opts.on("-v", "--verbose",
                    "Run verbose.",
                    "Default: off") { |v| OPTIONS[:verbose]=v }

            opts.on("--debug=LVL", Integer,
                    "Specifies debug level.",
                    "Default: 0") { |v| OPTIONS[:debug]=v }

            opts.separator ""

            opts.on("-h", "--help",
                    "Show this help message.") { puts opts; puts; exit }

            opts.parse!
        end
        OPTIONS[:iorfile] = File.expand_path(OPTIONS[:iorfile])
      when :stop, :status
        ARGV.options do |opts|
            opts.banner = "Usage: #{script_name} stop [options]"

            opts.separator ""

            unless IS_WIN32
              opts.on("-p DIR", "--pid=DIR", String,
                      "Specifies path where pidfile is stored.",
                      "Default: ./") { |v| OPTIONS[:piddir]=v }
            end

            unless @@command == 'status'
              OPTIONS[:daemon] = true unless IS_JRUBY || !INS.daemons_installed
              opts.on("--[no-]daemon",
                      "Do not run in daemon mode.",
                      "Default: #{OPTIONS[:daemon] ? 'on' : 'off'}") { |v| OPTIONS[:daemon]=v }
            end
            opts.on("-v", "--verbose",
                    "Run verbose.",
                    "Default: off") { |v| OPTIONS[:verbose]=v }

            opts.separator ""

            opts.on("-h", "--help",
                    "Show this help message.") { puts opts; puts; exit }

            opts.parse!
        end
      when :install
      when :remove
      end
      OPTIONS[:piddir] = File.expand_path(OPTIONS[:piddir]) if OPTIONS[:piddir]
      OPTIONS[:logdir] = File.expand_path(OPTIONS[:logdir]) if OPTIONS[:logdir]
    end

    def INS.run
      self.parse_arg()

      Controller.new(OPTIONS).send(self.command)
    end
  end
end

if __FILE__ == $0

  R2CORBA::INS.run

end
