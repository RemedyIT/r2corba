/*--------------------------------------------------------------------
# servant.cpp - R2TAO CORBA Servant support
#
# Author: Martin Corino
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the R2CORBA LICENSE which is
# included with this program.
#
# Copyright (c) Remedy IT Expertise BV
#------------------------------------------------------------------*/

#include "poa.h"
#include "ace/Auto_Ptr.h"
#include "tao/DynamicInterface/Server_Request.h"
#include "tao/DynamicInterface/Dynamic_Implementation.h"
#include "tao/AnyTypeCode/Any.h"
#include "tao/AnyTypeCode/NVList.h"
#include "tao/ORB.h"
#include "tao/Exception.h"
#include "tao/TSS_Resources.h"
#include "tao/PortableServer/POA_Current_Impl.h"
#include "typecode.h"
#include "object.h"
#include "exception.h"
#include "orb.h"
#include "servant.h"

#if RPOA_NEED_DSI_FIX
# include "srvreq_fix.cpp"
#endif

#define RUBY_INVOKE_FUNC RUBY_ALLOC_FUNC

VALUE r2tao_cServant;
static VALUE r2tao_cDynamicImp;
static VALUE r2tao_cServerRequest;

static int r2tao_IN_ARG;
static int r2tao_INOUT_ARG;
static int r2tao_OUT_ARG;

static ID invoke_ID;
static ID primary_interface_ID;

static ID repo_Id;
static ID repo_Ids;
static ID get_operation_sig_ID;
static ID include_ID;

static ID interface_repository_id_ID;

static R2TAO_RBFuncall FN_narrow ("_narrow");

static VALUE ID_arg_list;
static VALUE ID_result_type;
static VALUE ID_exc_list;
static VALUE ID_op_sym;

static VALUE r2tao_Servant_default_POA(VALUE self);
static VALUE r2tao_Servant_this(VALUE self);

static VALUE r2tao_ServerRequest_operation(VALUE self);
static VALUE r2tao_ServerRequest_describe(VALUE self, VALUE desc);
static VALUE r2tao_ServerRequest_arguments(VALUE self);
static VALUE r2tao_ServerRequest_get(VALUE self, VALUE key);
static VALUE r2tao_ServerRequest_set(VALUE self, VALUE key, VALUE val);

static VALUE srv_alloc(VALUE klass);
static void srv_free(void* ptr);

void r2tao_init_Servant()
{
  VALUE klass;

  r2tao_cServant = klass = rb_eval_string("::R2CORBA::PortableServer::Servant");
  rb_define_alloc_func (r2tao_cServant, RUBY_ALLOC_FUNC (srv_alloc));
  rb_define_method(klass, "_default_POA", RUBY_METHOD_FUNC(r2tao_Servant_default_POA), 0);
  rb_define_method(klass, "_this", RUBY_METHOD_FUNC(r2tao_Servant_this), 0);

  r2tao_cServerRequest = klass = rb_define_class_under (r2tao_nsCORBA, "ServerRequest", rb_cObject);
  rb_define_method(klass, "operation", RUBY_METHOD_FUNC(r2tao_ServerRequest_operation), 0);
  rb_define_method(klass, "describe", RUBY_METHOD_FUNC(r2tao_ServerRequest_describe), 1);
  rb_define_method(klass, "arguments", RUBY_METHOD_FUNC(r2tao_ServerRequest_arguments), 0);
  rb_define_method(klass, "[]", RUBY_METHOD_FUNC(r2tao_ServerRequest_get), 1);
  rb_define_method(klass, "[]=", RUBY_METHOD_FUNC(r2tao_ServerRequest_set), 2);

  ID_arg_list = rb_eval_string (":arg_list");
  ID_result_type = rb_eval_string (":result_type");
  ID_exc_list = rb_eval_string (":exc_list");
  ID_op_sym = rb_eval_string (":op_sym");

  repo_Id = rb_intern ("Id");
  repo_Ids = rb_intern ("Ids");
  get_operation_sig_ID = rb_intern("get_operation_signature");
  include_ID = rb_intern ("include?");

  interface_repository_id_ID = rb_intern ("_interface_repository_id");

  r2tao_cDynamicImp = klass = rb_eval_string("::R2CORBA::PortableServer::DynamicImplementation");

  invoke_ID = rb_intern ("invoke");
  primary_interface_ID = rb_intern ("_primary_interface");

  r2tao_IN_ARG = NUM2INT (rb_eval_string ("R2CORBA::CORBA::ARG_IN"));
  r2tao_INOUT_ARG = NUM2INT (rb_eval_string ("R2CORBA::CORBA::ARG_INOUT"));
  r2tao_OUT_ARG = NUM2INT (rb_eval_string ("R2CORBA::CORBA::ARG_OUT"));
}

//-------------------------------------------------------------------
//  R2TAO CORBA ServerRequest native data structure
//
//===================================================================

struct DSI_Data {
  R2CORBA_ServerRequest_ptr  _request;
  CORBA::NVList_ptr _nvlist;
  CORBA::TypeCode_var _result_type;
  VALUE _rData;

  DSI_Data(R2CORBA_ServerRequest_ptr _req)
    : _request(_req), _nvlist(0), _rData(Qnil) {}
  ~DSI_Data() {
    if (this->_rData!=Qnil) { DATA_PTR(this->_rData) = 0; }
  }
};

//-------------------------------------------------------------------
//  R2TAO CORBA ServerRequest methods
//
//===================================================================

VALUE r2tao_ServerRequest_operation(VALUE self)
{
  if (DATA_PTR (self) != 0)
  {
    R2CORBA_ServerRequest_ptr request = static_cast<DSI_Data*> (DATA_PTR (self))->_request;
    return rb_str_new2 (request->operation ());
  }
  return Qnil;
}

