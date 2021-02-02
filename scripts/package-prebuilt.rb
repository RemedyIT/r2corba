
require 'fileutils'
include FileUtils::Verbose

FILES = [
# '.config',
 'LICENSE',
 'INSTALL.prebuilt',
 'README.rdoc',
 'THANKS',
 'CHANGES',
 'acefiles.rb',
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
  'ext',
  'lib',
  'ridl',
#  'rpmbuild',
  'test',
  'example'
]

if RUBY_PLATFORM =~ /mingw32/
  pkg_cmd = 'zip -r {pkgfile}.zip'
  pkg_cmd2 = 'zip -r {pkgfile}.zip'
  exl_arg = ' -x@{xcl_path}\pkg-excludes-prebuilt-win.lst'
  so_pfx = RUBY_PLATFORM =~ /mingw32/ ? 'lib' : ''
  so_ext = '.dll'
  nul_redir = '> NUL'
  except_dll = (RUBY_PLATFORM =~ /x64/) ? 'libgcc_s_sjlj-1.dll' : 'libgcc_s_dw2-1.dll'
elsif RUBY_PLATFORM =~ /darwin/
  pkg_cmd = 'gnutar -chvf {pkgfile}.tar -X {xcl_path}/pkg-excludes-prebuilt.lst'
  pkg_cmd2 = 'gnutar -rhf {pkgfile}.tar'
  gz_cmd = 'gzip -f {pkgfile}.tar'
  so_pfx = 'lib'
  so_ext = '.dylib'
  nul_redir = '> /dev/null'
else
  pkg_cmd = 'tar -chvf {pkgfile}.tar -X {xcl_path}/pkg-excludes-prebuilt.lst'
  pkg_cmd2 = 'tar -rhf {pkgfile}.tar'
  gz_cmd = 'gzip -f {pkgfile}.tar'
  so_pfx = 'lib'
  so_ext = '.so.*'
  nul_redir = '> /dev/null'
end

script_root = File.expand_path(File.dirname(__FILE__))
pkg_root = File.dirname(script_root)
pkg_base = File.basename(pkg_root)
manifest = File.join(pkg_root, 'MANIFEST')
ver_file = File.join(pkg_root, 'lib', 'corba', 'common', 'version.rb')
pkg_dir = File.join(pkg_root, 'pkg')
ace_files = File.join(pkg_root, 'acefiles.rb')
ext_dir = File.join(pkg_root, 'ext')

CONFIG = {}
# helper method for loading 'ace_files.rb'
def get_config(k)
  CONFIG[k]
end
cfg_file = File.join(pkg_root, '.config')
File.foreach(cfg_file) do |l|
  la = l.split('=')
  CONFIG[la.first] = la.last.strip
end
CONFIG.each_value {|v| v.gsub!(%r<\$([^/]+)>) { CONFIG[$1] } }

require ver_file

require ace_files

pkg = File.join(pkg_dir, "Ruby2CORBA-#{R2CORBA::R2CORBA_VERSION}_prebuilt_#{RUBY_PLATFORM}-#{RUBY_VERSION}")
cmd = pkg_cmd.dup
SUBDIRS.each {|d|
  cmd << " #{File.join(pkg_base, d)}"
}
FILES.each {|f|
  cmd << " #{File.join(pkg_base, f)}"
}
ace_root = File.expand_path(ENV['ACE_ROOT'] || (File.directory?(File.join(pkg_root, 'ACE', 'ACE')) ? File.join(pkg_root, 'ACE', 'ACE') : File.join(pkg_root, 'ACE', 'ACE_wrappers')))
if /^#{pkg_root}/ =~ ace_root
  ace_root.gsub!(/^#{pkg_root}/, pkg_base)
end
ACE_FILES.each {|f|
  cmd << " #{File.join(ace_root, 'lib', so_pfx + f + so_ext)}"
}
if RUBY_PLATFORM =~ /win32/ || RUBY_PLATFORM =~ /mingw32/
  cmd << exl_arg
end
cmd = cmd.gsub('{pkgfile}', pkg).gsub('{xcl_path}', File.join(pkg_root, 'scripts'))

Dir.glob(pkg + '.{zip,tar.gz,tar.bz2}').each {|f| rm_f(f) if File.exist?(f) }

mkdir_p(pkg_dir) unless File.directory?(pkg_dir)

if RUBY_PLATFORM =~ /mingw32/
  ENV['PATH'].split(';').each do |p|
    if File.exist?(File.join(p, except_dll)) && File.exist?(File.join(p, 'libstdc++-6.dll'))
      cp(File.join(p, except_dll), ext_dir)
      cp(File.join(p, 'libstdc++-6.dll'), ext_dir)
      break
    end
  end
end

cur_dir = Dir.getwd
cd(File.expand_path('..', pkg_root))
begin
  puts(cmd)
  system(cmd + "| tee #{File.join(pkg_root, 'MANIFEST')}")

  cmd = pkg_cmd2.gsub('{pkgfile}', pkg)
  system(cmd + " #{File.join(pkg_base, 'MANIFEST')} #{nul_redir}")

  unless RUBY_PLATFORM =~ /win32/ || RUBY_PLATFORM =~ /mingw32/
    cmd = gz_cmd.gsub('{pkgfile}', pkg)
    puts(cmd)
    system(cmd + " #{nul_redir}")
  end
ensure
  cd(cur_dir)

  rm_f(File.join(ext_dir, 'libstdc++-6.dll')) if File.exist?(File.join(ext_dir, 'libstdc++-6.dll'))
  rm_f(File.join(ext_dir, except_dll)) if File.exist?(File.join(ext_dir, except_dll))
end
