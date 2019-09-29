require 'rubygems'
begin
  require 'rubygems/builder'
rescue LoadError
  require 'rubygems/package'
end

require './lib/taosource/version'

module TAOGem
  @@gemspec = nil

  def self.define_spec(name, version, &block)
    @@gemspec = Gem::Specification.new(name,version)
    @@gemspec.required_rubygems_version = Gem::Requirement.new(">= 0") if @@gemspec.respond_to? :required_rubygems_version=
    block.call(@@gemspec)
    @@gemspec
  end

  def self.gemspec
    @@gemspec
  end

  def self.build_gem
    if defined?(Gem::Builder)
      gem_file_name = Gem::Builder.new(gemspec).build
    else
      gem_file_name = Gem::Package.build(gemspec)
    end

    FileUtils.mkdir_p('pkg')

    FileUtils.mv(gem_file_name, 'pkg')
  end
end

task :define_gemspec do
  TAOGem.define_spec('taosource', TAOGem::VERSION) do |gem|
    gem.summary = %Q{TAO sourcecode for building R2CORBA}
    gem.description = %Q{TAO sourcecode for building R2CORBA}
    gem.email = 'mcorino@remedy.nl'
    gem.homepage = "https://www.remedy.nl/products/r2corba.html"
    gem.authors = ['Martin Corino']
    gem.files = Dir['lib/**/*']
    gem.files.concat(Dir["src/ACE+TAO-src-#{TAOGem::VERSION}.tar.gz"])
    gem.files << 'Rakefile'
    gem.extensions = ['Rakefile']
    gem.require_paths = %w{lib}
    gem.executables = []
    #gem.platform = Gem::Platform::CURRENT
    gem.required_ruby_version = '>= 1.8.6'
    gem.licenses = ['ACE']
  end
end

task :gemspec => :define_gemspec do
  File.open(TAOGem.gemspec.name+'.gemspec', 'w') {|f| f.puts TAOGem.gemspec.to_ruby}
end

task :build => :define_gemspec do
  TAOGem.build_gem
end

task :default => :build