VALUE r2tao_ServerRequest_describe(VALUE self, VALUE desc)
{
  if (DATA_PTR (self) != 0)
  {
    DSI_Data* dsi_data = static_cast<DSI_Data*> (DATA_PTR (self));

    // only allowed once
    if (CORBA::NVList::_nil () != dsi_data->_nvlist)
    {
      X_CORBA (BAD_INV_ORDER);
    }

    R2CORBA_ServerRequest_ptr request = dsi_data->_request;

    if (desc != Qnil && rb_type (desc) == T_HASH)
    {
      // check desc and create argument list for ORB
      VALUE arg_list = rb_hash_aref (desc, ID_arg_list);
      if (arg_list != Qnil && rb_type (arg_list) != T_ARRAY)
      {
        X_CORBA(BAD_PARAM);
      }
      VALUE result_type = rb_hash_aref (desc, ID_result_type);
      if (result_type != Qnil && rb_obj_is_kind_of(result_type, r2corba_cTypeCode) != Qtrue)
      {
        X_CORBA(BAD_PARAM);
      }

      CORBA::ORB_ptr _orb = request->_tao_server_request ().orb ();

      R2TAO_TRY
      {
        _orb->create_list (0, dsi_data->_nvlist);
      }
      R2TAO_CATCH;

      long arg_len =
          arg_list == Qnil ? 0 : RARRAY_LEN (arg_list);
      for (long arg=0; arg<arg_len ;++arg)
      {
        VALUE argspec = rb_ary_entry (arg_list, arg);
        if (argspec != Qnil && rb_type (argspec) != T_ARRAY)
        {
          X_CORBA(BAD_PARAM);
        }
        VALUE argname = rb_ary_entry (argspec, 0);
        if (argname != Qnil && rb_obj_is_kind_of(argname, rb_cString)==Qfalse)
        {
          X_CORBA(BAD_PARAM);
        }
        char *_arg_name = argname != Qnil ? RSTRING_PTR (argname) : 0;
        int _arg_type = NUM2INT (rb_ary_entry (argspec, 1));
        VALUE arg_rtc = rb_ary_entry (argspec, 2);
        if (rb_obj_is_kind_of(arg_rtc, r2corba_cTypeCode)==Qfalse)
        {
          X_CORBA(BAD_PARAM);
        }
        R2TAO_TRY
        {
          CORBA::TypeCode_ptr _arg_tc = r2corba_TypeCode_r2t (arg_rtc);

          CORBA::NamedValue_ptr _nv = _arg_name ?
                dsi_data->_nvlist->add_item (_arg_name, _arg_type == r2tao_IN_ARG ?
                                                        CORBA::ARG_IN :
                                                        (_arg_type == r2tao_INOUT_ARG ?
                                                          CORBA::ARG_INOUT : CORBA::ARG_OUT))
                :
                dsi_data->_nvlist->add (_arg_type == r2tao_IN_ARG ?
                                        CORBA::ARG_IN :
                                        (_arg_type == r2tao_INOUT_ARG ?
                                          CORBA::ARG_INOUT : CORBA::ARG_OUT));
          // assign type info to Any
          _nv->value ()->_tao_set_typecode (_arg_tc);
        }
        R2TAO_CATCH;
      }

      R2TAO_TRY
      {
        // set ORB arguments (retrieves data for IN/INOUT args)
        request->arguments (dsi_data->_nvlist);

        // register result type (if any)
        if (result_type != Qnil)
        {
          dsi_data->_result_type =
              CORBA::TypeCode::_duplicate(r2corba_TypeCode_r2t (result_type));
        }
      }
      R2TAO_CATCH;
    }
    else
    {
      X_CORBA(BAD_PARAM);
    }
  }
  return Qnil;
}

VALUE r2tao_ServerRequest_arguments(VALUE self)
{
  if (DATA_PTR (self) != 0)
  {
    DSI_Data* dsi_data = static_cast<DSI_Data*> (DATA_PTR (self));
    if (CORBA::NVList::_nil () == dsi_data->_nvlist)
    {
      X_CORBA (BAD_INV_ORDER);
    }

    R2TAO_TRY
    {
      // build argument list for servant implementation
      CORBA::ULong arg_len = dsi_data->_nvlist->count ();
      VALUE rargs = rb_ary_new ();
      for (CORBA::ULong arg=0; arg<arg_len ;++arg)
      {
        CORBA::NamedValue_ptr _nv = dsi_data->_nvlist->item (arg);
        if (ACE_BIT_DISABLED (_nv->flags (), CORBA::ARG_OUT))
        {
          CORBA::TypeCode_var _arg_tc = _nv->value ()->type ();
          VALUE rval = r2tao_Any2Ruby(*_nv->value (), _arg_tc.in (), Qnil, Qnil);
          rb_ary_push (rargs, rval);
        }
      }
      return rargs;
    }
    R2TAO_CATCH;
  }
  return Qnil;
}

VALUE r2tao_ServerRequest_get(VALUE self, VALUE key)
{
  if (DATA_PTR (self) != 0)
  {
    DSI_Data* dsi_data = static_cast<DSI_Data*> (DATA_PTR (self));
    if (CORBA::NVList::_nil () == dsi_data->_nvlist)
    {
      X_CORBA (BAD_INV_ORDER);
    }

    if (key == Qnil)
    {
      X_CORBA (BAD_PARAM);
    }

    if (rb_obj_is_kind_of (key, rb_cString) == Qtrue)
    {
      char* arg_name = RSTRING_PTR (key);
      CORBA::ULong arg_num = dsi_data->_nvlist->count ();
      for (CORBA::ULong ix=0; ix<arg_num ;++ix)
      {
        CORBA::NamedValue_ptr _nv = dsi_data->_nvlist->item (ix);
        if (_nv->name () && ACE_OS::strcmp (arg_name, _nv->name ()) == 0)
        {
          R2TAO_TRY
          {
            CORBA::TypeCode_var _arg_tc = _nv->value ()->type ();
            return r2tao_Any2Ruby(*_nv->value (), _arg_tc.in (), Qnil, Qnil);
          }
          R2TAO_CATCH;
        }
      }

      X_CORBA (BAD_PARAM);
    }
    else
    {
      CORBA::ULong ix = NUM2ULONG (key);
      if (dsi_data->_nvlist->count () <= ix)
      {
        X_CORBA (BAD_PARAM);
      }
      R2TAO_TRY
      {
        CORBA::NamedValue_ptr _nv = dsi_data->_nvlist->item (ix);
        CORBA::TypeCode_var _arg_tc = _nv->value ()->type ();
        return r2tao_Any2Ruby(*_nv->value (), _arg_tc.in (), Qnil, Qnil);
      }
      R2TAO_CATCH;
    }
  }
  return Qnil;
}

