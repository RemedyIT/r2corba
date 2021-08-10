/*--------------------------------------------------------------------
# poa.cpp - R2TAO CORBA PortableServer support
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
#include <memory>

#define RUBY_INVOKE_FUNC RUBY_ALLOC_FUNC

R2TAO_POA_EXPORT VALUE r2tao_nsPOA = 0;
static VALUE r2tao_nsPOAManager;
static VALUE r2tao_nsPortableServer;
static VALUE r2tao_cObjectId;
static VALUE r2tao_nsPolicy;

static VALUE r2tao_x_POA_AdapterAlreadyExists;
static VALUE r2tao_x_POA_AdapterInactive;
static VALUE r2tao_x_POA_AdapterNonExistent;
static VALUE r2tao_x_POA_InvalidPolicy;
static VALUE r2tao_x_POA_NoServant;
static VALUE r2tao_x_POA_ObjectAlreadyActive;
static VALUE r2tao_x_POA_ObjectNotActive;
static VALUE r2tao_x_POA_ServantAlreadyActive;
static VALUE r2tao_x_POA_ServantNotActive;
static VALUE r2tao_x_POA_WrongAdapter;
static VALUE r2tao_x_POA_WrongPolicy;

static VALUE r2tao_x_POAManager_AdapterInactive;

static ID new_ID;

static R2TAO_RBFuncall FN_narrow ("_narrow");

static VALUE r2tao_PS_string_to_ObjectId(VALUE self, VALUE string);
static VALUE r2tao_PS_ObjectId_to_string(VALUE self, VALUE oid);

static VALUE r2tao_POA_destroy(VALUE self, VALUE etherealize, VALUE wait_for_completion);
static VALUE r2tao_POA_the_name(VALUE self);
static VALUE r2tao_POA_the_POAManager(VALUE self);
static VALUE r2tao_POA_the_parent(VALUE self);
static VALUE r2tao_POA_the_children(VALUE self);
static VALUE r2tao_POA_activate_object(VALUE self, VALUE servant);
static VALUE r2tao_POA_activate_object_with_id(VALUE self, VALUE id, VALUE servant);
static VALUE r2tao_POA_deactivate_object(VALUE self, VALUE oid);
static VALUE r2tao_POA_create_reference(VALUE self, VALUE repoid);
static VALUE r2tao_POA_create_reference_with_id(VALUE self, VALUE oid, VALUE repoid);
static VALUE r2tao_POA_servant_to_id(VALUE self, VALUE servant);
static VALUE r2tao_POA_servant_to_reference(VALUE self, VALUE servant);
static VALUE r2tao_POA_reference_to_servant(VALUE self, VALUE obj);
static VALUE r2tao_POA_reference_to_id(VALUE self, VALUE obj);
static VALUE r2tao_POA_id_to_servant(VALUE self, VALUE oid);
static VALUE r2tao_POA_id_to_reference(VALUE self, VALUE oid);
static VALUE r2tao_POA_create_POA(VALUE self, VALUE name, VALUE poaman, VALUE policies);
static VALUE r2tao_POA_find_POA(VALUE self, VALUE name, VALUE activate);
static VALUE r2tao_POA_id(VALUE self);

static PortableServer::POAManager_ptr r2tao_POAManager_r2t(VALUE obj);

static VALUE r2tao_POAManager_activate(VALUE self);
static VALUE r2tao_POAManager_hold_requests(VALUE self, VALUE wait_for_completion);
static VALUE r2tao_POAManager_discard_requests(VALUE self, VALUE wait_for_completion);
static VALUE r2tao_POAManager_deactivate(VALUE self, VALUE etherealize, VALUE wait_for_completion);
static VALUE r2tao_POAManager_get_state(VALUE self);
static VALUE r2tao_POAManager_get_id(VALUE self);
static VALUE r2tao_POAManager_get_orb(VALUE self);

static PortableServer::ObjectId* r2tao_ObjectId_r2t(VALUE oid);

void r2tao_init_Servant(); // in servant.cpp
void r2tao_init_IORTable(); // in iortable.cpp

#if defined(WIN32) && defined(_DEBUG)
extern "C" R2TAO_POA_EXPORT void Init_librpoad()
#else
extern "C" R2TAO_POA_EXPORT void Init_librpoa()
#endif
{
  VALUE klass;

  if (r2tao_nsCORBA == 0)
  {
    rb_raise(rb_eRuntimeError, "CORBA base not initialized.");
    return;
  }

  if (r2tao_nsPOA) return;

  r2tao_nsPortableServer = klass = rb_eval_string("::R2CORBA::PortableServer");
  rb_define_singleton_method(klass, "string_to_ObjectId", RUBY_METHOD_FUNC(r2tao_PS_string_to_ObjectId), 1);
  rb_define_singleton_method(klass, "ObjectId_to_string", RUBY_METHOD_FUNC(r2tao_PS_ObjectId_to_string), 1);

  r2tao_nsPOA = klass = rb_eval_string("::R2CORBA::PortableServer::POA");

  r2tao_x_POA_AdapterAlreadyExists = rb_const_get (r2tao_nsPOA, rb_intern ("AdapterAlreadyExists"));
  r2tao_x_POA_AdapterInactive = rb_const_get (r2tao_nsPOA, rb_intern ("AdapterInactive"));
  r2tao_x_POA_AdapterNonExistent = rb_const_get (r2tao_nsPOA, rb_intern ("AdapterNonExistent"));
  r2tao_x_POA_InvalidPolicy = rb_const_get (r2tao_nsPOA, rb_intern ("InvalidPolicy"));
  r2tao_x_POA_NoServant = rb_const_get (r2tao_nsPOA, rb_intern ("NoServant"));
  r2tao_x_POA_ObjectAlreadyActive = rb_const_get (r2tao_nsPOA, rb_intern ("ObjectAlreadyActive"));
  r2tao_x_POA_ObjectNotActive = rb_const_get (r2tao_nsPOA, rb_intern ("ObjectNotActive"));
  r2tao_x_POA_ServantAlreadyActive = rb_const_get (r2tao_nsPOA, rb_intern ("ServantAlreadyActive"));
  r2tao_x_POA_ServantNotActive = rb_const_get (r2tao_nsPOA, rb_intern ("ServantNotActive"));
  r2tao_x_POA_WrongAdapter = rb_const_get (r2tao_nsPOA, rb_intern ("WrongAdapter"));
  r2tao_x_POA_WrongPolicy = rb_const_get (r2tao_nsPOA, rb_intern ("WrongPolicy"));

  rb_define_method(klass, "destroy", RUBY_METHOD_FUNC(r2tao_POA_destroy), 2);
  rb_define_method(klass, "the_name", RUBY_METHOD_FUNC(r2tao_POA_the_name), 0);
  rb_define_method(klass, "the_POAManager", RUBY_METHOD_FUNC(r2tao_POA_the_POAManager), 0);
  rb_define_method(klass, "the_parent", RUBY_METHOD_FUNC(r2tao_POA_the_parent), 0);
  rb_define_method(klass, "the_children", RUBY_METHOD_FUNC(r2tao_POA_the_children), 0);
  rb_define_method(klass, "activate_object", RUBY_METHOD_FUNC(r2tao_POA_activate_object), 1);
  rb_define_method(klass, "activate_object_with_id", RUBY_METHOD_FUNC(r2tao_POA_activate_object_with_id), 2);
  rb_define_method(klass, "deactivate_object", RUBY_METHOD_FUNC(r2tao_POA_deactivate_object), 1);
  rb_define_method(klass, "create_reference", RUBY_METHOD_FUNC(r2tao_POA_create_reference), 1);
  rb_define_method(klass, "create_reference_with_id", RUBY_METHOD_FUNC(r2tao_POA_create_reference_with_id), 2);
  rb_define_method(klass, "servant_to_id", RUBY_METHOD_FUNC(r2tao_POA_servant_to_id), 1);
  rb_define_method(klass, "servant_to_reference", RUBY_METHOD_FUNC(r2tao_POA_servant_to_reference), 1);
  rb_define_method(klass, "reference_to_servant", RUBY_METHOD_FUNC(r2tao_POA_reference_to_servant), 1);
  rb_define_method(klass, "reference_to_id", RUBY_METHOD_FUNC(r2tao_POA_reference_to_id), 1);
  rb_define_method(klass, "id_to_servant", RUBY_METHOD_FUNC(r2tao_POA_id_to_servant), 1);
  rb_define_method(klass, "id_to_reference", RUBY_METHOD_FUNC(r2tao_POA_id_to_reference), 1);
  rb_define_method(klass, "create_POA", RUBY_METHOD_FUNC(r2tao_POA_create_POA), 3);
  rb_define_method(klass, "find_POA", RUBY_METHOD_FUNC(r2tao_POA_find_POA), 2);
  rb_define_method(klass, "id", RUBY_METHOD_FUNC(r2tao_POA_id), 0);

  r2tao_nsPOAManager = klass = rb_eval_string("::R2CORBA::PortableServer::POAManager");

  r2tao_x_POAManager_AdapterInactive = rb_const_get (r2tao_nsPOAManager, rb_intern ("AdapterInactive"));

  rb_define_method(klass, "activate", RUBY_METHOD_FUNC(r2tao_POAManager_activate), 0);
  rb_define_method(klass, "hold_requests", RUBY_METHOD_FUNC(r2tao_POAManager_hold_requests), 1);
  rb_define_method(klass, "discard_requests", RUBY_METHOD_FUNC(r2tao_POAManager_discard_requests), 1);
  rb_define_method(klass, "deactivate", RUBY_METHOD_FUNC(r2tao_POAManager_deactivate), 2);
  rb_define_method(klass, "get_state", RUBY_METHOD_FUNC(r2tao_POAManager_get_state), 0);
  rb_define_method(klass, "get_id", RUBY_METHOD_FUNC(r2tao_POAManager_get_id), 0);
  rb_define_method(klass, "_get_orb", RUBY_METHOD_FUNC(r2tao_POAManager_get_orb), 0);

  new_ID = rb_intern ("new");

  r2tao_cObjectId = rb_eval_string("::R2CORBA::PortableServer::ObjectId");
  r2tao_nsPolicy = rb_eval_string ("R2CORBA::CORBA::Policy");

  r2tao_init_Servant(); // in servant.cpp
  r2tao_init_IORTable(); // in iortable.cpp
}

class R2TAO_POA_BlockedRegionCallerBase
{
public:
  R2TAO_POA_BlockedRegionCallerBase () = default;
  virtual ~R2TAO_POA_BlockedRegionCallerBase () noexcept(false);

  VALUE call ();

  static VALUE blocking_func_exec (void *arg);

protected:
  VALUE  execute ();

  virtual VALUE do_exec () = 0;

  bool exception_ {};
  CORBA::Exception* corba_ex_ {};
};

R2TAO_POA_BlockedRegionCallerBase::~R2TAO_POA_BlockedRegionCallerBase() noexcept(false)
{
  if (this->exception_)
  {
    if (corba_ex_)
    {
      std::unique_ptr<CORBA::Exception> e_ptr(corba_ex_);
      corba_ex_->_raise ();
    }
    else
    {
      throw ::CORBA::UNKNOWN ();
    }
  }
}

VALUE R2TAO_POA_BlockedRegionCallerBase::call ()
{
  return r2tao_blocking_call (R2TAO_POA_BlockedRegionCallerBase::blocking_func_exec, this);
}

VALUE R2TAO_POA_BlockedRegionCallerBase::blocking_func_exec (void *arg)
{
  R2TAO_POA_BlockedRegionCallerBase* call_obj =
      reinterpret_cast<R2TAO_POA_BlockedRegionCallerBase*> (arg);

  return call_obj->execute ();
}

VALUE R2TAO_POA_BlockedRegionCallerBase::execute ()
{
  try {
    return this->do_exec ();
  }
  catch (const CORBA::Exception& ex) {
    this->exception_ = true;
    this->corba_ex_ = ex._tao_duplicate ();
    return Qfalse;
  }
  catch(...) {
    this->exception_ = true;
    return Qfalse;
  }
}

//-------------------------------------------------------------------
//  ObjectId functions
//
//===================================================================

VALUE r2tao_ObjectId_t2r(const PortableServer::ObjectId& oid)
{
  return rb_funcall (r2tao_cObjectId,
                     new_ID,
                     1,
                     rb_str_new ((char*)oid.get_buffer (), (long)oid.length ()));
}

static PortableServer::ObjectId* r2tao_ObjectId_r2t(VALUE oid)
{
  VALUE oidstr =
    rb_type (oid) == T_STRING ? oid : rb_str_to_str (oid);
  CORBA::ULong buflen = static_cast<CORBA::ULong> (RSTRING_LEN (oidstr));
  CORBA::Octet* buf =
      PortableServer::ObjectId::allocbuf (buflen);
  ACE_OS::memcpy (buf, RSTRING_PTR (oidstr), static_cast<size_t> (buflen));
  return new PortableServer::ObjectId (buflen, buflen, buf, true);
}

//-------------------------------------------------------------------
//  Ruby PortableServer class methods
//
//===================================================================

VALUE r2tao_PS_string_to_ObjectId(VALUE /*self*/, VALUE string)
{
  string = rb_check_convert_type(string, T_STRING, "String", "to_s");
  R2TAO_TRY
  {
    PortableServer::ObjectId_var oid = PortableServer::string_to_ObjectId (RSTRING_PTR (string));
    return r2tao_ObjectId_t2r (oid);
  }
  R2TAO_CATCH;
  return Qnil;
}

