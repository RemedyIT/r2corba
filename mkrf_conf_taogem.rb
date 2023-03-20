#--------------------------------------------------------------------
# mkrf_conf_taogem.rb - Rakefile generator taosource gem installation
#
# Author: Martin Corino
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the R2CORBA LICENSE which is
# included with this program.
#
# Copyright (c) Remedy IT Expertise BV
#--------------------------------------------------------------------

# generate Rakefile with empty default task
File.open('Rakefile', 'w') do |f|
  f.puts <<EOF__
#--------------------------------------------------------------------
# Rakefile - build file for taosource installation
#
# Author: Martin Corino
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the R2CORBA LICENSE which is
# included with this program.
#
# Copyright (c) Remedy IT Expertise BV
#--------------------------------------------------------------------

task :default
EOF__
end

require 'fileutils'
require 'rubygems'
require 'rubygems/package'

# unpack TAO source archive
src_root = File.expand_path(File.join(File.dirname(__FILE__), 'src'))
src_pkg = Dir[File.join(src_root, 'ACE+TAO-src*.tar.gz')].first
curdir = Dir.getwd
begin
  Dir.chdir src_root
  puts 'Unpacking source archive. Please wait, this could take a while...'
  # following code has been nicked from RubyGems
  File.open src_pkg, 'rb' do |io|
    Zlib::GzipReader.wrap io do |gzio|
      tar = Gem::Package::TarReader.new gzio
      tar.each do |entry|
        if entry.file?
          raise "Failed to extract #{src_pkg}: invalid source path #{entry.full_name}" if entry.full_name.start_with? '/'

          destination = File.join src_root, entry.full_name
          destination = File.expand_path destination

          raise "Failed to extract #{src_pkg}: invalid destination path #{destination}" unless destination.start_with? src_root

          destination.untaint

          FileUtils.rm_rf destination

          FileUtils.mkdir_p File.dirname destination

          open destination, 'wb', entry.header.mode do |out|
            out.write entry.read
            out.fsync rescue nil # for filesystems without fsync(2)
          end

          puts destination
        end
      end
    end
  end
ensure
  Dir.chdir curdir
end