VALUE r2tao_ServerRequest_set(VALUE self, VALUE key, VALUE val)
{
  if (DATA_PTR (self) != 0)
  {
    DSI_Data* dsi_data = static_cast<DSI_Data*> (DATA_PTR (self));
    if (CORBA::NVList::_nil () == dsi_data->_nvlist)
    {
      X_CORBA (BAD_INV_ORDER);
    }

    if (key == Qnil)
    {
      X_CORBA (BAD_PARAM);
    }

    if (rb_obj_is_kind_of (key, rb_cString) == Qtrue)
    {
      char* arg_name = RSTRING_PTR (key);
      CORBA::ULong arg_num = dsi_data->_nvlist->count ();
      for (CORBA::ULong ix=0; ix<arg_num ;++ix)
      {
        CORBA::NamedValue_ptr _nv = dsi_data->_nvlist->item (ix);
        if (_nv->name () && ACE_OS::strcmp (arg_name, _nv->name ()) == 0)
        {
          R2TAO_TRY
          {
            CORBA::TypeCode_var _arg_tc = _nv->value ()->type ();
            r2tao_Ruby2Any(*_nv->value (), _arg_tc.in (), val);
            return Qtrue;
          }
          R2TAO_CATCH;
        }
      }

      X_CORBA (BAD_PARAM);
    }
    else
    {
      CORBA::ULong ix = NUM2ULONG (key);
      if (dsi_data->_nvlist->count () <= ix)
      {
        X_CORBA (BAD_PARAM);
      }
      R2TAO_TRY
      {
        CORBA::NamedValue_ptr _nv = dsi_data->_nvlist->item (ix);
        CORBA::TypeCode_var _arg_tc = _nv->value ()->type ();
        r2tao_Ruby2Any(*_nv->value (), _arg_tc.in (), val);
        return Qtrue;
      }
      R2TAO_CATCH;
    }
  }
  return Qnil;
}

//-------------------------------------------------------------------
//  R2TAO Servant class
//
//===================================================================

DSI_Servant::DSI_Servant(VALUE rbServant)
 : rbServant_ (rbServant)
{
  if (TAO_debug_level > 9)
    ACE_DEBUG ((LM_INFO, "R2TAO (%P|%t) - Servant::ctor(%@) - rbsrv=%@\n", this, this->rbServant_));

  this->register_with_servant();
}

DSI_Servant::~DSI_Servant()
{
  if (TAO_debug_level > 9)
    ACE_DEBUG ((LM_INFO, "R2TAO (%P|%t) - Servant::dtor(%@) - rbsrv=%@\n", this, this->rbServant_));

  this->cleanup_servant ();
}

void DSI_Servant::register_with_servant ()
{
  // register with Ruby servant (refcount == 1)
  DATA_PTR(this->rbServant_) = this;
}

void DSI_Servant::cleanup_servant ()
{
  r2tao_call_thread_safe (DSI_Servant::thread_safe_cleanup, this);
}

void DSI_Servant::inner_cleanup_servant ()
{
  // we're being destroyed so unlink us from the Ruby servant (if any)
  if (!NIL_P (this->rbServant_))
  {
    // clear our registration with the Ruby servant
    DATA_PTR(this->rbServant_) = 0;

    // unregister the Ruby servant so it can be GC-ed
    r2tao_unregister_object (this->rbServant_);
  }
}

// invocation helper for threadsafe calling of Ruby code
void* DSI_Servant::thread_safe_cleanup (void * arg)
{
  DSI_Servant* svt = reinterpret_cast<DSI_Servant*> (arg);

  try {
    svt->inner_cleanup_servant ();
  }
  catch (...) {
    return ::CORBA::UNKNOWN (0, CORBA::COMPLETED_MAYBE)._tao_duplicate ();
  }
  return 0;
}

void DSI_Servant::free_servant ()
{
  if (TAO_debug_level > 9)
    ACE_DEBUG ((LM_INFO, "R2TAO (%P|%t) - Servant::free_servant(%@) - rbsrv=%@\n", this, this->rbServant_));

  // the Ruby servant is freed (GC-ed) so unlink and decrease refcount
  // NOTE: only called if we were still registered with the Ruby servant
  //       at the time of GC
  this->rbServant_ = Qnil;
  this->_remove_ref (); // might trigger destructor
}

void DSI_Servant::activate_servant ()
{
  // we've been activated
  if (TAO_debug_level > 9)
    ACE_DEBUG ((LM_INFO, "R2TAO (%P|%t) - Servant::activate_servant(%@) - rbsrv=%@\n", this, this->rbServant_));

  // register the Ruby servant so it can't be GC-ed while we're alive
  r2tao_register_object (this->rbServant_);

  // ownership is transferred to a poa (raises refcount) so we can release
  // the refcount the Ruby servant is holding on us
  this->_remove_ref ();

  // since the Ruby servant is protected against GC the only way the
  // Ruby servant will be released is after we get deactivated
  // (& subsequently destructed) at which time we detach from the
  // Ruby servant before it can get GC-ed
}

// invocation helper for rb_protect()
VALUE DSI_Servant::_invoke_implementation(VALUE args)
{
  VALUE servant = rb_ary_entry (args, 0);
  VALUE operation = rb_ary_entry (args, 1);
  VALUE opargs = rb_ary_entry (args, 2);
  return rb_apply (servant, SYM2ID (operation), opargs);
}

DSI_Servant::METHOD  DSI_Servant::method_id (const char* method)
{
  if (ACE_OS::strcmp (method, "_is_a") == 0)
    return IS_A;
  else if (ACE_OS::strcmp (method, "_repository_id") == 0)
    return REPOSITORY_ID;
  else if (ACE_OS::strcmp (method, "_non_existent") == 0)
    return NON_EXISTENT;
  else if (ACE_OS::strcmp (method, "_component") == 0)
    return GET_COMPONENT;
  else if (ACE_OS::strcmp (method, "_interface") == 0)
    return GET_INTERFACE;

  return NONE;
}

#if RPOA_NEED_DSI_FIX
void DSI_Servant::invoke (CORBA::ServerRequest_ptr /*request*/)
{}

