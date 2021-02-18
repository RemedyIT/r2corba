#--------------------------------------------------------------------
# ext_r2tao.rb - build file
#
# Author: Martin Corino
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the R2CORBA LICENSE which is
# included with this program.
#
# Copyright (c) Remedy IT Expertise BV
#--------------------------------------------------------------------

require 'open-uri'

module R2CORBA

  module Ext

    if RUBY_PLATFORM =~ /mingw32/

      mpc_os_block = <<OS_DEP__
  libs += #{File.basename(RB_CONFIG['LIBRUBY'], '.a').sub(/^lib/, '')}
  libout = .
  dllout = .
  verbatim(gnuace, macros, 1) {
    override SOEXT := #{RB_CONFIG['DLEXT']}
  }
  postbuild  = <%cp%> lib<%sharedname%>.so ..<%slash%>
  postclean  = <%rm%> ..<%slash%>lib<%sharedname%>.so
OS_DEP__

    elsif RUBY_PLATFORM =~ /darwin/

      mpc_os_block = <<OS_DEP__
  specific(gnuace) {
    linkflags += "#{RB_CONFIG['LIBRUBYARG_SHARED']}"
  }
  libout = .
  dllout = .
  specific(gnuace) {
    linkflags += -headerpad_max_install_names
  }
  postbuild  = ln -s -f lib<%sharedname%>.dylib lib<%sharedname%>.bundle
  postbuild += ln -s -f lib<%sharedname%>.dylib ..<%slash%>lib<%sharedname%>.bundle
  postclean  = <%rm%> lib<%sharedname%>.bundle
  postclean += <%rm%> ..<%slash%>lib<%sharedname%>.bundle
OS_DEP__

    else

      mpc_os_block = <<OS_DEP__
  specific(gnuace) {
    linkflags += "#{RB_CONFIG['LIBRUBYARG_SHARED']}"
    linkflags += -Wl,-rpath,#{get_config('aceinstdir')}
  }
  libout = .
  dllout = ..
OS_DEP__

    end

    R2TAO_MPC = <<THE_END
project : taolib, portableserver, anytypecode, dynamicany, dynamicinterface, typecodefactory {
  Source_Files {
    required.cpp
    object.cpp
    orb.cpp
    exception.cpp
    typecode.cpp
    any.cpp
    longdouble.cpp
    values.cpp
  }
  dynamicflags = R2TAO_BUILD_DLL
  includes += "#{RB_CONFIG['rubyhdrdir'] || RB_CONFIG['archdir']}" \\
              #{RB_CONFIG['rubyhdrdir'] ? '"' + File.join(RB_CONFIG['rubyhdrdir'], RB_CONFIG['arch']) + '"' : ''} \\
              .
  macros += RUBY_VER_MAJOR=#{Config.rb_ver_major} RUBY_VER_MINOR=#{Config.rb_ver_minor} RUBY_VER_RELEASE=#{Config.rb_ver_release}
  sharedname = r2tao
  libpaths += "#{RB_CONFIG['libdir']}"
  #{mpc_os_block}
}
THE_END

    RPOA_MPC = <<THE_END
project : taolib, portableserver, anytypecode, dynamicany, dynamicinterface, typecodefactory, iortable {
  after += r2tao
  Source_Files {
    poa.cpp
    servant.cpp
    iortable.cpp
  }
  dynamicflags = R2TAO_POA_BUILD_DLL
  libpaths += #{File.join('..', 'libr2tao')}
  includes += "#{RB_CONFIG['rubyhdrdir'] || RB_CONFIG['archdir']}" \\
               #{RB_CONFIG['rubyhdrdir'] ? '"' + File.join(RB_CONFIG['rubyhdrdir'], RB_CONFIG['arch']) + '"' : ''} \\
               #{File.join('..', 'libr2tao')} \\
               .
  macros += RUBY_VER_MAJOR=#{Config.rb_ver_major} RUBY_VER_MINOR=#{Config.rb_ver_minor} RUBY_VER_RELEASE=#{Config.rb_ver_release}
  sharedname = rpoa
  libpaths += "#{RB_CONFIG['libdir']}"
  #{mpc_os_block}
  libs += r2tao#{Config.is_win32 ? '.' + RB_CONFIG['DLEXT'] : ''}
}
THE_END

    RPOL_MPC = <<THE_END
