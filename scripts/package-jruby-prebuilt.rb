
require 'fileutils'
include FileUtils::Verbose

FILES = [
# '.config',
 'LICENSE',
 'INSTALL.jruby-prebuilt',
 'README.rdoc',
 'THANKS',
 'CHANGES',
# 'acefiles.rb',
 'metaconfig',
# 'post-distclean.rb',
 'post-install.rb',
 'post-setup.rb',
 'pre-config.rb',
 'pre-test.rb',
 'setup.rb'
]

SUBDIRS = [
  'bin',
#  'ext',
  'lib',
  'ridl',
  File.join('jacorb', 'lib'),
#  'rpmbuild',
  'test',
  'example'
]

pkg_cmd = 'tar -chvf {pkgfile}.tar -X {xcl_path}/pkg-excludes-jruby-prebuilt.lst'
pkg_cmd2 = 'tar -rhf {pkgfile}.tar'
gz_cmd = 'gzip -f -c {pkgfile}.tar > {pkgfile}.tar.gz'
bz2_cmd = 'bzip2 -f {pkgfile}.tar'
zip_cmd = 'zip -r {pkgfile}.zip'
nul_redir = '> /dev/null'

script_root = File.expand_path(File.dirname(__FILE__))
pkg_root = File.dirname(script_root)
pkg_base = File.basename(pkg_root)
manifest = File.join(pkg_root, 'MANIFEST')
ver_file = File.join(pkg_root,'lib','corba','common','version.rb')
pkg_dir = File.join(pkg_root, 'pkg')

require ver_file

pkg = File.join(pkg_dir, "Ruby2CORBA-#{R2CORBA::R2CORBA_VERSION}_prebuilt_java")

Dir.glob(pkg+'.{zip,tar.gz,tar.bz2}').each {|f| rm_f(f) if File.exist?(f) }

mkdir_p(pkg_dir) unless File.directory?(pkg_dir)

cur_dir = Dir.getwd
cd(File.expand_path('..', pkg_root))
begin
  cmd = pkg_cmd.gsub('{xcl_path}',File.join(pkg_base, 'scripts')).gsub('{pkgfile}', pkg)
  SUBDIRS.each {|d|
    cmd << " #{File.join(pkg_base, d)}"
  }
  FILES.each {|f|
    cmd << " #{File.join(pkg_base, f)}"
  }
  puts(cmd)
  system(cmd+"| tee #{manifest}")

  cmd = pkg_cmd2.gsub('{pkgfile}', pkg)
  system(cmd + " #{File.join(pkg_base, 'MANIFEST')} #{nul_redir}")

  cmd = gz_cmd.gsub('{pkgfile}', pkg)
  puts(cmd)
  system(cmd)
  cmd = bz2_cmd.gsub('{pkgfile}', pkg)
  puts(cmd)
  system(cmd + " #{nul_redir}")

  cmd = zip_cmd.gsub('{pkgfile}', pkg)
  cmd << " #{pkg_base} -i #{File.join(pkg_base, 'MANIFEST')} -i@#{manifest}"
  puts(cmd)
  system(cmd+" #{nul_redir}")

ensure
  cd(cur_dir)
end