VALUE r2tao_PS_ObjectId_to_string(VALUE /*self*/, VALUE oid)
{
  R2TAO_TRY
  {
    PortableServer::ObjectId_var _oid = r2tao_ObjectId_r2t(oid);
    CORBA::String_var str = PortableServer::ObjectId_to_string (_oid);
    return rb_str_new2 (str.in ());
  }
  R2TAO_CATCH;
  return Qnil;
}

//-------------------------------------------------------------------
//  Ruby POA functions
//
//===================================================================

class R2TAO_POA_BlockedRegionCaller : public R2TAO_POA_BlockedRegionCallerBase
{
public:
  R2TAO_POA_BlockedRegionCaller (PortableServer::POA_ptr _poa)
    : poa_ (PortableServer::POA::_duplicate (_poa))
  {}
  ~R2TAO_POA_BlockedRegionCaller () override = default;

protected:
  //virtual VALUE do_exec () = 0;

  PortableServer::POA_var poa_;
};

R2TAO_POA_EXPORT PortableServer::POA_ptr r2tao_POA_r2t(VALUE obj)
{
  CORBA::Object_ptr _obj = r2corba_Object_r2t (obj);
  R2TAO_TRY
  {
    return PortableServer::POA::_narrow (_obj);
  }
  R2TAO_CATCH;
  return PortableServer::POA::_nil();
}