project : taolib, portableserver, anytypecode, dynamicany, dynamicinterface, typecodefactory, bidir_giop {
  after += r2tao rpoa
  Source_Files {
    policies.cpp
  }
  dynamicflags = R2TAO_POL_BUILD_DLL
  libpaths += #{File.join('..', 'libr2tao')} #{File.join('..', 'librpoa')}
  includes += "#{RB_CONFIG['rubyhdrdir'] || RB_CONFIG['archdir']}" \\
               #{RB_CONFIG['rubyhdrdir'] ? '"' + File.join(RB_CONFIG['rubyhdrdir'], RB_CONFIG['arch']) + '"' : ''} \\
               #{File.join('..', 'libr2tao')} \\
               #{File.join('..', 'librpoa')} \\
               .
  macros += RUBY_VER_MAJOR=#{Config.rb_ver_major} RUBY_VER_MINOR=#{Config.rb_ver_minor} RUBY_VER_RELEASE=#{Config.rb_ver_release}
  sharedname = rpol
  libpaths += "#{RB_CONFIG['libdir']}"
  #{mpc_os_block}
  libs += r2tao#{Config.is_win32 ? '.' + RB_CONFIG['DLEXT'] : ''}
  libs += rpoa#{Config.is_win32 ? '.' + RB_CONFIG['DLEXT'] : ''}
}
THE_END


    def self.r2tao_mpc_file
      File.join('ext', 'libr2tao', 'r2tao.mpc')
    end

    def self.rpoa_mpc_file
      File.join('ext', 'librpoa', 'rpoa.mpc')
    end

    def self.rpol_mpc_file
      File.join('ext', 'librpol', 'rpol.mpc')
    end

    if Config.is_win32

      EXTLOAD_MPC = <<THE_END__
project {
  Source_Files {
    extload.c
  }
  dynamicflags = EXTLOAD_BUILD_DLL
  sharedname = extload
  libout = .
  dllout = .
  verbatim(gnuace, macros, 1) {
    override SOEXT := #{RB_CONFIG['DLEXT']}
  }
  postbuild  = <%cp%> lib<%sharedname%>.so ..<%slash%>libr2taow.so
  postbuild += <%cp%> lib<%sharedname%>.so ..<%slash%>librpoaw.so
  postbuild += <%cp%> lib<%sharedname%>.so ..<%slash%>librpolw.so
  postclean  = <%rm%> ..<%slash%>libr2taow.so
  postclean += <%rm%> ..<%slash%>librpoaw.so
  postclean += <%rm%> ..<%slash%>librpolw.so
}
THE_END__

      def self.extload_mpc_file
        File.join('ext', 'extload', 'extload.mpc')
      end

      def self.extload_makefile
        File.join('ext', 'extload', 'GNUmakefile')
      end

    end

    def self.get_latest_ace_version
      print 'Latest ACE release is '
      _version = nil
      open('https://raw.githubusercontent.com/DOCGroup/ACE_TAO/master/ACE/ace/Version.h') do |f|
        f.each_line do |ln|
          if /define\s+ACE_VERSION\s+\"(.*)\"/ =~ ln
            _version = $1
          end
        end
      end
      puts _version
      _version
    end

    # Downloading from github results in some http redirects which we first have to follow
    def self.follow_url(uri_str, limit = 10)
      raise ArgumentError, 'HTTP redirect too deep' if limit == 0
      url = URI(uri_str)
      req = Net::HTTP::Get.new(url)
      response = Net::HTTP.start(url.host, url.port, use_ssl: true) { |http| http.request(req) }
      case response
      when Net::HTTPSuccess     then uri_str
      when Net::HTTPRedirection then follow_url(response['location'], limit - 1)
      else
        response.error!
      end
    end

    def self.download_tao_source(version, targetdir)
      version_dir = version.gsub('.', '_')
      _url = "https://github.com/DOCGroup/ACE_TAO/releases/download/ACE%2BTAO-#{version_dir}/ACE+TAO-src-#{version}.tar.gz"
      print(_msg = "Downloading ACE+TAO-src-#{version}.tar.gz from #{_url}")
      _fnm = File.join(targetdir, "ACE+TAO-src-#{version}.tar.gz")
      # First follow all http redirects
      url = URI(follow_url(_url))
      Net::HTTP.start(url.host, url.port, use_ssl: true) do |http|
       _fout = File.open(_fnm, "wb")
        begin
          http.request_get(url) do |resp|
            _sndlen =  resp.content_length
            _reclen = 0
            resp.read_body do |segment|
              _fout.write(segment)
              if _sndlen
                _reclen += segment.size
                print "\r#{_msg} #{_reclen * 100 / _sndlen}\%"
              else
                print '#'
              end
            end
          end
        ensure
          _fout.close()
          puts
        end
      end
      FileUtils::Verbose.sh("rm -rf #{File.join(targetdir, 'ACE_wrappers')} && tar -xzf #{_fnm} -C #{targetdir}")
      FileUtils::Verbose.sh("rm -f #{_fnm} && tar --format=gnu -czf #{_fnm} -C src ACE_wrappers")
    end

    def self.ext_shlibs
      (if Config.is_win32
        %w{libr2taow librpoaw librpolw}
      else
        %w{libr2tao librpoa librpol}
      end).collect {|lib| File.join('ext', lib + '.so') }
    end

  end

end