void DSI_Servant::_dispatch (TAO_ServerRequest &request,
                             void * /*context*/)
{
  // No need to do any of this if the client isn't waiting.
  if (request.response_expected ())
    {
      if (request.is_forwarded ())
        {
          request.init_reply ();
          request.tao_send_reply ();

          // No need to invoke in this case.
          return;
        }
      else if (request.sync_with_server ())
        {
          // The last line before the call to this function
          // was an ACE_CHECK_RETURN, so if we're here, we
          // know there is no exception so far, and that's all
          // a SYNC_WITH_SERVER client request cares about.
          request.send_no_exception_reply ();
        }
    }

  // Create DSI request object.
  R2CORBA::ServerRequest *dsi_request = 0;
  ACE_NEW (dsi_request,
           R2CORBA::ServerRequest (request));

  try
    {
      // Delegate to user.
      this->invoke_fix (dsi_request);

      // Only if the client is waiting.
      if (request.response_expected () && !request.sync_with_server ())
        {
          dsi_request->dsi_marshal ();
        }
    }
  catch (::CORBA::Exception& ex)
    {
      // Only if the client is waiting.
      if (request.response_expected () && !request.sync_with_server ())
        {
          if (request.collocated ()
               && request.operation_details ()->cac () != 0)
            {
              // If we have a cac it will handle the exception and no
              // need to do any further processing
              request.operation_details ()->cac ()->handle_corba_exception (
                request, &ex);
              return;
            }
          else
            request.tao_send_reply_exception (ex);
        }
    }

  ::CORBA::release (dsi_request);
}
#endif

// invocation helper for threadsafe calling of Ruby code
void* DSI_Servant::thread_safe_invoke (void * arg)
{
  ThreadSafeArg* tca = reinterpret_cast<ThreadSafeArg*> (arg);

  try {
    tca->servant_->inner_invoke (tca->request_);
  }
  catch (const CORBA::SystemException& ex) {
    return ex._tao_duplicate ();
  }
  catch (...) {
    return ::CORBA::UNKNOWN (0, CORBA::COMPLETED_MAYBE)._tao_duplicate ();
  }
  return 0;
}

# if RPOA_NEED_DSI_FIX
void DSI_Servant::invoke_fix (R2CORBA::ServerRequest_ptr request)
# else
void DSI_Servant::invoke (CORBA::ServerRequest_ptr request)
# endif
{
  ThreadSafeArg tca_(this, request);

  void* rc = r2tao_call_thread_safe (DSI_Servant::thread_safe_invoke, &tca_);
  if (rc != 0)
  {
    CORBA::SystemException* exc = reinterpret_cast<CORBA::SystemException*> (rc);
    ACE_Auto_Basic_Ptr<CORBA::SystemException> e_ptr(exc);
    exc->_raise ();
  }
}

void DSI_Servant::inner_invoke (R2CORBA_ServerRequest_ptr request)
{
  if (TAO_debug_level > 7)
    ACE_DEBUG ((LM_INFO, "R2TAO (%P|%t) - Servant::invoke(%C)\n", request->operation ()));

  // check if Ruby servant still attached
  if (this->rbServant_ == Qnil)
  {
    // we're detached so nothing is implemented anymore
    throw ::CORBA::NO_IMPLEMENT (0, CORBA::COMPLETED_NO);
  }

  METHOD mt = this->method_id(request->operation ());

  CORBA::Boolean f;
  if (mt == IS_A || mt == NON_EXISTENT)
  {
    CORBA::ORB_ptr _orb = request->_tao_server_request ().orb ();

    CORBA::NVList_ptr nvlist;
    _orb->create_list (0, nvlist);

    if (mt == IS_A)
    {
      CORBA::NamedValue_ptr _nv = nvlist->add (CORBA::ARG_IN);
      _nv->value ()->_tao_set_typecode (CORBA::_tc_string);

      // set ORB arguments (retrieves data for IN/INOUT args)
      request->arguments (nvlist);

      const char *tmp = 0;
      (*_nv->value ()) >>= tmp;

      f = this->_is_a (tmp);

      if (TAO_debug_level > 5)
        ACE_DEBUG ((LM_INFO, "R2TAO (%P|%t) _is_a (%s) -> %d\n", tmp, f));
    }
    else
    {
      // set ORB arguments (retrieves data for IN/INOUT args)
      request->arguments (nvlist);

      f = this->_non_existent ();

      if (TAO_debug_level > 5)
        ACE_DEBUG ((LM_INFO, "R2TAO (%P|%t) _non_existent () -> %d\n", f));
    }

    CORBA::Any _any;
    _any <<= CORBA::Any::from_boolean (f);
    request->set_result(_any);
  }
  else if (mt == REPOSITORY_ID)
  {
    CORBA::ORB_ptr _orb = request->_tao_server_request ().orb ();

    CORBA::NVList_ptr nvlist;
    _orb->create_list (0, nvlist);
    // set ORB arguments (retrieves data for IN/INOUT args)
    request->arguments (nvlist);

    CORBA::String_var repo_id = this->_repository_id ();

    if (TAO_debug_level > 5)
      ACE_DEBUG ((LM_INFO, "R2TAO (%P|%t) _repository_id () -> %s\n", repo_id.in ()));

    CORBA::Any _any;
    _any <<= repo_id.in ();
    request->set_result(_any);
  }
  else if (mt == GET_COMPONENT)
  {
    CORBA::ORB_ptr _orb = request->_tao_server_request ().orb ();

    CORBA::NVList_ptr nvlist;
    _orb->create_list (0, nvlist);
    // set ORB arguments (retrieves data for IN/INOUT args)
    request->arguments (nvlist);

    CORBA::Object_var obj = this->_get_component ();

    if (TAO_debug_level > 5)
      ACE_DEBUG ((LM_INFO, "R2TAO (%P|%t) _get_component () -> %@\n", obj.in ()));

    CORBA::Any _any;
    _any <<= obj.in ();
    request->set_result(_any);
  }
  else if (mt == GET_INTERFACE)
  {
    throw ::CORBA::NO_IMPLEMENT (0, CORBA::COMPLETED_NO);
  }
  else
  {
    if (rb_obj_is_kind_of (this->rbServant_, r2tao_cDynamicImp))
      this->invoke_DSI(request);
    else
      this->invoke_SI(request);
  }
}