class R2TAO_POA_BlockedDestroy : public R2TAO_POA_BlockedRegionCaller
{
public:
  R2TAO_POA_BlockedDestroy (PortableServer::POA_ptr _poa, bool _etherealize, bool _wait_for_completion)
    : R2TAO_POA_BlockedRegionCaller (_poa),
      etherealize_ (_etherealize),
      wait_for_completion_ (_wait_for_completion)
  {}
  ~R2TAO_POA_BlockedDestroy () override = default;

protected:
  virtual VALUE do_exec ();

  bool etherealize_;
  bool wait_for_completion_;
};

VALUE R2TAO_POA_BlockedDestroy::do_exec ()
{
  this->poa_->destroy (this->etherealize_, this->wait_for_completion_);
  return Qnil;
}

VALUE r2tao_POA_destroy(VALUE self, VALUE etherealize, VALUE wait_for_completion)
{
  R2TAO_TRY
  {
    PortableServer::POA_var _poa = r2tao_POA_r2t (self);
    R2TAO_POA_BlockedDestroy blocked_destroy (_poa.in (), etherealize == Qtrue, wait_for_completion == Qtrue);
    blocked_destroy.call ();
  }
  R2TAO_CATCH;
  return Qnil;
}
VALUE r2tao_POA_the_name(VALUE self)
{
  VALUE rpoaname = Qnil;
  R2TAO_TRY
  {
    PortableServer::POA_var _poa = r2tao_POA_r2t (self);
    CORBA::String_var _poaname = _poa->the_name ();
    rpoaname = rb_str_new2 (_poaname.in ());
  }
  R2TAO_CATCH;
  return rpoaname;
}
VALUE r2tao_POA_the_POAManager(VALUE self)
{
  VALUE rpoa_man = Qnil;
  R2TAO_TRY
  {
    PortableServer::POA_var _poa = r2tao_POA_r2t (self);
    PortableServer::POAManager_var _poa_manager = _poa->the_POAManager ();

    CORBA::Object_ptr obj =
        dynamic_cast<CORBA::Object_ptr> (_poa_manager.in ());
    rpoa_man = r2corba_Object_t2r (obj);
    rpoa_man = FN_narrow.invoke (r2tao_nsPOAManager, 1, &rpoa_man);
  }
  R2TAO_CATCH;
  return rpoa_man;
}
VALUE r2tao_POA_the_parent(VALUE self)
{
  VALUE rpoa_parent = Qnil;
  R2TAO_TRY
  {
    PortableServer::POA_var _poa = r2tao_POA_r2t (self);
    PortableServer::POA_var _poa_parent = _poa->the_parent ();

    rpoa_parent =
        r2corba_Object_t2r(dynamic_cast<CORBA::Object_ptr> (_poa_parent.in ()));
    rpoa_parent = FN_narrow.invoke (r2tao_nsPOA, 1, &rpoa_parent);
  }
  R2TAO_CATCH;
  return rpoa_parent;
}
VALUE r2tao_POA_the_children(VALUE self)
{
  VALUE rpoa_list = Qnil;
  R2TAO_TRY
  {
    PortableServer::POA_var _poa = r2tao_POA_r2t (self);
    PortableServer::POAList_var _poa_list = _poa->the_children ();

    rpoa_list = rb_ary_new2 (ULONG2NUM (_poa_list->length ()));
    for (CORBA::ULong l=0; l<_poa_list->length () ;++l)
    {
      PortableServer::POA_ptr _poa_child = _poa_list[l];
      VALUE rpoa_child =
          r2corba_Object_t2r(dynamic_cast<CORBA::Object_ptr> (_poa_child));
      rb_ary_push (rpoa_list, FN_narrow.invoke (r2tao_nsPOA, 1, &rpoa_child));
    }
  }
  R2TAO_CATCH;
  return rpoa_list;
}

