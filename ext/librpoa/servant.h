/*--------------------------------------------------------------------
# servant.h - R2TAO CORBA Servant support
#
# Author: Martin Corino
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the R2CORBA LICENSE which is
# included with this program.
#
# Copyright (c) Remedy IT Expertise BV
# Chamber of commerce Rotterdam nr.276339, The Netherlands
#------------------------------------------------------------------*/

#if ((TAO_MAJOR_VERSION < 2) || (TAO_MAJOR_VERSION == 2 && TAO_MINOR_VERSION == 0 && TAO_BETA_VERSION <= 1))
# define RPOA_NEED_DSI_FIX  1

# include "srvreq_fix.h"

# define R2CORBA_ServerRequest  R2CORBA::ServerRequest
# define R2CORBA_ServerRequest_ptr  R2CORBA::ServerRequest_ptr
#else
# define R2CORBA_ServerRequest  CORBA::ServerRequest
# define R2CORBA_ServerRequest_ptr  CORBA::ServerRequest_ptr
#endif

//-------------------------------------------------------------------
//  R2TAO Servant class
//
//===================================================================

class DSI_Servant : public PortableServer::DynamicImplementation
{
public:
  DSI_Servant (VALUE rbServant);
  // ctor
  virtual ~DSI_Servant ();
  // dtor

  virtual void invoke (CORBA::ServerRequest_ptr request);
      //ACE_THROW_SPEC ((CORBA::SystemException));
#if RPOA_NEED_DSI_FIX
  void invoke_fix (R2CORBA::ServerRequest_ptr request);
#endif

  virtual CORBA::RepositoryId _primary_interface (
      const PortableServer::ObjectId &oid,
      PortableServer::POA_ptr poa);

  virtual CORBA::Boolean _is_a (const char *logical_type_id);

  virtual CORBA::Boolean _non_existent (void);

  //virtual CORBA::InterfaceDef_ptr _get_interface (void);

  virtual CORBA::Object_ptr _get_component (void);

  virtual char * _repository_id (void);

  enum METHOD {
    NONE,
    IS_A,
    NON_EXISTENT,
    GET_INTERFACE,
    GET_COMPONENT,
    REPOSITORY_ID
  };

  VALUE rbServant () {
    return this->rbServant_;
  }

  void free_servant ();

  void activate_servant ();

protected:
  virtual const char *_interface_repository_id (void) const;

#if RPOA_NEED_DSI_FIX
  /// Turns around and calls invoke.
  virtual void _dispatch (TAO_ServerRequest &request, void *context);
#endif

  void register_with_servant ();

  void cleanup_servant ();
  void inner_cleanup_servant ();

  METHOD  method_id (const char* method);

  virtual void inner_invoke (R2CORBA_ServerRequest_ptr request);

  void invoke_SI (R2CORBA_ServerRequest_ptr request);
  void invoke_DSI (R2CORBA_ServerRequest_ptr request);

  static VALUE _invoke_implementation(VALUE args);

private:
  VALUE rbServant_;
  // The Ruby Servant

  CORBA::String_var repo_id_;

  struct ThreadSafeArg
  {
    ThreadSafeArg (DSI_Servant* srv,
                   R2CORBA_ServerRequest_ptr req)
      : servant_(srv), request_(req) {}
    DSI_Servant* servant_;
    R2CORBA_ServerRequest_ptr request_;
  };

  static void* thread_safe_invoke (void * arg);
  static void* thread_safe_cleanup (void* arg);
};