void DSI_Servant::invoke_DSI (R2CORBA_ServerRequest_ptr request)
{
  if (TAO_debug_level > 5)
    ACE_DEBUG ((LM_INFO, "R2TAO (%P|%t) - Servant::invoke_DSI(%C) entry\n", request->operation ()));

  // wrap request for Ruby; cleanup automatically
  ACE_Auto_Basic_Ptr<DSI_Data>  dsi_data(new DSI_Data(request));

  VALUE srvreq = Data_Wrap_Struct(r2tao_cServerRequest, 0, 0, dsi_data.get ());

  dsi_data.get()->_rData = srvreq;  // have DSI_Data clean up Ruby object at destruction time

  // invoke servant implementation
  VALUE rargs = rb_ary_new2 (1);
  rb_ary_push (rargs, srvreq);
  VALUE invoke_holder = rb_ary_new2 (3);
  rb_ary_push (invoke_holder, this->rbServant_);
  rb_ary_push (invoke_holder, ID2SYM (invoke_ID));
  rb_ary_push (invoke_holder, rargs);
  int invoke_state = 0;
  VALUE ret = rb_protect (RUBY_INVOKE_FUNC (DSI_Servant::_invoke_implementation),
                          invoke_holder,
                          &invoke_state);

  if (invoke_state)
  {
    // handle exception
    VALUE rexc = rb_gv_get ("$!");
    if (rb_obj_is_kind_of(rexc, r2tao_cUserException) == Qtrue)
    {
      VALUE rextc = rb_eval_string ("R2CORBA::CORBA::Any.typecode_for_any ($!)");
      if (rextc != Qnil)
      {
        CORBA::Any _xval;
        CORBA::TypeCode_ptr _xtc = r2corba_TypeCode_r2t (rextc);
        r2tao_Ruby2Any(_xval, _xtc, rexc);
        request->set_exception (_xval);

        return;
      }
    }

    if (rb_obj_is_kind_of(rexc, r2tao_cSystemException) == Qtrue)
    {
      VALUE rid = rb_funcall (rexc, interface_repository_id_ID, 0);
      CORBA::SystemException* _exc = TAO::create_system_exception (RSTRING_PTR (rid));

      _exc->minor (
        static_cast<CORBA::ULong> (NUM2ULONG (rb_iv_get (rexc, "@minor"))));
      _exc->completed (
        static_cast<CORBA::CompletionStatus> (NUM2ULONG (rb_iv_get (rexc, "@completed"))));

      ACE_Auto_Basic_Ptr<CORBA::SystemException> e_ptr(_exc);
      _exc->_raise ();
    }
    else
    {
      rb_eval_string ("STDERR.puts $!.to_s+\"\\n\"+$!.backtrace.join(\"\\n\")");
      throw ::CORBA::UNKNOWN (0, CORBA::COMPLETED_MAYBE);
    }
  }
  else
  {
    // check for oneway (no results at all) or twoway
    if (!CORBA::is_nil (dsi_data.get()->_result_type.in ()))
    {
      // twoway
      if (TAO_debug_level > 5)
        ACE_DEBUG ((LM_INFO, "(%P|%t) checking return values of twoway invocation\n"));

      // handle OUT values
      long arg_out = 0;
      long ret_off =
          (dsi_data.get()->_result_type->kind () != CORBA::tk_void) ? 1 : 0;
      CORBA::ULong arg_len = dsi_data.get()->_nvlist->count ();
      for (CORBA::ULong arg=0; arg<arg_len ;++arg)
      {
        if (TAO_debug_level > 7)
          ACE_DEBUG ((LM_INFO, "(%P|%t) handling (IN)OUT arg %d\n", arg));

        CORBA::NamedValue_ptr _nv = dsi_data.get()->_nvlist->item (arg);
        if (ACE_BIT_DISABLED (_nv->flags (), CORBA::ARG_IN))
        {
          ++arg_out; // count number of (IN)OUT arguments

          VALUE retval = Qnil;
          if (rb_type (ret) == T_ARRAY && ret_off<RARRAY_LEN (ret))
          {
            retval = rb_ary_entry (ret, ret_off++);
          }
          CORBA::TypeCode_var _arg_tc = _nv->value ()->type ();
          r2tao_Ruby2Any(*_nv->value (), _arg_tc.in (), retval);

          if (TAO_debug_level > 7)
            ACE_DEBUG ((LM_INFO, "(%P|%t) converted (IN)OUT arg %d\n", arg));
        }
      }

      // handle return value
      if (dsi_data.get()->_result_type->kind () != CORBA::tk_void)
      {
        if (TAO_debug_level > 7)
          ACE_DEBUG ((LM_INFO, "(%P|%t) handling result value\n"));

        CORBA::Any _retval;
        VALUE retval = Qnil;
        if (arg_out == 0)
        {
          retval = ret;
        }
        else if (rb_type (ret) == T_ARRAY && 0<RARRAY_LEN (ret))
        {
          retval = rb_ary_entry (ret, 0);
        }
        r2tao_Ruby2Any(_retval, dsi_data.get()->_result_type.in (), retval);

        if (TAO_debug_level > 7)
          ACE_DEBUG ((LM_INFO, "(%P|%t) converted result value\n"));

        request->set_result (_retval);
      }
    }
  }
}