class R2TAO_POA_BlockedActivateObject : public R2TAO_POA_BlockedRegionCaller
{
public:
  R2TAO_POA_BlockedActivateObject (PortableServer::POA_ptr _poa, DSI_Servant* _svnt)
    : R2TAO_POA_BlockedRegionCaller (_poa),
      servant_ (_svnt),
      with_id_ (false)
  {}
  R2TAO_POA_BlockedActivateObject (PortableServer::POA_ptr _poa, DSI_Servant* _svnt, PortableServer::ObjectId* oid)
    : R2TAO_POA_BlockedRegionCaller (_poa),
      servant_ (_svnt),
      oid_ (oid),
      with_id_ (true)
  {}
  ~R2TAO_POA_BlockedActivateObject () override = default;

  const PortableServer::ObjectId& oid () const { return this->oid_.in (); }

protected:
  VALUE do_exec () override;

  DSI_Servant* servant_ {};
  PortableServer::ObjectId_var oid_;
  bool with_id_;
};

VALUE R2TAO_POA_BlockedActivateObject::do_exec ()
{
  if (this->with_id_)
    this->poa_->activate_object_with_id (this->oid_.in (), this->servant_);
  else
    this->oid_ = this->poa_->activate_object (this->servant_);
  return Qnil;
}

VALUE r2tao_POA_activate_object(VALUE self, VALUE servant)
{
  r2tao_check_type(servant, r2tao_cServant);

  R2TAO_TRY
  {
    try
    {
      PortableServer::POA_var _poa = r2tao_POA_r2t (self);

      DSI_Servant* _servant {};
      if (DATA_PTR (servant) == 0)
      {
        _servant = new DSI_Servant (servant);
      }
      else
      {
        _servant = static_cast<DSI_Servant*> (DATA_PTR (servant));
      }
      R2TAO_POA_BlockedActivateObject blocked_actobj (_poa.in (), _servant);
      blocked_actobj.call ();

      _servant->activate_servant (); // activate Ruby servant

      return r2tao_ObjectId_t2r (blocked_actobj.oid ());
    }
    catch (const PortableServer::POA::WrongPolicy& ex)
    {
      rb_exc_raise (rb_class_new_instance (0, 0, r2tao_x_POA_WrongPolicy));
    }
    catch (const PortableServer::POA::ServantAlreadyActive& ex)
    {
      rb_exc_raise (rb_class_new_instance (0, 0, r2tao_x_POA_ServantAlreadyActive));
    }
  }
  R2TAO_CATCH;
  return Qnil;
}

