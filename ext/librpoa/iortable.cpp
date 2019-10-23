/*--------------------------------------------------------------------
# iortable.cpp - R2TAO TAO IORTable support (non-standard extension)
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
#include "tao/ORB.h"
#include "tao/IORTable/IORTable.h"
#include "object.h"
#include "exception.h"
#include "orb.h"

#define RUBY_INVOKE_FUNC RUBY_ALLOC_FUNC

static VALUE r2tao_nsIORTable;
static VALUE r2tao_cIORTableLocator;
static VALUE r2tao_cIORTableNotFoundX;

static VALUE r2tao_IORTable_bind(VALUE self, VALUE obj_key, VALUE ior);
static VALUE r2tao_IORTable_rebind(VALUE self, VALUE obj_key, VALUE ior);
static VALUE r2tao_IORTable_unbind(VALUE self, VALUE obj_key);
static VALUE r2tao_IORTable_set_locator(VALUE self, VALUE locator);

void r2tao_init_IORTable()
{
  VALUE klass;

  r2tao_nsIORTable = klass = rb_eval_string("::R2CORBA::IORTable::Table");

  rb_define_method(klass, "bind", RUBY_METHOD_FUNC(r2tao_IORTable_bind), 2);
  rb_define_method(klass, "rebind", RUBY_METHOD_FUNC(r2tao_IORTable_rebind), 2);
  rb_define_method(klass, "unbind", RUBY_METHOD_FUNC(r2tao_IORTable_unbind), 1);
  rb_define_method(klass, "set_locator", RUBY_METHOD_FUNC(r2tao_IORTable_set_locator), 1);

  r2tao_cIORTableNotFoundX = rb_eval_string("::R2CORBA::IORTable::NotFound");
  r2tao_cIORTableLocator = rb_eval_string("::R2CORBA::IORTable::Locator");
}

//-------------------------------------------------------------------
//  Ruby IORTable methods
//
//===================================================================

class R2taoLocator : public IORTable::Locator
{
public:
  R2taoLocator(VALUE rbloc)
   : IORTable::Locator(), rb_locator_(rbloc)
  {
    // register to prevent GC
    r2tao_register_object (this->rb_locator_);
  }

  ~R2taoLocator()
  {
    // unregister to allow GC; mind GVL
    r2tao_call_thread_safe (R2taoLocator::thread_safe_unregister, this);
  }

  virtual char * locate (const char * object_key);

private:
  VALUE     rb_locator_;

  void inner_unregister ();
  char * inner_locate (const char * object_key);

  struct ThreadSafeArg
  {
    ThreadSafeArg (R2taoLocator* loc,
                   const char * obj_key)
      : locator_(loc),
        object_key_(obj_key),
        exception_ (false) {}
    R2taoLocator* locator_;
    const char * object_key_;
    bool exception_;
  };

  static void* thread_safe_invoke (void * arg);
  static void* thread_safe_unregister (void* arg);
};

void R2taoLocator::inner_unregister()
{
  // unregister to allow GC
  r2tao_unregister_object (this->rb_locator_);
}

// invocation helper for threadsafe calling of Ruby code
void* R2taoLocator::thread_safe_unregister (void * arg)
{
  R2taoLocator* tloc = reinterpret_cast<R2taoLocator*> (arg);

  try {
    tloc->inner_unregister ();
  }
  catch (...) {
    return ::CORBA::UNKNOWN (0, CORBA::COMPLETED_MAYBE)._tao_duplicate ();
  }
  return 0;
}

// invocation helper for threadsafe calling of Ruby code
void* R2taoLocator::thread_safe_invoke (void * arg)
{
  ThreadSafeArg* tca = reinterpret_cast<ThreadSafeArg*> (arg);

  try {
    return tca->locator_->inner_locate (tca->object_key_);
  }
  catch (const CORBA::SystemException& ex) {
    tca->exception_ = true;
    return ex._tao_duplicate ();
  }
  catch (...) {
    tca->exception_ = true;
    return ::CORBA::UNKNOWN (0, CORBA::COMPLETED_MAYBE)._tao_duplicate ();
  }
}

char* R2taoLocator::locate (const char * object_key)
{
  ThreadSafeArg tca_(this, object_key);

  void* rc = r2tao_call_thread_safe (R2taoLocator::thread_safe_invoke, &tca_);
  if (tca_.exception_)
  {
    CORBA::SystemException* exc = reinterpret_cast<CORBA::SystemException*> (rc);
    ACE_Auto_Basic_Ptr<CORBA::SystemException> e_ptr(exc);
    exc->_raise ();
    return 0;
  }
  else
  {
    return reinterpret_cast<char*> (rc);
  }
}

char* R2taoLocator::inner_locate (const char * object_key)
{
  static R2TAO_RBFuncall FN_locate ("locate", false);

  // invoke locator implementation
  VALUE rargs = rb_ary_new2 (1);
  rb_ary_push (rargs, object_key ? rb_str_new2 (object_key) : Qnil);
  VALUE ior = FN_locate.invoke (this->rb_locator_, rargs);
  if (FN_locate.has_caught_exception ())
  {
    // handle exception
    VALUE rexc = rb_gv_get ("$!");
    if (rb_obj_is_kind_of(rexc, r2tao_cIORTableNotFoundX) == Qtrue)
    {
      throw ::IORTable::NotFound();
    }
    else if(rb_obj_is_kind_of(rexc, r2tao_cSystemException) == Qtrue)
    {
      VALUE rid = rb_funcall (rexc, rb_intern ("_interface_repository_id"), 0);
      CORBA::SystemException* _exc = TAO::create_system_exception (RSTRING_PTR(rid));

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

  if (rb_type (ior) != T_STRING)
  {
    throw CORBA::BAD_PARAM(0, CORBA::COMPLETED_NO);
  }

  return CORBA::string_dup (RSTRING_PTR (ior));
}

IORTable::Table_ptr r2tao_IORTable_r2t(VALUE obj)
{
  CORBA::Object_ptr _obj = r2corba_Object_r2t (obj);
  return IORTable::Table::_narrow (_obj);
}

VALUE r2tao_IORTable_bind(VALUE self, VALUE obj_key, VALUE ior)
{
  obj_key = rb_check_convert_type (obj_key, T_STRING, "String", "to_s");
  ior = rb_check_convert_type (ior, T_STRING, "String", "to_s");
  R2TAO_TRY
  {
    IORTable::Table_var _iortbl = r2tao_IORTable_r2t (self);
    _iortbl->bind (RSTRING_PTR (obj_key), RSTRING_PTR (ior));
  }
  R2TAO_CATCH;
  return Qnil;
}

VALUE r2tao_IORTable_rebind(VALUE self, VALUE obj_key, VALUE ior)
{
  obj_key = rb_check_convert_type (obj_key, T_STRING, "String", "to_s");
  ior = rb_check_convert_type (ior, T_STRING, "String", "to_s");
  R2TAO_TRY
  {
    IORTable::Table_var _iortbl = r2tao_IORTable_r2t (self);
    _iortbl->rebind (RSTRING_PTR (obj_key), RSTRING_PTR (ior));
  }
  R2TAO_CATCH;
  return Qnil;
}

VALUE r2tao_IORTable_unbind(VALUE self, VALUE obj_key)
{
  obj_key = rb_check_convert_type (obj_key, T_STRING, "String", "to_s");
  R2TAO_TRY
  {
    IORTable::Table_var _iortbl = r2tao_IORTable_r2t (self);
    _iortbl->unbind (RSTRING_PTR (obj_key));
  }
  R2TAO_CATCH;
  return Qnil;
}

VALUE r2tao_IORTable_set_locator(VALUE self, VALUE locator)
{
  r2tao_check_type (locator, r2tao_cIORTableLocator);

  R2TAO_TRY
  {
    IORTable::Table_var _iortbl = r2tao_IORTable_r2t (self);

    IORTable::Locator_var _locvar = new R2taoLocator(locator);

    _iortbl->set_locator (_locvar.in ());
  }
  R2TAO_CATCH;
  return Qnil;
}
