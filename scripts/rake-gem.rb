
require File.join(File.dirname(__FILE__), 'rake-common')
require './lib/corba/common/version'

task :define_gemspec do
  R2CORBA.define_spec('r2corba', R2CORBA::R2CORBA_VERSION) do |gem|
    gem.summary = %Q{CORBA language mapping implementation for Ruby}
    gem.description = %Q{OMG CORBA v. 3.3 compliant CORBA language mapping implementation for Ruby. Depends on ridl gem for providing native Ruby IDL compiler. }
    gem.email = 'mcorino@remedy.nl'
    gem.homepage = "https://www.remedy.nl/opensource/r2corba.html"
    gem.authors = ['Martin Corino']
    gem.files = R2CORBA.manifest
    gem.extensions = ['Rakefile']
    gem.extra_rdoc_files = %w{LICENSE README.rdoc}
    gem.require_paths = %w{lib}
    gem.executables = %w{rins}
    if defined?(JRUBY_VERSION)
      gem.platform = Gem::Platform::JAVA
      gem.executables << 'jrins'
      gem.require_paths << 'jacorb/lib'
      gem.required_ruby_version = '>= 1.5.0'
      gem.licenses = ['Nonstandard', 'GPL-2.0']
    else
      gem.platform = Gem::Platform::CURRENT if RUBY_PLATFORM =~ /mingw32/
      gem.required_ruby_version = '>= 1.8.6'
      gem.licenses = ['Nonstandard', 'DOC', 'GPL-2.0']
      gem.require_paths << 'ext'
    end
    gem.add_dependency 'ridl', '>= 2.2.2'
  end
end

task :gemspec => :define_gemspec do
  File.open(R2CORBA.gemspec.name+'.gemspec', 'w') {|f| f.puts R2CORBA.gemspec.to_ruby}
end

namespace :r2corba do
  task :prepare do
    if RUBY_PLATFORM =~ /mingw32/
      # copy required dlls to gem install folder
      ext_inst_dir = File.join(R2CORBA.pkg_root, 'ext')
      R2CORBA.ext_dlls.each do |dll_path|
        cp(dll_path, ext_inst_dir) unless File.exist?(File.join(ext_inst_dir, File.basename(dll_path)))
      end
    elsif !defined?(JRUBY_VERSION)
      # make sure rins executable exists
      unless File.file?(File.join('bin', 'rins'))
        rins_rb = <<THE_END__
#!/usr/bin/env ruby
require 'corba/svcs/ins/ins'
INS.run
THE_END__

        File.open(File.join('bin', 'rins'), 'w') {|f|
          f.puts rins_rb
        }
        File.chmod(0755, File.join('bin', 'rins'))
      end
    end
  end
  task :clean do
    if RUBY_PLATFORM =~ /mingw32/
      # clean up copied dlls
      ext_inst_dir = File.join(R2CORBA.pkg_root, 'ext')
      R2CORBA.ext_dlls.each do |dll_path|
        rm_f(File.join(ext_inst_dir, File.basename(dll_path)))
      end
    end
  end
end

task :build => ['define_gemspec', 'r2corba:prepare'] do
  R2CORBA.build_gem

  Rake::Task['r2corba:clean'].invoke
end

task :default => :build
