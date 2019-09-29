./jridlc --ignore-pidl --output lib/corba/idl/r2c_orb.rb --namespace=R2CORBA --include=lib/idl --stubs-only --expand-includes --search-includepath --no-libinit --interface-as-class=TypeCode orb.idl
./jridlc --output lib/corba/idl/POAC.rb --namespace=R2CORBA --include=lib/idl --stubs-only --expand-includes --search-includepath --no-libinit PortableServer.pidl
./jridlc --output lib/corba/idl/MessagingC.rb --namespace=R2CORBA --include=lib/idl --stubs-only --expand-includes --search-includepath --no-libinit Messaging.pidl
./jridlc --output lib/corba/idl/BiDirPolicyC.rb --namespace=R2CORBA --include=lib/idl --stubs-only --expand-includes --search-includepath --no-libinit BiDirPolicy.pidl
