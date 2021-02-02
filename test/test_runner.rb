#--------------------------------------------------------------------
# test_runner.rb - main test runner
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
require 'optparse'

if defined? RbConfig
  RB_CONFIG = RbConfig::CONFIG
else
  RB_CONFIG = Config::CONFIG
end

is_win32 = (RB_CONFIG['target_os'] =~ /win32/ || RB_CONFIG['target_os'] =~ /mingw32/) ? true : false

root_path = File.expand_path(File.join(File.dirname(__FILE__), '..'))

has_local_ridl = File.directory?(File.join(root_path, 'ridl'))

if defined?(JRUBY_VERSION)
  ENV['JACORB_HOME'] ||= File.expand_path(File.join(root_path, 'jacorb'))
  incdirs = [
      has_local_ridl ? File.expand_path(File.join(root_path, 'ridl', 'lib')) : nil,
      File.expand_path(File.join(root_path, 'lib')),
      File.expand_path(File.join(root_path, 'ext')),
      File.expand_path(File.join(ENV['JACORB_HOME'], 'lib')),
      ENV['RUBYLIB'],
      '.'
    ].compact
  ENV['RUBYLIB'] = incdirs.join(File::PATH_SEPARATOR)
else
  ace_root = ENV['ACE_ROOT'] || File.expand_path(File.join(root_path, 'ACE', 'ACE_wrappers'))
  ## setup the right environment for running tests
  incdirs = [
      has_local_ridl ? File.expand_path(File.join(root_path, 'ridl', 'lib')) : nil,
      File.expand_path(File.join(root_path, 'lib')),
      File.expand_path(File.join(root_path, 'ext')),
      ENV['RUBYLIB'],
      '.'
  ].compact
  ENV['RUBYLIB'] = incdirs.join(File::PATH_SEPARATOR)
  if is_win32
    ENV['PATH'] = [
      File.directory?(ace_root) ? File.join(ENV['ACE_ROOT'],'lib') : nil,
      File.expand_path(File.join(root_path, 'ext')),
      ENV['PATH']
      ].compact.join(File::PATH_SEPARATOR)
  elsif RUBY_PLATFORM =~ /darwin/
      ENV['DYLD_LIBRARY_PATH'] = [
          File.directory?(ace_root) ? File.join(ENV['ACE_ROOT'],'lib') : nil,
          ENV['DYLD_LIBRARY_PATH']
        ].compact.join(File::PATH_SEPARATOR)
      ENV['DYLD_FALLBACK_LIBRARY_PATH'] = [
          File.directory?(ace_root) ? File.join(ENV['ACE_ROOT'],'lib') : nil,
          File.expand_path(File.join(root_path, 'ext')),
          ENV['DYLD_FALLBACK_LIBRARY_PATH']
        ].compact.join(File::PATH_SEPARATOR)
  else
    ENV['LD_LIBRARY_PATH'] = [
        File.directory?(ace_root) ? File.join(ENV['ACE_ROOT'],'lib') : nil,
        ENV['LD_LIBRARY_PATH']
      ].compact.join(File::PATH_SEPARATOR)
  end
end

module TestFinder
  OPTIONS = {
    :exclude => nil,
    :runonly => nil,
    :listonly => false,
    :debug => !ENV['R2CORBA_DEBUG'].nil?
    }

  ROOT = File.expand_path(File.dirname(__FILE__))

  class << self
    ## define test class
    def define_test_runner
      TestFinder.const_set(:TestRunner, Class.new(Test::Unit::TestCase) do
          self.const_set(:PROG, RB_CONFIG['RUBY_INSTALL_NAME'])
          def self.run_it(path, cmd)
            cur_dir = Dir.getwd
            Dir.chdir(path)
            begin
              Kernel.system(cmd)
              return $?.exitstatus
            ensure
              Dir.chdir(cur_dir)
            end
          end
        end) unless defined?(TestFinder::TestRunner)
    end
  end

  def self.process_directory(path)
    cmd = nil
    unless OPTIONS[:listonly]
      cmd = TestRunner::PROG + ' '
      cmd << (ENV['R2CORBA_VERBOSE'].nil? ? '' : '-v ') <<
             'run_test.rb ' <<
             (OPTIONS[:debug] ? '-d' : '')
    end
    if File.directory?(path)
      if File.exist?(File.join(path, 'run_test.rb'))
        dir = path.gsub(/^#{ROOT.gsub('/', '\/')}\//, '')
        return if (OPTIONS[:exclude] || []).any? {|match| /^#{match.gsub('/', '\/')}/ =~ dir }
        unless OPTIONS[:listonly]
          TestRunner.module_eval %Q{
          def test_#{dir.gsub('/', '_')}
            puts ""
            puts "##### running test #{dir}"
            puts ""
            exstat = TestRunner.run_it('#{path}', "#{cmd}")
            raise "Execution of test #{dir} failed with exitstatus \#\{exstat\}" unless exstat == 0
          end
          }
        else
          puts dir
        end
      else
        Dir.glob(File.join(path, "*")) {|psub| self.process_directory(psub)}
      end
    end
  end

  def self.run(argv)
    opts = OptionParser.new
    script_name = File.basename($0)
    opts.banner = "Usage: #{script_name} #{/r2corba/ =~ script_name ? 'test ' : nil}[options]"

    opts.separator ""

    opts.on("-x MATCH", "--exclude=MATCH",
            "Do not run tests matching MATCH.",
            "Default: nil") { |v| (OPTIONS[:exclude] ||= []) << v.to_s }
    opts.on("-r MATCH", "--run=MATCH",
            "Only run tests matching MATCH.",
            "Default: nil (run all)") { |v| (OPTIONS[:runonly] ||= []) << v.to_s }
    opts.on('-l', '--list',
            'List tests, do not run.',
            "Default: off") { OPTIONS[:listonly] = true }
    opts.on("-d",
            "Run with debugging output.",
            "Default: ENV['R2CORBA_DEBUG'].nil? ? false : true") { OPTIONS[:debug] = true }

    opts.separator ""

    opts.on("-h", "--help",
            "Show this help message.") { puts opts; exit }

    opts.parse!(argv)

    unless argv.empty?
      (OPTIONS[:runonly] ||= []).concat(argv.collect {|a| a.gsub('\\', '/') })
    end
    argv.clear

    unless OPTIONS[:listonly]
      require 'test/unit'

      define_test_runner
    end

    if OPTIONS[:runonly].nil?
      Dir.glob(File.join(TestFinder::ROOT, "*")) do |p|
        TestFinder.process_directory(p)
      end
    else
      OPTIONS[:runonly].each do |match|
        Dir.glob(File.join(TestFinder::ROOT, "#{match.to_s}*")) do |p|
          TestFinder.process_directory(p)
        end
      end
    end
  end
end

# add Ruby library path for test library
ENV['RUBYLIB'] = ((ENV['RUBYLIB'] || '').split(File::PATH_SEPARATOR)+[TestFinder::ROOT]).join(File::PATH_SEPARATOR)

if $0 == __FILE__
  TestFinder.run(ARGV)
end
