
FILES = [
 'LICENSE',
 'INSTALL',
 'INSTALL.jruby',
 'README.rdoc',
 'THANKS',
 'CHANGES',
 'acefiles.rb',
 'metaconfig',
 'post-distclean.rb',
 'post-install.rb',
 'post-setup.rb',
 'pre-config.rb',
 'pre-test.rb',
 'setup.rb'
]

SUBDIRS = [
  'bin',
  'ext',
  'lib',
  'ridl',
  'rpmbuild',
  'test',
  'example'
]

script_root = File.expand_path(File.dirname(__FILE__))
pkg_root = File.dirname(script_root)
pkg_base = File.basename(pkg_root)
manifest = File.join(pkg_root, 'MANIFEST')
ver_file = File.join(pkg_root,'lib','corba','common','version.rb')
pkg_dir = File.join(pkg_root, 'pkg')
Dir.mkdir(pkg_dir) unless File.directory?(pkg_dir)
require ver_file
pkg = File.join(pkg_dir, "Ruby2CORBA-#{R2CORBA::R2CORBA_VERSION}.tar")
cmd = "tar -cvf #{pkg}"
cmd << " -X #{File.join(script_root, 'pkg-excludes.lst')} --exclude-vcs --exclude-backups"
SUBDIRS.each {|d|
  cmd << " #{File.join(pkg_base, d)}"
}
FILES.each {|f|
  cmd << " #{File.join(pkg_base, f)}"
}

File.delete(pkg) if File.exists?(pkg)
File.delete("#{pkg}.gz") if File.exists?("#{pkg}.gz")
File.delete("#{pkg}.bz2") if File.exists?("#{pkg}.bz2")
cur_dir = Dir.getwd
Dir.chdir(File.expand_path('..', pkg_root))
begin
  puts(cmd)
  system(cmd+' > '+ manifest)
  puts("tar --append -vf #{pkg} #{File.join(pkg_base, 'MANIFEST')}")
  system("tar --append -vf #{pkg} #{File.join(pkg_base, 'MANIFEST')} > /dev/null")
  puts("gzip #{pkg}")
  system("gzip -c #{pkg} > #{pkg}.gz")
  puts("bzip2 #{pkg}")
  system("bzip2 #{pkg}")
ensure
  Dir.chdir(cur_dir)
end

pkg = File.join(pkg_root, 'pkg', "Ruby2CORBA-#{R2CORBA::R2CORBA_VERSION}.zip")
cmd = "zip -r #{pkg}"
SUBDIRS.each {|d|
  cmd << " #{File.join(pkg_base, d)}"
}
(FILES + ['MANIFEST']).each {|f|
  cmd << " #{File.join(pkg_base, f)}"
}
cmd << " -x@#{File.join(script_root, 'pkg-excludes.lst')}"

File.delete(pkg) if File.exists?(pkg)
cur_dir = Dir.getwd
Dir.chdir(File.expand_path('..', pkg_root))
begin
  puts(cmd)
  system(cmd+'> /dev/null')
ensure
  Dir.chdir(cur_dir)
end
