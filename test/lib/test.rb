#--------------------------------------------------------------------
# test.rb - Test running utils
#
# Author: Martin Corino
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the R2CORBA LICENSE which is
# included with this program.
#
# Copyright (c) Remedy IT Expertise BV
#--------------------------------------------------------------------

require 'rbconfig'

module TestUtil

  if defined? RbConfig
    RB_CONFIG = RbConfig::CONFIG
  else
    RB_CONFIG = Config::CONFIG
  end

  def self.is_win32?
    (RB_CONFIG['target_os'] =~ /win32/ || RB_CONFIG['target_os'] =~ /mingw32/) ? true : false
  end

  RBVersion = RUBY_VERSION.split('.').collect {|x| x.to_i}
end


if defined?(JRUBY_VERSION)
  require 'ffi'
elsif TestUtil::is_win32?
  unless TestUtil::RBVersion[0] >= 2 || TestUtil::RBVersion[1] > 8
    # get Win32 Process support
    require 'rubygems'
    gem 'windows-pr', '>= 1.2.2'
    require 'windows/api'
    require 'windows/process'
    require 'windows/error'
    require 'windows/library'
    require 'windows/console'
    require 'windows/handle'
    require 'windows/synchronize'
    require 'windows/thread'
  end
end

module TestUtil

  class ProcessError < RuntimeError; end

if defined?(JRUBY_VERSION)
  class Process
    JRUBY_CMD = File.join(RB_CONFIG['bindir'], RB_CONFIG['RUBY_INSTALL_NAME']).sub(/.*\s.*/m, '"\&"')
  protected
    module Exec
      extend FFI::Library
      ffi_lib 'c'

      if TestUtil::is_win32?

        # intptr_t _spawnvpe(int mode,
        #                    const char *cmdname,
        #                    const char *const *argv,
        #                    const char *const *envp);

        attach_function :_spawnvpe,:_spawnvpe, [:int, :string, :pointer, :pointer], :pointer

        P_NOWAIT = 1

        # intptr_t _cwait(int *termstat,
        #                 intptr_t procHandle,
        #                 int action);

        attach_function :_wait, :_cwait, [:pointer, :pointer, :int], :pointer

        module Kernel32
          extend FFI::Library
          ffi_lib 'kernel32'
          ffi_convention :stdcall

          attach_function :terminate_process, :TerminateProcess, [:pointer, :uint], :int
        end

        def self.run(cmd, args)
          argv = ['cmd', '/c']
          argv << "cd #{Dir.getwd.gsub('/', '\\')} && #{Process::JRUBY_CMD} #{$VERBOSE ? '-v' : ''} #{cmd} #{args}"
          spawnp(*argv)
        end

        def self.spawnp(*args)
          spawn_args = _prepare_spawn_args(args)
          _spawnvpe(*spawn_args)
        end

        def self.stop(pid)
          kill(pid)
        end

        def self.kill(pid)
          Kernel32.terminate_process(pid, 0) if pid
        end

        def self.wait(pid)
          stat_ptr = FFI::MemoryPointer.new(:int, 1)
          tmp_pid = _wait(stat_ptr, pid, 0)
          if tmp_pid==pid
            return [pid, stat_ptr.get_int()]
          else
            return [pid, 0]
          end
        end

        private

        def self._prepare_spawn_args(args)
          args_ary = FFI::MemoryPointer.new(:pointer, args.length + 1)
          str_ptrs = args.map {|str| FFI::MemoryPointer.from_string(str)}
          args_ary.put_array_of_pointer(0, str_ptrs)

          env_ary = FFI::MemoryPointer.new(:pointer, ENV.length + 1)
          env_ptrs = ENV.map {|key,value| FFI::MemoryPointer.from_string("#{key}=#{value}")}
          env_ary.put_array_of_pointer(0, env_ptrs)

          [P_NOWAIT, args[0], args_ary, env_ary]
        end
      else
        # Extracted from the Spoon gem by Charles Oliver Nutter

        # int
        # posix_spawnp(pid_t *restrict pid, const char *restrict path,
        #     const posix_spawn_file_actions_t *file_actions,
        #     const posix_spawnattr_t *restrict attrp, char *const argv[restrict],
        #     char *const envp[restrict]);

        attach_function :_posix_spawnp, :posix_spawnp, [:pointer, :string, :pointer, :pointer, :pointer, :pointer], :int

        def self.run(cmd, args)
          argv = ['sh', '-c']
          argv << "cd #{Dir.getwd} && #{Process::JRUBY_CMD} #{$VERBOSE ? '-v' : ''} #{cmd} #{args}"
          spawnp(*argv)
        end

        def self.spawnp(*args)
          spawn_args = _prepare_spawn_args(args)
          _posix_spawnp(*spawn_args)
          spawn_args[0].read_int
        end

        def self.stop(pid)
          ::Process.kill('TERM', pid) if pid
        end

        def self.kill(pid)
          ::Process.kill('KILL', pid) if pid
        end

        def self.wait(pid)
          
            tmp, status = ::Process.waitpid2(pid, ::Process::WNOHANG)
            if tmp==pid and status.success? != nil
              return [pid, status.success?() ? 0 : status.exitstatus ]
            end
            return [nil, 0]
          rescue Errno::ECHILD
            return [pid, 0]
          
        end

        private

        def self._prepare_spawn_args(args)
          pid_ptr = FFI::MemoryPointer.new(:pid_t, 1)

          args_ary = FFI::MemoryPointer.new(:pointer, args.length + 1)
          str_ptrs = args.map {|str| FFI::MemoryPointer.from_string(str)}
          args_ary.put_array_of_pointer(0, str_ptrs)

          env_ary = FFI::MemoryPointer.new(:pointer, ENV.length + 1)
          env_ptrs = ENV.map {|key,value| FFI::MemoryPointer.from_string("#{key}=#{value}")}
          env_ary.put_array_of_pointer(0, env_ptrs)

          [pid_ptr, args[0], nil, nil, args_ary, env_ary]
        end
      end
    end
    def initialize(cmd_, arg_)
      @pid = nil
      @exitstatus = nil
      @trd = Thread.start() do
        exit_status = 0
        @pid = Exec.run(cmd_, arg_)
        if @pid
          is_running = true
          while is_running
            sleep 0.01

            tmp_pid, tmp_status = Exec.wait(@pid)
            if tmp_pid==@pid
              exit_status = tmp_status
              is_running = false
            end
          end
        end
        exit_status
      end
    end
  public
    private_class_method :new

    def Process.run(cmd_, arg_)
      proc = new(cmd_, arg_)
      sleep(0.1)
      proc.check_status
      return proc
    end

    def pid
      @pid
    end

    def check_status
      
        unless @trd.alive?
          @exitstatus = @trd.value
        end
        return @trd.alive?
      rescue
        @exitstatus = 0
        return false
      
    end

    def exitstatus
      @exitstatus
    end

    def is_running?; @exitstatus.nil?; end
    def has_error? ; @trd.status.nil? or (!self.is_running? and self.exitstatus!=0) ;end

    def stop
      Exec.stop(@pid)
    end

    def kill
      Exec.kill(@pid)
    end
  end # Process