VALUE r2tao_POA_activate_object_with_id(VALUE self, VALUE oid, VALUE servant)
{
  R2TAO_TRY
  {
    try
    {
      PortableServer::POA_var _poa = r2tao_POA_r2t (self);

      DSI_Servant* _servant {};
      if (DATA_PTR (servant) == 0)
      {
        _servant = new DSI_Servant (servant);
      }
      else
      {
        _servant = static_cast<DSI_Servant*> (DATA_PTR (servant));
      }
      R2TAO_POA_BlockedActivateObject blocked_actobj (_poa.in (), _servant, r2tao_ObjectId_r2t(oid));
      blocked_actobj.call ();

      _servant->activate_servant (); // activate Ruby servant
    }
    catch (const PortableServer::POA::WrongPolicy& ex)
    {
      rb_exc_raise (rb_class_new_instance (0, 0, r2tao_x_POA_WrongPolicy));
    }
    catch (const PortableServer::POA::ServantAlreadyActive& ex)
    {
      rb_exc_raise (rb_class_new_instance (0, 0, r2tao_x_POA_ServantAlreadyActive));
    }
    catch (const PortableServer::POA::ObjectAlreadyActive& ex)
    {
      rb_exc_raise (rb_class_new_instance (0, 0, r2tao_x_POA_ObjectAlreadyActive));
    }
  }
  R2TAO_CATCH;
  return Qnil;
}

class R2TAO_POA_BlockedDeactivateObject : public R2TAO_POA_BlockedRegionCaller
{
public:
  R2TAO_POA_BlockedDeactivateObject (PortableServer::POA_ptr _poa, PortableServer::ObjectId* oid)
    : R2TAO_POA_BlockedRegionCaller (_poa),
      oid_ (oid)
  {}
  ~R2TAO_POA_BlockedDeactivateObject () override = default;

protected:
  VALUE do_exec () override;

  PortableServer::ObjectId_var oid_;
};

VALUE R2TAO_POA_BlockedDeactivateObject::do_exec ()
{
  this->poa_->deactivate_object (this->oid_.in ());
  return Qnil;
}

VALUE r2tao_POA_deactivate_object(VALUE self, VALUE oid)
{
  R2TAO_TRY
  {
    try
    {
      PortableServer::POA_var _poa = r2tao_POA_r2t (self);

      R2TAO_POA_BlockedDeactivateObject blocked_deactobj (_poa.in (), r2tao_ObjectId_r2t(oid));
      blocked_deactobj.call ();
    }
    catch (const PortableServer::POA::WrongPolicy& ex)
    {
      rb_exc_raise (rb_class_new_instance (0, 0, r2tao_x_POA_WrongPolicy));
    }
    catch (const PortableServer::POA::ObjectNotActive& ex)
    {
      rb_exc_raise (rb_class_new_instance (0, 0, r2tao_x_POA_ObjectNotActive));
    }
  }
  R2TAO_CATCH;
  return Qnil;
}