void DSI_Servant::invoke_SI (R2CORBA_ServerRequest_ptr request)
{
  if (TAO_debug_level > 5)
    ACE_DEBUG ((LM_INFO, "R2TAO (%P|%t) - Servant::invoke_SI(%C) entry\n", request->operation ()));

  // retrieve targeted operation
  VALUE ropsym = ID2SYM (rb_intern (request->operation ()));
  // retrieve operation signature
  VALUE ropsig = rb_funcall (this->rbServant_, get_operation_sig_ID, 1, ropsym);

  if (ropsig != Qnil && rb_type (ropsig) == T_HASH)
  {
    // check signature and create argument list for ORB
    VALUE arg_list = rb_hash_aref (ropsig, ID_arg_list);
    if (arg_list != Qnil && rb_type (arg_list) != T_ARRAY)
    {
      throw ::CORBA::BAD_PARAM (0, CORBA::COMPLETED_NO);
    }
    VALUE result_type = rb_hash_aref (ropsig, ID_result_type);
    if (result_type != Qnil && rb_obj_is_kind_of(result_type, r2corba_cTypeCode) != Qtrue)
    {
      throw ::CORBA::BAD_PARAM (0, CORBA::COMPLETED_NO);
    }
    VALUE exc_list = rb_hash_aref (ropsig, ID_exc_list);
    if (exc_list != Qnil && rb_type (exc_list) != T_ARRAY)
    {
      throw ::CORBA::BAD_PARAM (0, CORBA::COMPLETED_NO);
    }
    VALUE alt_op_sym = rb_hash_aref (ropsig, ID_op_sym);
    if (alt_op_sym != Qnil && rb_type (alt_op_sym) == T_SYMBOL)
    {
      ropsym = alt_op_sym;
    }

    CORBA::ORB_ptr _orb = request->_tao_server_request ().orb ();

    CORBA::NVList_ptr nvlist;
    _orb->create_list (0, nvlist);

    long arg_len =
        arg_list == Qnil ? 0 : RARRAY_LEN (arg_list);
    for (long arg=0; arg<arg_len ;++arg)
    {
      VALUE argspec = rb_ary_entry (arg_list, arg);
      if (argspec != Qnil && rb_type (argspec) != T_ARRAY)
      {
        throw ::CORBA::BAD_PARAM (0, CORBA::COMPLETED_NO);
      }
      char *_arg_name = RSTRING_PTR (rb_ary_entry (argspec, 0));
      int _arg_type = NUM2INT (rb_ary_entry (argspec, 1));
      VALUE argtc = rb_ary_entry (argspec, 2);
      if (argtc != Qnil && rb_obj_is_kind_of(argtc, r2corba_cTypeCode) != Qtrue)
      {
        throw ::CORBA::BAD_PARAM (0, CORBA::COMPLETED_NO);
      }
      CORBA::TypeCode_ptr _arg_tc = r2corba_TypeCode_r2t (argtc);

      if (TAO_debug_level > 6)
        ACE_DEBUG ((LM_INFO, "R2TAO (%P|%t) - Servant::invoke_SI(%C) arg #%d : kind=%d, type=%d\n",
                    request->operation (),
                    arg,
                    _arg_tc->kind(),
                    _arg_type));

      CORBA::NamedValue_ptr _nv = nvlist->add_item (_arg_name, _arg_type == r2tao_IN_ARG ?
                                                    CORBA::ARG_IN :
                                                    (_arg_type == r2tao_INOUT_ARG ?
                                                      CORBA::ARG_INOUT : CORBA::ARG_OUT));
      // assign type info to Any
      r2tao_Ruby2Any (*_nv->value (), _arg_tc, Qnil);
    }

    if (TAO_debug_level > 6)
      ACE_DEBUG ((LM_INFO, "R2TAO (%P|%t) - Servant::invoke_SI(%C) retrieve request args\n", request->operation ()));

    // set ORB arguments (retrieves data for IN/INOUT args)
    request->arguments (nvlist);

    if (TAO_debug_level > 6)
      ACE_DEBUG ((LM_INFO, "R2TAO (%P|%t) - Servant::invoke_SI(%C) convert request args\n", request->operation ()));

    // build argument list for servant implementation
    VALUE rargs = rb_ary_new ();
    for (long arg=0; arg<arg_len ;++arg)
    {
      CORBA::NamedValue_ptr _nv = nvlist->item (static_cast<CORBA::ULong> (arg));
      if (ACE_BIT_DISABLED (_nv->flags (), CORBA::ARG_OUT))
      {
        VALUE argspec = rb_ary_entry (arg_list, arg);
        VALUE argtc = rb_ary_entry (argspec, 2);
        CORBA::TypeCode_ptr _arg_tc = r2corba_TypeCode_r2t (argtc);
        VALUE rval = r2tao_Any2Ruby(*_nv->value (), _arg_tc, Qnil, Qnil);
        rb_ary_push (rargs, rval);
      }
    }

    if (TAO_debug_level > 6)
      ACE_DEBUG ((LM_INFO, "R2TAO (%P|%t) - Servant::invoke_SI(%C) invoke implementation\n", request->operation ()));

    // invoke servant implementation
    VALUE invoke_holder = rb_ary_new2 (4);
    rb_ary_push (invoke_holder, this->rbServant_);
    rb_ary_push (invoke_holder, ropsym);
    rb_ary_push (invoke_holder, rargs);
    int invoke_state = 0;
    VALUE ret = rb_protect (RUBY_INVOKE_FUNC (DSI_Servant::_invoke_implementation),
                            invoke_holder,
                            &invoke_state);
    if (invoke_state)
    {
      if (TAO_debug_level > 5)
        ACE_DEBUG ((LM_INFO, "R2TAO (%P|%t) - Servant::invoke_SI(%C) exception from invocation\n", request->operation ()));

      // handle exception
      VALUE rexc = rb_gv_get ("$!");
      if (rb_obj_is_kind_of(rexc, r2tao_cUserException) == Qtrue)
      {
        if (TAO_debug_level > 6)
          ACE_DEBUG ((LM_INFO, "R2TAO (%P|%t) - Servant::invoke_SI(%C) detected user exception\n",
                               request->operation ()));

        if (exc_list != Qnil)
        {
          long exc_len = RARRAY_LEN (exc_list);
          for (long x=0; x<exc_len ;++x)
          {
            VALUE exctc = rb_ary_entry (exc_list, x);
            VALUE exklass = rb_funcall (exctc, rb_intern ("get_type"), 0);
            if (rb_obj_is_kind_of(rexc, exklass) == Qtrue)
            {
              CORBA::Any _xval;
              CORBA::TypeCode_ptr _xtc = r2corba_TypeCode_r2t (exctc);

              if (TAO_debug_level > 9)
                ACE_DEBUG ((LM_INFO, "R2TAO (%P|%t) - Servant::invoke_SI(%C) returning user exception %C\n",
                                     request->operation (), _xtc->id ()));

              r2tao_Ruby2Any(_xval, _xtc, rexc);
              request->set_exception (_xval);

              return;
            }
          }
        }
      }

      if (rb_obj_is_kind_of(rexc, r2tao_cSystemException) == Qtrue)
      {
        VALUE rid = rb_funcall (rexc, interface_repository_id_ID, 0);
        CORBA::SystemException* _exc = TAO::create_system_exception (RSTRING_PTR (rid));

        if (TAO_debug_level > 9)
          ACE_DEBUG ((LM_INFO, "R2TAO (%P|%t) - Servant::invoke_SI(%C) returning system exception %C\n",
                               request->operation (), RSTRING_PTR (rid)));

        _exc->minor (
          static_cast<CORBA::ULong> (NUM2ULONG (rb_iv_get (rexc, "@minor"))));
        _exc->completed (
          static_cast<CORBA::CompletionStatus> (NUM2ULONG (rb_iv_get (rexc, "@completed"))));

        ACE_Auto_Basic_Ptr<CORBA::SystemException> e_ptr(_exc);
        _exc->_raise ();
      }
      else
      {
        rb_eval_string ("STDERR.puts $!.to_s+\"\\n\"+$!.backtrace.join(\"\\n\")");
        throw ::CORBA::UNKNOWN (0, CORBA::COMPLETED_MAYBE);
      }
    }
    else
    {
      if (TAO_debug_level > 5)
        ACE_DEBUG ((LM_INFO, "R2TAO (%P|%t) - Servant::invoke_SI(%C) handle invocation result\n", request->operation ()));

      // check for oneway (no results at all) or twoway
      if (result_type != Qnil)
      {
        if (TAO_debug_level > 6)
          ACE_DEBUG ((LM_INFO, "(%P|%t) Servant::invoke_SI(%C) checking return values of twoway invocation\n",
                               request->operation ()));

        // twoway
        CORBA::TypeCode_ptr _result_tc = r2corba_TypeCode_r2t (result_type);

        // handle OUT values
        long ret_off =
            (_result_tc->kind () != CORBA::tk_void) ? 1 : 0;
        long arg_out = 0;
        for (long arg=0; arg<arg_len ;++arg)
        {
          if (TAO_debug_level > 9)
            ACE_DEBUG ((LM_INFO, "(%P|%t) Servant::invoke_SI(%C) handling (IN)OUT arg %d\n", request->operation (), arg));

          CORBA::NamedValue_ptr _nv = nvlist->item (static_cast<CORBA::ULong> (arg));
          if (ACE_BIT_DISABLED (_nv->flags (), CORBA::ARG_IN))
          {
            ++arg_out; // count number of (IN)OUT arguments

            VALUE retval = Qnil;
            if (rb_type (ret) == T_ARRAY && ret_off<RARRAY_LEN (ret))
            {
              retval = rb_ary_entry (ret, ret_off++);
            }
            VALUE argspec = rb_ary_entry (arg_list, arg);
            VALUE rtc = rb_ary_entry (argspec, 2);
            CORBA::TypeCode_ptr _arg_tc = r2corba_TypeCode_r2t (rtc);

            //rb_funcall (rb_eval_string ("STDERR"), rb_intern ("puts"),
            //            1, rb_funcall (retval, rb_intern ("inspect"), 0));

            r2tao_Ruby2Any(*_nv->value (), _arg_tc, retval);

            if (TAO_debug_level > 9)
              ACE_DEBUG ((LM_INFO, "(%P|%t) Servant::invoke_SI(%C) converted (IN)OUT arg %d\n", request->operation (), arg));
          }
        }

        // handle return value
        if (_result_tc->kind () != CORBA::tk_void)
        {
          if (TAO_debug_level > 9)
            ACE_DEBUG ((LM_INFO, "(%P|%t) Servant::invoke_SI(%C) handling result value\n", request->operation ()));

          CORBA::Any _retval;
          VALUE retval = Qnil;
          if (arg_out == 0)
          {
            retval = ret;
          }
          else if (rb_type (ret) == T_ARRAY && 0<RARRAY_LEN (ret))
          {
            retval = rb_ary_entry (ret, 0);
          }
          r2tao_Ruby2Any(_retval, _result_tc, retval);

          if (TAO_debug_level > 9)
            ACE_DEBUG ((LM_INFO, "(%P|%t) Servant::invoke_SI(%C) converted result value\n", request->operation ()));

          request->set_result (_retval);
        }
      }
    }
  }
  else
  {
    throw ::CORBA::NO_IMPLEMENT (0, CORBA::COMPLETED_NO);
  }
}