elsif is_win32? && TestUtil::RBVersion[0] < 2 && TestUtil::RBVersion[1] < 9
    class Process
      include Windows::Error
      include Windows::Library
      include Windows::Console
      include Windows::Handle
      include Windows::Synchronize
      include Windows::Thread
      extend Windows::Error
      extend Windows::Library
      extend Windows::Console
      extend Windows::Handle
      extend Windows::Synchronize
      extend Windows::Thread

    protected
      # Used by Process.create
      ProcessInfo = Struct.new("ProcessInfo",
          :process_handle,
          :thread_handle,
          :process_id,
          :thread_id
      )

      module WinAPI
        Windows::API.auto_namespace = 'TestUtil::Process::WinAPI'
        Windows::API.auto_constant = true
        Windows::API.auto_method = true
        Windows::API.auto_unicode = true

        STILL_ACTIVE = 259

        Windows::API.new('CreateProcess', 'PPPPLLLPPP', 'B')
        Windows::API.new('GetExitCodeProcess', 'LP', 'B')
      end

      include WinAPI
      extend WinAPI

      def Process.create(cmd_)
        startinfo = [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]
        startinfo = startinfo.pack('LLLLLLLLLLLLSSLLLL')
        procinfo  = [0,0,0,0].pack('LLLL')

        bool = CreateProcess(
           0,                 # App name
           cmd_,              # Command line
           0,                 # Process attributes
           0,                 # Thread attributes
           1,                 # Inherit handles?
           0,                 # Creation flags
           0,                 # Environment
           0,                 # Working directory
           startinfo,         # Startup Info
           procinfo           # Process Info
        )

        unless bool
           raise ProcessError, "CreateProcess() failed: ", get_last_error
        end

        ProcessInfo.new(
           procinfo[0,4].unpack('L').first, # hProcess
           procinfo[4,4].unpack('L').first, # hThread
           procinfo[8,4].unpack('L').first, # hProcessId
           procinfo[12,4].unpack('L').first # hThreadId
        )
      end

      def Process.waitpi(pi_)
        exit_code = [0].pack('L')
        if GetExitCodeProcess(pi_.process_handle, exit_code)
          exit_code = exit_code.unpack('L').first
          return exit_code == STILL_ACTIVE ? nil : exit_code
        else
          CloseHandle(pi_.process_handle) unless pi_.process_handle == INVALID_HANDLE_VALUE
          pi_.process_handle = INVALID_HANDLE_VALUE
          raise ProcessError, "GetExitCodeProcess failed: ", get_last_error
        end
      end

      def Process.stop(pi_)
        if pi_.process_handle != INVALID_HANDLE_VALUE
          thread_id = [0].pack('L')
          dll       = 'kernel32'
          proc      = 'ExitProcess'

          mh = GetModuleHandle(dll)
          pa = GetProcAddress(mh, proc)
          thread = CreateRemoteThread(
              pi_.process_handle,
              0,
              0,
              pa,
              0,
              0,
              thread_id
          )

          if thread
              WaitForSingleObject(thread, 5)
              CloseHandle(pi_.process_handle)
              pi_.process_handle = INVALID_HANDLE_VALUE
          else
              CloseHandle(pi_.process_handle)
              pi_.process_handle = INVALID_HANDLE_VALUE
              raise ProcessError, get_last_error
          end
        end
      end

      def Process.kill(pi_)
        if pi_.process_handle != INVALID_HANDLE_VALUE
          if TerminateProcess(pi_.process_handle, pi_.process_id)
            CloseHandle(pi_.process_handle)
            pi_.process_handle = INVALID_HANDLE_VALUE
          else
            CloseHandle(pi_.process_handle)
            pi_.process_handle = INVALID_HANDLE_VALUE
            raise ProcessError, get_last_error
          end
        end
      end

      def initialize(pi_)
        @pi = pi_
        @exitstatus = nil
      end
    public
      private_class_method :new
      def Process.run(cmd_, arg_)
        pi = self.create("#{RB_CONFIG['RUBY_INSTALL_NAME']} #{$VERBOSE ? '-v' : ''} #{cmd_} #{arg_}")
        proc = new(pi)
        sleep(0.1)
        proc.check_status
        return proc
      end

      def pid; @pi.process_id; end

      def check_status
        @exitstatus ||= self.class.waitpi(@pi)
        return @exitstatus.nil?
      end

      def exitstatus; @exitstatus; end

      def is_running?; @exitstatus.nil?; end
      def has_error?; !@exitstatus.nil? and (@exitstatus != 0); end

      def stop
        self.class.stop(@pi)
        @exitstatus = 0
      end

      def kill
        self.class.kill(@pi)
      end
    end # Process