VALUE r2tao_POA_create_reference(VALUE self, VALUE repoid)
{
  Check_Type(repoid, T_STRING);
  R2TAO_TRY
  {
    try
    {
      PortableServer::POA_var _poa = r2tao_POA_r2t (self);

      CORBA::Object_var obj = _poa->create_reference (RSTRING_PTR (repoid));
      return r2corba_Object_t2r(obj.in ());
    }
    catch (const PortableServer::POA::WrongPolicy& ex)
    {
      rb_exc_raise (rb_class_new_instance (0, 0, r2tao_x_POA_WrongPolicy));
    }
  }
  R2TAO_CATCH;
  return Qnil;
}
VALUE r2tao_POA_create_reference_with_id(VALUE self, VALUE oid, VALUE repoid)
{
  Check_Type(repoid, T_STRING);
  R2TAO_TRY
  {
    try
    {
      PortableServer::ObjectId_var _oid = r2tao_ObjectId_r2t(oid);
      PortableServer::POA_var _poa = r2tao_POA_r2t (self);

      CORBA::Object_var obj = _poa->create_reference_with_id (_oid.in (), RSTRING_PTR (repoid));
      return r2corba_Object_t2r(obj.in ());
    }
    catch (const PortableServer::POA::WrongPolicy& ex)
    {
      rb_exc_raise (rb_class_new_instance (0, 0, r2tao_x_POA_WrongPolicy));
    }
  }
  R2TAO_CATCH;
  return Qnil;
}
VALUE r2tao_POA_servant_to_id(VALUE self, VALUE servant)
{
  r2tao_check_type(servant, r2tao_cServant);

  R2TAO_TRY
  {
    try
    {
      PortableServer::POA_var _poa = r2tao_POA_r2t (self);

      DSI_Servant* _servant = static_cast<DSI_Servant*> (DATA_PTR (servant));
      PortableServer::ObjectId_var _oid = _poa->servant_to_id (_servant);
      return r2tao_ObjectId_t2r (_oid.in ());
    }
    catch (const PortableServer::POA::WrongPolicy& ex)
    {
      rb_exc_raise (rb_class_new_instance (0, 0, r2tao_x_POA_WrongPolicy));
    }
    catch (const PortableServer::POA::ServantNotActive& ex)
    {
      rb_exc_raise (rb_class_new_instance (0, 0, r2tao_x_POA_ServantNotActive));
    }
  }
  R2TAO_CATCH;
  return Qnil;
}
VALUE r2tao_POA_servant_to_reference(VALUE self, VALUE servant)
{
  r2tao_check_type(servant, r2tao_cServant);

  R2TAO_TRY
  {
    try
    {
      PortableServer::POA_var _poa = r2tao_POA_r2t (self);

      DSI_Servant* _servant = static_cast<DSI_Servant*> (DATA_PTR (servant));
      CORBA::Object_var _obj = _poa->servant_to_reference (_servant);
      return r2corba_Object_t2r(_obj.in ());
    }
    catch (const PortableServer::POA::WrongPolicy& ex)
    {
      rb_exc_raise (rb_class_new_instance (0, 0, r2tao_x_POA_WrongPolicy));
    }
    catch (const PortableServer::POA::ServantNotActive& ex)
    {
      rb_exc_raise (rb_class_new_instance (0, 0, r2tao_x_POA_ServantNotActive));
    }
  }
  R2TAO_CATCH;
  return Qnil;
}
VALUE r2tao_POA_reference_to_servant(VALUE self, VALUE obj)
{
  R2TAO_TRY
  {
    try
    {
      CORBA::Object_ptr _obj = r2corba_Object_r2t (obj);
      PortableServer::POA_var _poa = r2tao_POA_r2t (self);

      PortableServer::Servant _srv = _poa->reference_to_servant (_obj);
      DSI_Servant* _servant = dynamic_cast<DSI_Servant*> (_srv);
      return _servant->rbServant ();
    }
    catch (const PortableServer::POA::WrongPolicy& ex)
    {
      rb_exc_raise (rb_class_new_instance (0, 0, r2tao_x_POA_WrongPolicy));
    }
    catch (const PortableServer::POA::ObjectNotActive& ex)
    {
      rb_exc_raise (rb_class_new_instance (0, 0, r2tao_x_POA_ObjectNotActive));
    }
    catch (const PortableServer::POA::WrongAdapter& ex)
    {
      rb_exc_raise (rb_class_new_instance (0, 0, r2tao_x_POA_WrongAdapter));
    }
  }
  R2TAO_CATCH;
  return Qnil;
}
VALUE r2tao_POA_reference_to_id(VALUE self, VALUE obj)
{
  R2TAO_TRY
  {
    try
    {
      CORBA::Object_ptr _obj = r2corba_Object_r2t (obj);
      PortableServer::POA_var _poa = r2tao_POA_r2t (self);

      PortableServer::ObjectId_var _oid = _poa->reference_to_id (_obj);
      return r2tao_ObjectId_t2r (_oid.in ());
    }
    catch (const PortableServer::POA::WrongPolicy& ex)
    {
      rb_exc_raise (rb_class_new_instance (0, 0, r2tao_x_POA_WrongPolicy));
    }
    catch (const PortableServer::POA::WrongAdapter& ex)
    {
      rb_exc_raise (rb_class_new_instance (0, 0, r2tao_x_POA_WrongAdapter));
    }
  }
  R2TAO_CATCH;
  return Qnil;
}
VALUE r2tao_POA_id_to_servant(VALUE self, VALUE oid)
{
  R2TAO_TRY
  {
    try
    {
      PortableServer::ObjectId_var _oid = r2tao_ObjectId_r2t(oid);
      PortableServer::POA_var _poa = r2tao_POA_r2t (self);

      PortableServer::Servant _srv = _poa->id_to_servant (_oid.in ());
      DSI_Servant* _servant = dynamic_cast<DSI_Servant*> (_srv);
      return _servant->rbServant ();
    }
    catch (const PortableServer::POA::WrongPolicy& ex)
    {
      rb_exc_raise (rb_class_new_instance (0, 0, r2tao_x_POA_WrongPolicy));
    }
    catch (const PortableServer::POA::ObjectNotActive& ex)
    {
      rb_exc_raise (rb_class_new_instance (0, 0, r2tao_x_POA_ObjectNotActive));
    }
  }
  R2TAO_CATCH;
  return Qnil;
}
VALUE r2tao_POA_id_to_reference(VALUE self, VALUE oid)
{
  R2TAO_TRY
  {
    try
    {
      PortableServer::ObjectId_var _oid = r2tao_ObjectId_r2t(oid);
      PortableServer::POA_var _poa = r2tao_POA_r2t (self);

      CORBA::Object_var _obj = _poa->id_to_reference (_oid.in ());
      return r2corba_Object_t2r(_obj.in ());
    }
    catch (const PortableServer::POA::WrongPolicy& ex)
    {
      rb_exc_raise (rb_class_new_instance (0, 0, r2tao_x_POA_WrongPolicy));
    }
    catch (const PortableServer::POA::ObjectNotActive& ex)
    {
      rb_exc_raise (rb_class_new_instance (0, 0, r2tao_x_POA_ObjectNotActive));
    }
  }
  R2TAO_CATCH;
  return Qnil;
}

