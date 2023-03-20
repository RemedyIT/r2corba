#!/bin/sh
./ridlc --ignore-pidl --output lib/corba/idl/r2c_orb.rb --namespace=R2CORBA --include=lib/idl --stubs-only --expand-includes --search-includepath --no-libinit --interface-as-class=TypeCode orb.idl
./ridlc --output lib/corba/idl/POAC.rb --namespace=R2CORBA --include=lib/idl --stubs-only --expand-includes --search-includepath --no-libinit PortableServer.pidl
./ridlc --output lib/corba/idl/MessagingC.rb --namespace=R2CORBA --include=lib/idl --stubs-only --expand-includes --search-includepath --no-libinit Messaging.pidl
./ridlc --output lib/corba/idl/BiDirPolicyC.rb --namespace=R2CORBA --include=lib/idl --stubs-only --expand-includes --search-includepath --no-libinit BiDirPolicy.pidl

./ridlc --output lib/corba/idl/TAO_ExtC.rb --namespace=R2CORBA --include=lib/idl --stubs-only --expand-includes --search-includepath --no-libinit TAO_Ext.pidl
./ridlc --output lib/corba/idl/IORTableC.rb --namespace=R2CORBA --include=$ACE_ROOT/TAO --stubs-only --expand-includes --search-includepath --no-libinit tao/IORTable/IORTable.pidl