else # !win32
  class Process
  protected
    def initialize(pid_)
      @pid = pid_
      @status = nil
      @exitstatus = nil
    end
  public
    private_class_method :new
    unless TestUtil::RBVersion[0] >= 2 || TestUtil::RBVersion[1] > 8
      def Process.run(cmd_, arg_)
        pid = ::Process.fork do
          ::Kernel.exec("#{RB_CONFIG['RUBY_INSTALL_NAME']} #{$VERBOSE ? '-v' : ''} #{cmd_} #{arg_}")
        end
        proc = new(pid)
        sleep(0.1)
        proc.check_status
        return proc
      end
    else
      def Process.run(cmd_, arg_)
        pid = ::Kernel.spawn("#{RB_CONFIG['RUBY_INSTALL_NAME']} #{$VERBOSE ? '-v' : ''} #{cmd_} #{arg_}")
        proc = new(pid)
        sleep(0.1)
        proc.check_status
        return proc
      end
    end

    attr_reader :pid

    def check_status
      
        tmp, @status = ::Process.waitpid2(@pid, ::Process::WNOHANG)
        if tmp==@pid and @status.success? == false
          @exitstatus = @status.exitstatus
          return false
        end
        return true
      rescue Errno::ECHILD
        @exitstatus = 0
        return false
      
    end

    def exitstatus
      @exitstatus
    end

    def is_running?; @exitstatus.nil?; end
    def has_error?; !@status.nil? and (@status.success? == false); end

    def stop
      ::Process.kill('SIGTERM', @pid)
    end

    def kill
      ::Process.kill('SIGKILL', @pid)
    end
  end # Process
end

  class Test
    def initialize
      @proc = nil
      @cmd = ""
    end

    def run(cmd_, arg_)
      @cmd = cmd_
      begin
        @proc = Process.run(cmd_, arg_)
      rescue ProcessError
        STDERR.puts "ERROR: failed to run <#{@cmd}>"
        return false
      end
      true
    end

    def pid; @proc.pid; end
    def is_running?; @proc.is_running?; end
    def exit_status; @proc.exitstatus; end

    def wait(timeout, check_exit=true)
      t = Time.now
      begin
        if @proc.check_status
          if (Time.now() - t) >= timeout.to_f
            STDERR.puts "ERROR: KILLING #{@cmd}"
            @proc.kill
            return 255
          end
          sleep(0.1)
        end
      end until !@proc.is_running?
      if check_exit && @proc.has_error?
        STDERR.puts "ERROR: #{@cmd} returned: #{@proc.exitstatus}"
        return @proc.exitstatus != 0 ? @proc.exitstatus : 255
      end
      return 0
    end

    def wait_term(timeout)
      @proc.stop
      self.wait(timeout, false)
    end

    def kill(timeout)
      @proc.kill
      self.wait(timeout, false)
    end

  end

  def TestUtil.wait_for_file(filename, timeout)
    t = Time.now
    while !File.readable?(filename) do
      sleep(0.1)
      if (Time.now() - t) >= timeout.to_f
        STDERR.puts "ERROR: could not find file '#{filename}'"
        return false
      end
    end
    true
  end

  def TestUtil.remove_file(filename)
    File.delete(filename) if File.exist?(filename)
  end

end