VALUE r2tao_POA_create_POA(VALUE self, VALUE name, VALUE poaman, VALUE policies)
{
  VALUE poaret = Qnil;
  CORBA::ULong alen = 0;

  name = rb_check_convert_type(name, T_STRING, "String", "to_s");
  r2tao_check_type (poaman, r2tao_nsPOAManager);
  if (policies != Qnil)
  {
    VALUE rPolicyList_tc = rb_eval_string ("CORBA::PolicyList._tc");
    rb_funcall (rPolicyList_tc, rb_intern ("validate"), 1, policies);
    alen = static_cast<unsigned long> (RARRAY_LEN (policies));
  }

  PortableServer::POA_var _poa = r2tao_POA_r2t (self);
  PortableServer::POAManager_var _poa_man = r2tao_POAManager_r2t (poaman);
  R2TAO_TRY
  {
    try
    {
      CORBA::PolicyList pollist(alen);
      pollist.length (alen);
      for (CORBA::ULong l=0; l<alen ;++l)
      {
        VALUE pol = rb_ary_entry (policies, l);
        CORBA::Object_ptr obj = r2corba_Object_r2t(pol);
        pollist[l] = CORBA::Policy::_duplicate (dynamic_cast<CORBA::Policy_ptr> (obj));
      }

      PortableServer::POA_var _newpoa =
          _poa->create_POA (RSTRING_PTR (name), _poa_man.in (), pollist);

      poaret = r2corba_Object_t2r (dynamic_cast<CORBA::Object_ptr> (_newpoa.in ()));
      poaret = FN_narrow.invoke (r2tao_nsPOA, 1, &poaret);
    }
    catch (const PortableServer::POA::InvalidPolicy& ex)
    {
      VALUE index = INT2NUM (ex.index);
      rb_exc_raise (rb_class_new_instance (1, &index, r2tao_x_POA_InvalidPolicy));
    }
    catch (const PortableServer::POA::AdapterAlreadyExists& ex)
    {
      rb_exc_raise (rb_class_new_instance (0, 0, r2tao_x_POA_AdapterAlreadyExists));
    }
  }
  R2TAO_CATCH;

  return poaret;
}

VALUE r2tao_POA_find_POA(VALUE self, VALUE name, VALUE activate)
{
  VALUE poaret = Qnil;

  name = rb_check_convert_type(name, T_STRING, "String", "to_s");

  R2TAO_TRY
  {
    try
    {
      PortableServer::POA_var _poa = r2tao_POA_r2t (self);
      PortableServer::POA_var _newpoa =
          _poa->find_POA (RSTRING_PTR (name), activate == Qtrue);

      poaret = r2corba_Object_t2r (dynamic_cast<CORBA::Object_ptr> (_newpoa.in ()));
      poaret = FN_narrow.invoke (r2tao_nsPOA, 1, &poaret);
    }
    catch (const PortableServer::POA::AdapterNonExistent& ex)
    {
      rb_exc_raise (rb_class_new_instance (0, 0, r2tao_x_POA_AdapterNonExistent));
    }
  }
  R2TAO_CATCH;

  return poaret;
}

VALUE r2tao_POA_id(VALUE self)
{
  VALUE rid = Qnil;
  R2TAO_TRY
  {
    PortableServer::POA_var _poa = r2tao_POA_r2t (self);
    CORBA::OctetSeq_var _id = _poa->id ();
    rid = rb_funcall (rb_eval_string ("CORBA::OctetSeq"),
                      new_ID,
                      1,
                      rb_str_new ((char*)_id->get_buffer (), (long)_id->length ()));
  }
  R2TAO_CATCH;
  return rid;
}

//-------------------------------------------------------------------
//  Ruby POAManager functions
//
//===================================================================

PortableServer::POAManager_ptr r2tao_POAManager_r2t(VALUE obj)
{
  CORBA::Object_ptr _obj = r2corba_Object_r2t (obj);
  return PortableServer::POAManager::_narrow (_obj);
}

class R2TAO_POAMan_BlockedRegionCaller : public R2TAO_POA_BlockedRegionCallerBase
{
public:
  R2TAO_POAMan_BlockedRegionCaller (PortableServer::POAManager_ptr _poaman)
    : poaman_ (PortableServer::POAManager::_duplicate (_poaman))
  {}
  ~R2TAO_POAMan_BlockedRegionCaller () override = default;

protected:
  //virtual VALUE do_exec () = 0;

  PortableServer::POAManager_var poaman_;
};

class R2TAO_POAMan_BlockedActivate : public R2TAO_POAMan_BlockedRegionCaller
{
public:
  R2TAO_POAMan_BlockedActivate (PortableServer::POAManager_ptr _poaman)
    : R2TAO_POAMan_BlockedRegionCaller (_poaman)
  {}
  ~R2TAO_POAMan_BlockedActivate () override = default;

protected:
  VALUE do_exec () override;
};

VALUE R2TAO_POAMan_BlockedActivate::do_exec ()
{
  this->poaman_->activate ();
  return Qnil;
}

VALUE r2tao_POAManager_activate(VALUE self)
{
  PortableServer::POAManager_var _poa_man = r2tao_POAManager_r2t (self);
  R2TAO_TRY
  {
    try
    {
      R2TAO_POAMan_BlockedActivate blocked_activate (_poa_man.in ());
      blocked_activate.call ();
    }
    catch (const PortableServer::POAManager::AdapterInactive& ex)
    {
      rb_exc_raise (rb_class_new_instance (0, 0, r2tao_x_POAManager_AdapterInactive));
    }
  }
  R2TAO_CATCH;
  return Qnil;
}