CORBA::Boolean DSI_Servant::_is_a (const char *logical_type_id)
{
  static R2TAO_RBFuncall FN_is_a ("_is_a?");

  // provide support for multiple interfaces
  if (rb_respond_to (this->rbServant_, FN_is_a.id ()) != 0)
  {
    // call overloaded #_is_a? method in servant implementation
    VALUE repo_id = rb_str_new2 (logical_type_id ? logical_type_id : "");
    return (Qtrue == FN_is_a.invoke (this->rbServant_, 1 , &repo_id));
  }
  else if (rb_const_defined (rb_class_of (this->rbServant_), repo_Ids) == Qtrue)
  {
    // check if requested interface included in servants Ids array
    return (Qtrue == rb_funcall (rb_const_get (rb_class_of (this->rbServant_), repo_Ids),
                                 include_ID, 1, rb_str_new2 (logical_type_id ? logical_type_id : "")));
  }
  else
  {
    return PortableServer::DynamicImplementation::_is_a (logical_type_id);
  }
}

CORBA::Boolean DSI_Servant::_non_existent (void)
{
  static R2TAO_RBFuncall FN_non_existent ("_non_existent?");

  // provide support for multiple interfaces
  if (rb_respond_to (this->rbServant_, FN_non_existent.id ()) != 0)
  {
    // call overloaded #_non_existent? method in servant implementation
    return (Qtrue == FN_non_existent.invoke (this->rbServant_));
  }
  else
  {
    return PortableServer::DynamicImplementation::_non_existent ();
  }
}

CORBA::Object_ptr DSI_Servant::_get_component (void)
{
  static R2TAO_RBFuncall FN_get_component ("_get_component");

  // provide support for multiple interfaces
  if (rb_respond_to (this->rbServant_, FN_get_component.id ()) != 0)
  {
    // call overloaded #_get_component method in servant implementation
    VALUE robj = FN_get_component.invoke (this->rbServant_);
    CORBA::Object_ptr obj = NIL_P(robj) ? CORBA::Object::_nil () : r2corba_Object_r2t (robj);
    return CORBA::Object::_duplicate (obj);
  }
  else
  {
    return PortableServer::DynamicImplementation::_get_component ();
  }
}

