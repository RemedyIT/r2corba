set R2CORBA_ROOT=%~dp0
for /F "usebackq" %%i in (`ruby -e "puts ARGV.first.gsub('\\', '/')" %R2CORBA_ROOT%`) do @set R2CORBA_ROOT=%%i
if exist %R2CORBA_ROOT%ACE/ACE_wrappers goto atcdold
set ACE_ROOT=%R2CORBA_ROOT%ACE/ACE
set ATCD_ROOT=%R2CORBA_ROOT%ACE
goto envrest
:atcdold
set ACE_ROOT=%R2CORBA_ROOT%ACE/ACE_wrappers
set ATCD_ROOT=%R2CORBA_ROOT%ACE/ACE_wrappers
:envrest
set TAO_ROOT=%ATCD_ROOT%/TAO
set MPC_ROOT=%ATCD_ROOT%/MPC
set ATCD_ROOT=
set PATH=%PATH%;%R2CORBA_ROOT%\bin;%ACE_ROOT%\bin;%ACE_ROOT%\lib
set RUBYLIB=.;%R2CORBA_ROOT%lib;%R2CORBA_ROOT%ridl/lib;%R2CORBA_ROOT%ext;%R2CORBA_ROOT%ext/libr2tao;%R2CORBA_ROOT%ext/librpoa;%R2CORBA_ROOT%ext/librpol;%R2CORBA_ROOT%test
