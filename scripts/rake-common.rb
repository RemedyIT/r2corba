require 'rubygems'
begin
  require 'rubygems/builder'
rescue LoadError
  require 'rubygems/package'
end

unless defined?(JRUBY_VERSION)
  CONFIG = {}
# helper method for loading 'ace_files.rb'
  def get_config(k)
    CONFIG[k]
  end
  File.foreach('.config') do |l|
    la = l.split('=')
    CONFIG[la.first] = la.last.strip
  end
  CONFIG.each_value {|v| v.gsub!(%r<\$([^/]+)>) { CONFIG[$1] } }
  require './acefiles.rb'
end

module R2CORBA

  unless defined?(JRUBY_VERSION)
    ACE_FILES = ::ACE_FILES
  end

  @@pkg_root = nil
  @@ace_root = nil

  def self.pkg_root
    @@pkg_root = File.dirname(File.expand_path(File.dirname(__FILE__)))
  end

  def self.ace_root
    @@ace_root ||= File.expand_path(ENV['ACE_ROOT'] || (File.directory?(File.join(pkg_root, 'ACE', 'ACE')) ? File.join(pkg_root, 'ACE', 'ACE') : File.join(pkg_root, 'ACE', 'ACE_wrappers')))
  end

  if RUBY_PLATFORM =~ /mingw32/
    SYS_DLL = []
    except_dll = (RUBY_PLATFORM =~ /x64/) ? 'libgcc_s_sjlj-1.dll' : 'libgcc_s_dw2-1.dll'
    ENV['PATH'].split(';').each do |p|
      if File.exist?(File.join(p, except_dll)) && File.exist?(File.join(p, 'libstdc++-6.dll'))
        SYS_DLL << File.join(p, except_dll)
        SYS_DLL << File.join(p, 'libstdc++-6.dll')
        break
      end
    end

    @@ext_dlls = nil

    def self.ext_dlls
      unless @@ext_dlls
        @@ext_dlls = []
        # collect required dll paths
        @@ext_dlls.concat(R2CORBA::ACE_FILES.collect {|fn| File.join(R2CORBA.ace_root, 'lib', "lib#{fn}.dll") })
        @@ext_dlls.concat(Dir[File.join(R2CORBA.pkg_root, 'ext', '*.so')])
        @@ext_dlls.concat(R2CORBA::SYS_DLL)
      end
      @@ext_dlls
    end
  end

  @@manifest = nil

  def self.manifest
    # create MANIFEST list with included files
    unless @@manifest
      @@manifest = []
      if defined?(JRUBY_VERSION) || RUBY_PLATFORM =~ /mingw32/
        @@manifest.concat Dir.glob(File.join('bin', '*.[^r]*'))
        if defined?(JRUBY_VERSION)
          @@manifest.concat(Dir.glob(File.join('jacorb', 'lib', '*.jar')).select do |fnm|
            !%w{idl jacorb-sources picocontainer wrapper}.any? {|nm| /^#{nm}/ =~ File.basename(fnm) }
          end)
        else
          @@manifest.concat R2CORBA.ext_dlls.collect { |fnm| File.join('ext', File.basename(fnm)) }
        end
        @@manifest.concat(Dir.glob(File.join('lib', '**', '*')).select {|fnm| File.basename(fnm) != 'pre-install.rb' })
        @@manifest.concat Dir.glob(File.join('test', '**', '*'))
        @@manifest.concat %w{LICENSE README.rdoc THANKS CHANGES Rakefile metaconfig post-setup.rb pre-config.rb pre-test.rb setup.rb}
      else
        @@manifest.concat Dir['bin/*.rb']
        @@manifest.concat Dir['ext/**/*.{rb,c,cpp,h,mpc,mwc}']
        @@manifest.concat Dir['lib/**/*[^C].*']
        @@manifest.concat Dir['test/**/*.*']
        @@manifest.concat %w{LICENSE README.rdoc THANKS CHANGES Rakefile acefiles.rb metaconfig}
        @@manifest.concat %w{post-setup.rb pre-config.rb pre-test.rb setup.rb}
      end
    end
    @@manifest
  end

  @@gemspec = nil

  def self.define_spec(name, version, &block)
    @@gemspec = Gem::Specification.new(name, version)
    @@gemspec.required_rubygems_version = Gem::Requirement.new('>= 0') if @@gemspec.respond_to? :required_rubygems_version=
    block.call(@@gemspec)
    @@gemspec
  end

  def self.gemspec
    @@gemspec
  end

  def self.build_gem
    if defined?(Gem::Builder)
      gem_file_name = Gem::Builder.new(R2CORBA.gemspec).build
    else
      gem_file_name = Gem::Package.build(R2CORBA.gemspec)
    end

    pkg_dir = File.join(R2CORBA.pkg_root, 'pkg')
    FileUtils.mkdir_p(pkg_dir)

    gem_file_name = File.join(R2CORBA.pkg_root, gem_file_name)
    FileUtils.mv(gem_file_name, pkg_dir)
  end
end