const char *DSI_Servant::_interface_repository_id (void) const
{
  static R2TAO_RBFuncall FN_repository_id ("_repository_id");

  // check if Ruby servant still attached
  if (this->rbServant_ == Qnil)
  {
    return "";
  }

  DSI_Servant* servant_ = const_cast<DSI_Servant*> (this);

  // provide support for multiple interfaces
  if (rb_respond_to (servant_->rbServant_, FN_repository_id.id ()) != 0)
  {
    // call overloaded #_repository_id method in servant implementation
    VALUE repo_id = FN_repository_id.invoke (servant_->rbServant_);
    if (repo_id==Qnil || rb_obj_is_kind_of(repo_id, rb_cString)==Qfalse)
    {
      if (TAO_debug_level > 3)
        ACE_DEBUG ((LM_WARNING, "(%P|%t) Servant::_interface_repository_id - cannot retrieve repo-id\n"));
      return "";
    }
    else
    {
      return RSTRING_PTR (repo_id);
    }
  }
  else
  {
    if (servant_->repo_id_.in () == 0)
    {
      if (rb_const_defined (rb_class_of (servant_->rbServant_), repo_Id) == Qtrue)
      {
        VALUE rb_repo_id = rb_const_get (rb_class_of (servant_->rbServant_), repo_Id);
        servant_->repo_id_ = CORBA::string_dup (RSTRING_PTR (rb_repo_id));
      }
      else
      {
        if (TAO_debug_level > 3)
          ACE_DEBUG ((LM_WARNING, "(%P|%t) Servant::_interface_repository_id - cannot retrieve repo-id\n"));
        servant_->repo_id_ = CORBA::string_dup ("");
      }
    }
    return servant_->repo_id_.in ();
  }
}

char * DSI_Servant::_repository_id (void)
{
  return CORBA::string_dup (this->_interface_repository_id ());
}

CORBA::RepositoryId DSI_Servant::_primary_interface (
    const PortableServer::ObjectId & oid,
    PortableServer::POA_ptr poa)
{
  // check if Ruby servant still attached
  if (this->rbServant_ == Qnil)
  {
    return CORBA::string_dup ("");
  }

  if (rb_obj_is_kind_of (this->rbServant_, r2tao_cDynamicImp))
  {
    // invoke servant implementation
    VALUE rargs = rb_ary_new2 (1);
    rb_ary_push (rargs, r2tao_ObjectId_t2r (oid));
    VALUE rpoa = r2corba_Object_t2r(dynamic_cast<CORBA::Object_ptr> (poa));
    rpoa = FN_narrow.invoke (r2tao_nsPOA, 1, &rpoa);
    rb_ary_push (rargs, rpoa);
    VALUE invoke_holder = rb_ary_new2 (3);
    rb_ary_push (invoke_holder, this->rbServant_);
    rb_ary_push (invoke_holder, ID2SYM (primary_interface_ID));
    rb_ary_push (invoke_holder, rargs);
    int invoke_state = 0;
    VALUE ret = rb_protect (RUBY_INVOKE_FUNC (DSI_Servant::_invoke_implementation),
                            invoke_holder,
                            &invoke_state);
    if (invoke_state || ret==Qnil || rb_obj_is_kind_of(ret, rb_cString)==Qfalse)
    {
      ACE_ERROR ((LM_ERROR, "(%P|%t) FAILED TO RETRIEVE REPO-ID FOR SERVANT!\n"));
      return CORBA::string_dup ("");
    }
    else
    {
      return CORBA::string_dup (RSTRING_PTR (ret));
    }
  }
  else
  {
    if (this->repo_id_.in () == 0)
    {
      if (rb_const_defined (rb_class_of (rbServant_), repo_Id) == Qtrue)
      {
        VALUE rb_repo_id = rb_const_get (rb_class_of (rbServant_), repo_Id);
        this->repo_id_ = CORBA::string_dup (RSTRING_PTR (rb_repo_id));
      }
      else
      {
        ACE_ERROR ((LM_ERROR, "(%P|%t) FAILED TO RETRIEVE REPO-ID FOR SERVANT!\n"));
        this->repo_id_ = CORBA::string_dup ("");
      }
    }
    return CORBA::string_dup (this->repo_id_.in ());
  }
}

VALUE r2tao_Servant_default_POA(VALUE self)
{
  R2TAO_TRY
  {
    DSI_Servant* _servant;
    if (DATA_PTR (self) == 0)
    {
      // create new C++ servant object
      _servant = new DSI_Servant (self);
    }
    else
    {
      // get existing C++ servant object
      _servant = static_cast<DSI_Servant*> (DATA_PTR (self));
    }

    // get default POA
    PortableServer::POA_var _poa = _servant->_default_POA ();
    VALUE rpoa = r2corba_Object_t2r(dynamic_cast<CORBA::Object_ptr> (_poa.in ()));
    return FN_narrow.invoke (r2tao_nsPOA, 1, &rpoa);
  }
  R2TAO_CATCH;
  return Qnil;
}

VALUE r2tao_Servant_this(VALUE self)
{
  R2TAO_TRY
  {
    bool _new_srv = false;
    DSI_Servant* _servant;
    if (DATA_PTR (self) == 0)
    {
      // create new C++ servant object
      _servant = new DSI_Servant (self);
      _new_srv = true;
    }
    else
    {
      // get existing C++ servant object
      _servant = static_cast<DSI_Servant*> (DATA_PTR (self));
    }

    // Check if we're called from the context of an invocation of this
    // servant or not. We check the POA_Current_Impl in TSS for this.
    if (!_new_srv)
    {
      TAO::Portable_Server::POA_Current_Impl *poa_current_impl =
        static_cast <TAO::Portable_Server::POA_Current_Impl *>
                        (TAO_TSS_Resources::instance ()->poa_current_impl_);

      if (poa_current_impl != 0
          && poa_current_impl->servant () == _servant)
        {
          // in an invocation we can safely use _this()
          CORBA::Object_var _obj = _servant->_this ();
          return r2corba_Object_t2r(_obj.in ());
        }
    }

    // register with default POA and return object ref
    VALUE rpoa = rb_funcall (self, rb_intern ("_default_POA"), 0);
    PortableServer::POA_var _poa = r2tao_POA_r2t (rpoa);
    PortableServer::ObjectId_var _oid = _poa->activate_object (_servant);

    _servant->activate_servant (); // activate Ruby servant

    CORBA::Object_var _obj = _poa->id_to_reference (_oid.in ());
    return r2corba_Object_t2r(_obj.in ());
  }
  R2TAO_CATCH;
  return Qnil;
}

//-------------------------------------------------------------------
//  Ruby <-> TAO servant conversions
//
//===================================================================

static VALUE
srv_alloc(VALUE klass)
{
  VALUE obj;
  // we start off without the C++ representation
  obj = Data_Wrap_Struct(klass, 0, srv_free, 0);
  return obj;
}

static void
srv_free(void* ptr)
{
  if (ptr)
  {
    // detach from Ruby servant object
    static_cast<DSI_Servant*> (ptr)->free_servant ();
  }
}