class R2TAO_POAMan_BlockedHoldReq : public R2TAO_POAMan_BlockedRegionCaller
{
public:
  R2TAO_POAMan_BlockedHoldReq (PortableServer::POAManager_ptr _poaman, bool _wait_for_completion)
    : R2TAO_POAMan_BlockedRegionCaller (_poaman),
      wait_for_completion_ (_wait_for_completion)
  {}
  ~R2TAO_POAMan_BlockedHoldReq () override = default;

protected:
  VALUE do_exec () override;

  bool wait_for_completion_;
};

VALUE R2TAO_POAMan_BlockedHoldReq::do_exec ()
{
  this->poaman_->hold_requests (this->wait_for_completion_);
  return Qnil;
}

VALUE r2tao_POAManager_hold_requests(VALUE self, VALUE wait_for_completion)
{
  PortableServer::POAManager_var _poa_man = r2tao_POAManager_r2t (self);
  R2TAO_TRY
  {
    try
    {
      R2TAO_POAMan_BlockedHoldReq blocked_holdreq (_poa_man.in (), wait_for_completion == Qtrue);
      blocked_holdreq.call ();
    }
    catch (const PortableServer::POAManager::AdapterInactive& ex)
    {
      rb_exc_raise (rb_class_new_instance (0, 0, r2tao_x_POAManager_AdapterInactive));
    }
  }
  R2TAO_CATCH;
  return Qnil;
}

class R2TAO_POAMan_BlockedDiscardReq : public R2TAO_POAMan_BlockedRegionCaller
{
public:
  R2TAO_POAMan_BlockedDiscardReq (PortableServer::POAManager_ptr _poaman, bool _wait_for_completion)
    : R2TAO_POAMan_BlockedRegionCaller (_poaman),
      wait_for_completion_ (_wait_for_completion)
  {}
  ~R2TAO_POAMan_BlockedDiscardReq () override = default;

protected:
  VALUE do_exec () override;

  bool const wait_for_completion_;
};

VALUE R2TAO_POAMan_BlockedDiscardReq::do_exec ()
{
  this->poaman_->discard_requests (this->wait_for_completion_);
  return Qnil;
}

VALUE r2tao_POAManager_discard_requests(VALUE self, VALUE wait_for_completion)
{
  PortableServer::POAManager_var _poa_man = r2tao_POAManager_r2t (self);
  R2TAO_TRY
  {
    try
    {
      R2TAO_POAMan_BlockedDiscardReq blocked_discardreq (_poa_man.in (), wait_for_completion == Qtrue);
      blocked_discardreq.call ();
    }
    catch (const PortableServer::POAManager::AdapterInactive& ex)
    {
      rb_exc_raise (rb_class_new_instance (0, 0, r2tao_x_POAManager_AdapterInactive));
    }
  }
  R2TAO_CATCH;
  return Qnil;
}

class R2TAO_POAMan_BlockedDeactivate : public R2TAO_POAMan_BlockedRegionCaller
{
public:
  R2TAO_POAMan_BlockedDeactivate (PortableServer::POAManager_ptr _poaman, bool _etherealize, bool _wait_for_completion)
    : R2TAO_POAMan_BlockedRegionCaller (_poaman),
      etherealize_ (_etherealize),
      wait_for_completion_ (_wait_for_completion)
  {}
  ~R2TAO_POAMan_BlockedDeactivate () override = default;

protected:
  VALUE do_exec () override;

  bool const etherealize_;
  bool const wait_for_completion_;
};

VALUE R2TAO_POAMan_BlockedDeactivate::do_exec ()
{
  this->poaman_->deactivate (this->etherealize_, this->wait_for_completion_);
  return Qnil;
}

VALUE r2tao_POAManager_deactivate(VALUE self, VALUE etherealize, VALUE wait_for_completion)
{
  PortableServer::POAManager_var _poa_man = r2tao_POAManager_r2t (self);
  R2TAO_TRY
  {
    try
    {
      R2TAO_POAMan_BlockedDeactivate blocked_deactivate (_poa_man.in (), etherealize == Qtrue, wait_for_completion == Qtrue);
      blocked_deactivate.call ();
    }
    catch (const PortableServer::POAManager::AdapterInactive& ex)
    {
      rb_exc_raise (rb_class_new_instance (0, 0, r2tao_x_POAManager_AdapterInactive));
    }
  }
  R2TAO_CATCH;
  return Qnil;
}
VALUE r2tao_POAManager_get_state(VALUE self)
{
  PortableServer::POAManager_var _poa_man = r2tao_POAManager_r2t (self);
  R2TAO_TRY
  {
    return ULONG2NUM (static_cast<unsigned long> (_poa_man->get_state ()));
  }
  R2TAO_CATCH;
  return Qnil;
}
VALUE r2tao_POAManager_get_id(VALUE self)
{
  PortableServer::POAManager_var _poa_man = r2tao_POAManager_r2t (self);
  R2TAO_TRY
  {
    return rb_str_new2 (_poa_man->get_id ());
  }
  R2TAO_CATCH;
  return Qnil;
}
VALUE r2tao_POAManager_get_orb(VALUE self)
{
  PortableServer::POAManager_var _poa_man = r2tao_POAManager_r2t (self);
  R2TAO_TRY
  {
    CORBA::ORB_var _orb = _poa_man->_get_orb ();
    return r2corba_ORB_t2r(_orb.in ());
  }
  R2TAO_CATCH;
  return Qnil;
}
