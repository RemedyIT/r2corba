/*--------------------------------------------------------------------
# object.cpp - R2TAO CORBA Object support
#
# Author: Martin Corino
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the R2CORBA LICENSE which is
# included with this program.
#
# Copyright (c) Remedy IT Expertise BV
#------------------------------------------------------------------*/

#include "required.h"
#include "tao/DynamicInterface/Request.h"
#include "tao/DynamicInterface/DII_CORBA_methods.h"
#include "tao/DynamicInterface/Unknown_User_Exception.h"
#include "ace/Truncate.h"
#include "ace/Auto_Ptr.h"
#include "typecode.h"
#include "object.h"
#include "exception.h"
#include "orb.h"

R2TAO_EXPORT VALUE r2corba_cObject = 0;
R2TAO_EXPORT VALUE r2tao_cObject = 0;
static VALUE r2tao_cStub;
static VALUE r2tao_cRequest;
static VALUE r2corba_nsRequest;

VALUE r2tao_Object_orb(VALUE self);
VALUE r2tao_Object_object_id(VALUE self);

static int r2tao_IN_ARG;
static int r2tao_INOUT_ARG;
static int r2tao_OUT_ARG;

static VALUE ID_arg_list;
static VALUE ID_result_type;
static VALUE ID_exc_list;

static ID wrap_native_ID;
static ID objref_ID;

VALUE rCORBA_Object_is_a(VALUE self, VALUE type_id);
VALUE rCORBA_Object_get_interface(VALUE self);
VALUE rCORBA_Object_get_component(VALUE self);
VALUE rCORBA_Object_is_nil(VALUE self);
//VALUE rCORBA_Object_free_ref(VALUE self);
VALUE rCORBA_Object_duplicate(VALUE self);
VALUE rCORBA_Object_release(VALUE self);
VALUE rCORBA_Object_non_existent(VALUE self);
VALUE rCORBA_Object_is_equivalent(VALUE self, VALUE other);
VALUE rCORBA_Object_hash(VALUE self, VALUE max);
VALUE rCORBA_Object_get_policy(VALUE self, VALUE policy_type);
VALUE rCORBA_Object_repository_id(VALUE self);
VALUE rCORBA_Object_release(VALUE self);

VALUE ri_CORBA_Object_equal(VALUE self, VALUE that);
VALUE ri_CORBA_Object_hash(VALUE self);

VALUE rCORBA_Object_request(VALUE self, VALUE op);

VALUE rCORBA_Stub_invoke(int _argc, VALUE *_argv, VALUE self);

VALUE rCORBA_Request_target(VALUE self);
VALUE rCORBA_Request_operation(VALUE self);
VALUE rCORBA_Request_arguments(VALUE self, VALUE arg_list);
VALUE rCORBA_Request_return_value(VALUE self, VALUE result_type);
VALUE rCORBA_Request_invoke(int _argc, VALUE *_argv, VALUE self);
VALUE rCORBA_Request_send_oneway(VALUE self, VALUE arg_list);
VALUE rCORBA_Request_send_deferred(int _argc, VALUE *_argv, VALUE self);
VALUE rCORBA_Request_get_response(VALUE self);
VALUE rCORBA_Request_poll_response(VALUE self);

static void _object_free(void *ptr);

void
r2tao_Init_Object()
{
  VALUE klass;
  //VALUE nsCORBA_PortableStub;

  if (r2tao_cObject) return;

  ID_arg_list = rb_eval_string (":arg_list");
  ID_result_type = rb_eval_string (":result_type");
  ID_exc_list = rb_eval_string (":exc_list");

  wrap_native_ID = rb_intern ("_wrap_native");
  objref_ID = rb_intern ("objref_");

  // CORBA::Object
  r2corba_cObject = rb_eval_string ("::R2CORBA::CORBA::Object");
  // CORBA::Native::Object
  klass = r2tao_cObject =
    rb_define_class_under(r2tao_nsCORBA_Native, "Object", rb_cObject);

  rb_define_method(klass, "_is_a", RUBY_METHOD_FUNC(rCORBA_Object_is_a), 1);
  rb_define_method(klass, "_get_interface", RUBY_METHOD_FUNC(rCORBA_Object_get_interface), 0);
  rb_define_method(klass, "_get_component", RUBY_METHOD_FUNC(rCORBA_Object_get_component), 0);
  rb_define_method(klass, "_repository_id", RUBY_METHOD_FUNC(rCORBA_Object_repository_id), 0);
  rb_define_method(klass, "_is_nil", RUBY_METHOD_FUNC(rCORBA_Object_is_nil), 0);
  //rb_define_method(klass, "_free_ref", RUBY_METHOD_FUNC(rCORBA_Object_free_ref), 0);
  rb_define_method(klass, "_duplicate", RUBY_METHOD_FUNC(rCORBA_Object_duplicate), 0);
  rb_define_method(klass, "_release", RUBY_METHOD_FUNC(rCORBA_Object_release), 0);
  rb_define_method(klass, "_non_existent", RUBY_METHOD_FUNC(rCORBA_Object_non_existent), 0);
  rb_define_method(klass, "_is_equivalent", RUBY_METHOD_FUNC(rCORBA_Object_is_equivalent), 1);
  rb_define_method(klass, "_hash", RUBY_METHOD_FUNC(rCORBA_Object_hash), 1);
  rb_define_method(klass, "_get_policy", RUBY_METHOD_FUNC(rCORBA_Object_get_policy), 1);
  rb_define_method(klass, "_get_orb", RUBY_METHOD_FUNC(r2tao_Object_orb), 0);
  rb_define_method(klass, "_orb", RUBY_METHOD_FUNC(r2tao_Object_orb), 0);
  rb_define_method(klass, "_request", RUBY_METHOD_FUNC(rCORBA_Object_request), 1);

  rb_define_method(klass, "==", RUBY_METHOD_FUNC(ri_CORBA_Object_equal), 1);
  rb_define_method(klass, "eql?", RUBY_METHOD_FUNC(ri_CORBA_Object_equal), 1);
  rb_define_method(klass, "hash", RUBY_METHOD_FUNC(ri_CORBA_Object_hash), 0);

  // CORBA::Stub

  klass = r2tao_cStub = rb_define_module_under (r2tao_nsCORBA, "Stub");
  // R2TAO::CORBA::Stub._invoke(opname, arg_list, result_type = nil)
  // . arg_list = Array of Array-s containing name, argtype, tc [, value] for each arg
  // . result_type = typecode; if result_type == nil => oneway call
  // -> returns [ <return value>, <out arg1>, ..., <out argn> ] or nil (oneway) or throws exception
  rb_define_protected_method(klass, "_invoke", RUBY_METHOD_FUNC(rCORBA_Stub_invoke), -1);

  r2tao_IN_ARG = NUM2INT (rb_eval_string ("R2CORBA::CORBA::ARG_IN"));
  r2tao_INOUT_ARG = NUM2INT (rb_eval_string ("R2CORBA::CORBA::ARG_INOUT"));
  r2tao_OUT_ARG = NUM2INT (rb_eval_string ("R2CORBA::CORBA::ARG_OUT"));

  // R2CORBA::CORBA::Request
  r2corba_nsRequest = rb_eval_string ("R2CORBA::CORBA::Request");
  // create anonymous class for wrapping CORBA::Request
  klass = r2tao_cRequest = rb_class_new (rb_cObject);
  rb_global_variable (&r2tao_cRequest); // pin it down so GC doesn't get it
  // include the standard module
  rb_include_module (r2tao_cRequest, r2corba_nsRequest);
  // add native methods
  rb_define_method(klass, "target", RUBY_METHOD_FUNC(rCORBA_Request_target), 0);
  rb_define_method(klass, "operation", RUBY_METHOD_FUNC(rCORBA_Request_operation), 0);

  // R2TAO::CORBA::Request.invoke({:arg_list=>[], :result_type=>, :exc_list=>[]})
  // . arg_list = Array of Array-s containing name, argtype, tc [, value] for each arg
  // . result_type = typecode; if result_type == nil => oneway call
  // -> returns [ <return value>, <out arg1>, ..., <out argn> ] or nil (oneway) or throws exception
  rb_define_protected_method(klass, "_invoke", RUBY_METHOD_FUNC(rCORBA_Request_invoke), -1);
  rb_define_protected_method(klass, "_send_oneway", RUBY_METHOD_FUNC(rCORBA_Request_send_oneway), 1);
  rb_define_protected_method(klass, "_send_deferred", RUBY_METHOD_FUNC(rCORBA_Request_send_deferred), -1);
  rb_define_protected_method(klass, "_get_response", RUBY_METHOD_FUNC(rCORBA_Request_get_response), 0);
  rb_define_protected_method(klass, "_poll_response", RUBY_METHOD_FUNC(rCORBA_Request_poll_response), 0);
  rb_define_protected_method(klass, "_get_arguments", RUBY_METHOD_FUNC(rCORBA_Request_arguments), 1);
  rb_define_protected_method(klass, "_return_value", RUBY_METHOD_FUNC(rCORBA_Request_return_value), 1);
}

//-------------------------------------------------------------------
//  Ruby <-> TAO object conversions
//
//===================================================================

VALUE
r2tao_t2r(VALUE klass, CORBA::Object_ptr obj)
{
  VALUE ret;
  CORBA::Object_ptr o;

  o = CORBA::Object::_duplicate (obj);
  ret = Data_Wrap_Struct(klass, 0, _object_free, o);

  return ret;
}

R2TAO_EXPORT VALUE
r2tao_Object_t2r(CORBA::Object_ptr obj)
{
  return r2tao_t2r (r2tao_cObject, obj);
}

R2TAO_EXPORT CORBA::Object_ptr
r2tao_Object_r2t(VALUE obj)
{
  CORBA::Object_ptr ret;

  r2tao_check_type (obj, r2tao_cObject);
  Data_Get_Struct(obj, CORBA::Object, ret);
  return ret;
}

R2TAO_EXPORT VALUE
r2corba_Object_t2r(CORBA::Object_ptr obj)
{
  VALUE r2tao_obj = r2tao_Object_t2r(obj);
  return rb_funcall (r2corba_cObject, wrap_native_ID, 1, r2tao_obj);
}

R2TAO_EXPORT CORBA::Object_ptr
r2corba_Object_r2t(VALUE obj)
{
  r2tao_check_type (obj, r2corba_cObject);
  return r2tao_Object_r2t (rb_funcall (obj, objref_ID, 0));
}

static void
_object_free(void *ptr)
{
  CORBA::release (static_cast<CORBA::Object_ptr> (ptr));
}


static void
_request_free(void *ptr)
{
  CORBA::release (static_cast<CORBA::Request_ptr> (ptr));
}

VALUE
r2tao_Request_t2r(CORBA::Request_ptr req)
{
  VALUE ret;
  CORBA::Request_ptr o;

  o = CORBA::Request::_duplicate (req);
  ret = Data_Wrap_Struct(r2tao_cRequest, 0, _request_free, o);

  return ret;
}

CORBA::Request_ptr
r2tao_Request_r2t(VALUE obj)
{
  CORBA::Request_ptr ret;

  r2tao_check_type(obj, r2tao_cRequest);
  Data_Get_Struct(obj, CORBA::Request, ret);
  return ret;
}

//-------------------------------------------------------------------
//  CORBA::Object methods
//
//===================================================================

VALUE
r2tao_Object_orb(VALUE self)
{
  CORBA::ORB_var orb_ = r2tao_Object_r2t(self)->_get_orb ();
  return r2tao_ORB_t2r(orb_.in ());
}

VALUE
rCORBA_Object_get_interface(VALUE /*self*/)
{
  X_CORBA(NO_IMPLEMENT);
  return Qnil;
}

VALUE
rCORBA_Object_get_component(VALUE self)
{
  VALUE ret = Qnil;

  CORBA::Object_ptr obj = r2tao_Object_r2t (self);

  R2TAO_TRY
  {
    CORBA::Object_var comp = obj->_get_component ();
    ret = r2tao_Object_t2r (comp.in ());
  }
  R2TAO_CATCH;

  return ret;
}

VALUE
rCORBA_Object_repository_id(VALUE self)
{
  VALUE ret = Qnil;

  CORBA::Object_ptr obj = r2tao_Object_r2t (self);

  R2TAO_TRY
  {
    ret = rb_str_new2 (obj->_repository_id ());
  }
  R2TAO_CATCH;

  return ret;
}

VALUE
rCORBA_Object_is_nil(VALUE self)
{
  VALUE ret = Qnil;

  CORBA::Object_ptr obj = r2tao_Object_r2t (self);

  R2TAO_TRY
  {
    ret = CORBA::is_nil (obj) ? Qtrue: Qfalse;
  }
  R2TAO_CATCH;

  return ret;
}

/*
VALUE
rCORBA_Object_free_ref(VALUE self)
{
  CORBA::Object_ptr obj = r2tao_Object_r2t (self);

  R2TAO_TRY
  {
    if (!CORBA::is_nil (obj))
    {
      _object_free (DATA_PTR (self));
      DATA_PTR (self) = CORBA::Object::_nil ();
    }
  }
  R2TAO_CATCH;

  return self;
}
*/

VALUE
rCORBA_Object_duplicate(VALUE self)
{
  VALUE ret = Qnil;

  R2TAO_TRY
  {
    ret = r2tao_Object_t2r (r2tao_Object_r2t (self));
  }
  R2TAO_CATCH;

  return ret;
}

VALUE
rCORBA_Object_release(VALUE self)
{
  CORBA::Object_ptr obj = r2tao_Object_r2t (self);

  R2TAO_TRY
  {
    if (!CORBA::is_nil (obj))
    {
      _object_free (DATA_PTR (self));
      DATA_PTR (self) = CORBA::Object::_nil ();
    }
  }
  R2TAO_CATCH;

  return self;
}

VALUE
rCORBA_Object_non_existent(VALUE self)
{
  VALUE ret = Qnil;

  R2TAO_TRY
  {
    ret = r2tao_Object_r2t (self)->_non_existent () ? Qtrue: Qfalse;
  }
  R2TAO_CATCH;

  return ret;
}

VALUE
rCORBA_Object_is_equivalent(VALUE self, VALUE _other)
{
  CORBA::Object_ptr other, obj;
  VALUE ret = Qnil;

  obj = r2tao_Object_r2t (self);
  other = r2tao_Object_r2t (_other);

  R2TAO_TRY
  {
    ret = obj->_is_equivalent (other)? Qtrue: Qfalse;
  }
  R2TAO_CATCH;

  return ret;
}

VALUE
rCORBA_Object_hash(VALUE self, VALUE _max)
{
  CORBA::ULong ret=0, max;
  CORBA::Object_ptr obj = r2tao_Object_r2t (self);

  max = NUM2ULONG(_max);
  R2TAO_TRY
  {
    ret = obj->_hash(max);
  }
  R2TAO_CATCH;

  return ULONG2NUM(ret);
}

VALUE
rCORBA_Object_get_policy(VALUE /*self*/, VALUE /*policy_type*/)
{
  /* Implemented in policy extension */
  X_CORBA(NO_IMPLEMENT);
  return Qnil;
}

VALUE
ri_CORBA_Object_equal(VALUE self, VALUE that)
{
  CORBA::Object_ptr obj1, obj2;

  r2tao_check_type(that, r2tao_cObject);

  Data_Get_Struct(self, CORBA::Object, obj1);
  Data_Get_Struct(self, CORBA::Object, obj2);
  return (obj1 == obj2) ? Qtrue : Qfalse;
}

VALUE
ri_CORBA_Object_hash(VALUE self)
{
  return ULONG2NUM (ACE_Utils::truncate_cast<unsigned long> ((intptr_t)r2tao_Object_r2t (self)));
}

VALUE
rCORBA_Object_is_a(VALUE self, VALUE type_id)
{
  CORBA::Object_ptr obj;
  VALUE ret = Qnil;

  obj = r2tao_Object_r2t (self);
  Check_Type(type_id, T_STRING);

  R2TAO_TRY
  {
    int f = obj->_is_a (RSTRING_PTR (type_id));
    //::printf ("rCORBA_Object_is_a: %s -> %d\n", RSTRING_PTR (type_id), f);
    ret = f ? Qtrue: Qfalse;
  }
  R2TAO_CATCH;

  return ret;
}

VALUE
rCORBA_Object_request(VALUE self, VALUE op_name)
{
  CORBA::Object_ptr obj;
  CORBA::Request_var req;

  obj = r2tao_Object_r2t (self);
  Check_Type(op_name, T_STRING);

  R2TAO_TRY
  {
    req = obj->_request (RSTRING_PTR (op_name));
  }
  R2TAO_CATCH;

  return r2tao_Request_t2r (req.in ());
}

//-------------------------------------------------------------------
//  Request invocation helper methods
//
//===================================================================

static VALUE _r2tao_set_request_arguments(CORBA::Request_ptr _req, VALUE arg_list)
{
  if (TAO_debug_level > 9)
    ACE_DEBUG ((LM_INFO, "R2TAO (%P|%t) - set_request_arguments: entry\n"));

  long ret_val = 0;

  // clear all current args
  CORBA::ULong arg_num = _req->arguments ()->count ();
  while (arg_num > 0)
    _req->arguments ()->remove (--arg_num);

  if (!NIL_P (arg_list))
  {
    long arg_len = RARRAY_LEN (arg_list);
    for (long a=0; a<arg_len ;++a)
    {
      VALUE argspec = rb_ary_entry (arg_list, a);
      VALUE argname = rb_ary_entry (argspec, 0);
      int _arg_type = NUM2INT (rb_ary_entry (argspec, 1));
      CORBA::TypeCode_ptr _arg_tc = r2corba_TypeCode_r2t (rb_ary_entry (argspec, 2));

      if (_arg_type != r2tao_OUT_ARG)
      {
        VALUE arg_val = rb_ary_entry (argspec, 3);

        char *_arg_name = NIL_P (argname) ? 0 : RSTRING_PTR (argname);
        CORBA::Any& _arg = (_arg_type == r2tao_IN_ARG) ?
            (_arg_name ? _req->add_in_arg (_arg_name) : _req->add_in_arg ()) :
            (_arg_name ? _req->add_inout_arg (_arg_name) : _req->add_inout_arg ());

        if (_arg_type == r2tao_INOUT_ARG)
          ++ret_val;

        if (TAO_debug_level > 9)
          ACE_DEBUG ((LM_INFO, "R2TAO (%P|%t) - set_request_arguments: IN_ARG/INOUT_ARG - arg_name=%s\n",
                      _arg_name));

        // assign value to Any
        r2tao_Ruby2Any(_arg, _arg_tc, arg_val);
      }
      else
      {
        ++ret_val;
        char *_arg_name = NIL_P (argname) ? 0 : RSTRING_PTR (argname);
        CORBA::Any& _arg = _arg_name ?
            _req->add_out_arg (_arg_name) : _req->add_out_arg ();

        if (TAO_debug_level > 9)
          ACE_DEBUG ((LM_INFO, "R2TAO (%P|%t) - set_request_arguments: OUT_ARG - arg_name=%s\n",
                      _arg_name));

        // assign type info to Any
        r2tao_Ruby2Any(_arg, _arg_tc, Qnil);
      }
    }
  }
  return LONG2NUM (ret_val);
}

static VALUE _r2tao_set_request_exceptions(CORBA::Request_ptr _req, VALUE exc_list)
{
  if (TAO_debug_level > 9)
    ACE_DEBUG ((LM_INFO, "R2TAO (%P|%t) - set_request_exceptions: entry\n"));

  long exc_len = 0;
  // clear all current excepts
  CORBA::ULong x_num = _req->exceptions ()->count ();
  while (x_num > 0)
    _req->exceptions ()->remove (--x_num);

  if (!NIL_P (exc_list))
  {
    exc_len = RARRAY_LEN (exc_list);
    for (long x=0; x<exc_len ;++x)
    {
      VALUE exctc = rb_ary_entry (exc_list, x);
      CORBA::TypeCode_ptr _xtc = r2corba_TypeCode_r2t (exctc);
      _req->exceptions ()->add (_xtc);
    }
  }
  return LONG2NUM (exc_len);
}

class R2TAO_Request_BlockedRegionCaller
{
public:
  R2TAO_Request_BlockedRegionCaller (CORBA::Request_ptr req)
    : req_ (req),
      exception_ (false),
      corba_ex_ (0) {}
  virtual ~R2TAO_Request_BlockedRegionCaller () R2CORBA_NO_EXCEPT_FALSE;

  VALUE call ();

  static VALUE blocking_func_exec (void *arg);

protected:
  VALUE  execute ();

  virtual VALUE do_exec () = 0;

  CORBA::Request_ptr req_;
  bool exception_;
  CORBA::Exception* corba_ex_;
};

R2TAO_Request_BlockedRegionCaller::~R2TAO_Request_BlockedRegionCaller() R2CORBA_NO_EXCEPT_FALSE
{
  if (this->exception_)
  {
    if (corba_ex_)
    {
      ACE_Auto_Basic_Ptr<CORBA::Exception> e_ptr(corba_ex_);
      corba_ex_->_raise ();
    }
    else
    {
      throw ::CORBA::UNKNOWN ();
    }
  }
}

VALUE R2TAO_Request_BlockedRegionCaller::call ()
{
  return r2tao_blocking_call (R2TAO_Request_BlockedRegionCaller::blocking_func_exec, this);
}

VALUE R2TAO_Request_BlockedRegionCaller::blocking_func_exec (void *arg)
{
  R2TAO_Request_BlockedRegionCaller* call_obj =
      reinterpret_cast<R2TAO_Request_BlockedRegionCaller*> (arg);

  return call_obj->execute ();
}

VALUE R2TAO_Request_BlockedRegionCaller::execute ()
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

class R2TAO_Request_BlockedInvoke : public R2TAO_Request_BlockedRegionCaller
{
public:
  R2TAO_Request_BlockedInvoke (CORBA::Request_ptr req)
    : R2TAO_Request_BlockedRegionCaller (req) {}
  virtual ~R2TAO_Request_BlockedInvoke () {}

protected:
  virtual VALUE do_exec ();
};

VALUE R2TAO_Request_BlockedInvoke::do_exec ()
{
  this->req_->invoke ();
  return Qnil;
}

class R2TAO_Request_BlockedSendOneway : public R2TAO_Request_BlockedRegionCaller
{
public:
  R2TAO_Request_BlockedSendOneway (CORBA::Request_ptr req)
    : R2TAO_Request_BlockedRegionCaller (req) {}
  virtual ~R2TAO_Request_BlockedSendOneway () {}

protected:
  virtual VALUE do_exec ();
};

VALUE R2TAO_Request_BlockedSendOneway::do_exec ()
{
  this->req_->send_oneway ();
  return Qnil;
}

class R2TAO_Request_BlockedSendDeferred : public R2TAO_Request_BlockedRegionCaller
{
public:
  R2TAO_Request_BlockedSendDeferred (CORBA::Request_ptr req)
    : R2TAO_Request_BlockedRegionCaller (req) {}
  virtual ~R2TAO_Request_BlockedSendDeferred () {}

protected:
  virtual VALUE do_exec ();
};

VALUE R2TAO_Request_BlockedSendDeferred::do_exec ()
{
  this->req_->send_deferred ();
  return Qnil;
}

class R2TAO_Request_BlockedGetResponse : public R2TAO_Request_BlockedRegionCaller
{
public:
  R2TAO_Request_BlockedGetResponse (CORBA::Request_ptr req)
    : R2TAO_Request_BlockedRegionCaller (req) {}
  virtual ~R2TAO_Request_BlockedGetResponse () {}

protected:
  virtual VALUE do_exec ();
};

VALUE R2TAO_Request_BlockedGetResponse::do_exec ()
{
  this->req_->get_response ();
  return Qnil;
}

class R2TAO_Request_BlockedPollResponse : public R2TAO_Request_BlockedRegionCaller
{
public:
  R2TAO_Request_BlockedPollResponse (CORBA::Request_ptr req)
    : R2TAO_Request_BlockedRegionCaller (req) {}
  virtual ~R2TAO_Request_BlockedPollResponse () {}

protected:
  virtual VALUE do_exec ();
};

VALUE R2TAO_Request_BlockedPollResponse::do_exec ()
{
  return this->req_->poll_response () ? Qtrue : Qfalse;
}

static VALUE _r2tao_invoke_request(CORBA::Request_ptr _req,
                                   VALUE arg_list,
                                   VALUE ret_rtc,
                                   VALUE exc_list,
                                   bool& _raise)
{
  if (TAO_debug_level > 5)
    ACE_DEBUG ((LM_INFO, "R2TAO (%P|%t) - invoke_request(%C): entry\n", _req->operation ()));

  if (!NIL_P (arg_list))
    _r2tao_set_request_arguments(_req, arg_list);
  if (!NIL_P (exc_list))
    _r2tao_set_request_exceptions(_req, exc_list);

  if (TAO_debug_level > 9)
    ACE_DEBUG ((LM_INFO, "R2TAO (%P|%t) - invoke_request(%C): set return type\n", _req->operation ()));

  CORBA::TypeCode_ptr _ret_tc = CORBA::TypeCode::_nil ();
  if (!NIL_P(ret_rtc))
  {
    _ret_tc = r2corba_TypeCode_r2t (ret_rtc);
    // assign type info to Any
    r2tao_Ruby2Any(_req->return_value(), _ret_tc, Qnil);
  }

  CORBA::ULong ret_num = 0;

  // invoke twoway if resulttype specified (could be void!)
  if (!CORBA::is_nil(_ret_tc) && _ret_tc->kind () != CORBA::tk_null)
  {
    if (_ret_tc->kind () != CORBA::tk_void)
      ++ret_num;

    CORBA::ULong arg_num = _req->arguments ()->count ();
    for (CORBA::ULong a=0; a<arg_num ;++a)
    {
      CORBA::NamedValue_ptr _arg = _req->arguments ()->item (a);
      if (ACE_BIT_DISABLED (_arg->flags (), CORBA::ARG_IN))
        ++ret_num;
    }

    if (TAO_debug_level > 6)
      ACE_DEBUG ((LM_INFO, "R2TAO (%P|%t) - invoke_request(%C): invoke remote twoway\n", _req->operation ()));

    // invoke request
    try
    {
      {
        R2TAO_Request_BlockedInvoke blocked_exec (_req);

        blocked_exec.call ();
      }
    }
    catch (CORBA::UnknownUserException& user_ex)
    {
      if (TAO_debug_level > 6)
        ACE_DEBUG ((LM_INFO, "R2TAO (%P|%t) - invoke_request(%C): user exception from remote twoway\n", _req->operation ()));

      CORBA::Any& _excany = user_ex.exception ();

      CORBA::ULong exc_len = _req->exceptions ()->count ();
      for (CORBA::ULong x=0; x<exc_len ;++x)
      {
        CORBA::TypeCode_var _xtc = _req->exceptions ()->item (x);
        if (ACE_OS::strcmp (_xtc->id (),
                            _excany._tao_get_typecode ()->id ()) == 0)
        {
          VALUE x_rtc = r2corba_TypeCode_t2r (_xtc.in ());
          VALUE rexc = r2tao_Any2Ruby (_excany,
                                       _xtc.in (),
                                       x_rtc, x_rtc);
          _raise = true;
          return rexc;
        }
      }

      // rethrow if we were not able to identify the exception
      // will be caught and handled in outer exception handler
      throw;
    }

    if (TAO_debug_level > 6)
      ACE_DEBUG ((LM_INFO, "R2TAO (%P|%t) - invoke_request(%C): handle remote twoway results\n", _req->operation ()));

    // handle result and OUT arguments
    VALUE result = (ret_num>1 ? rb_ary_new () : Qnil);

    if (_ret_tc->kind () != CORBA::tk_void)
    {
      if (TAO_debug_level > 9)
        ACE_DEBUG ((LM_INFO, "R2TAO (%P|%t) - invoke_request(%C): handle remote twoway return value\n", _req->operation ()));

      CORBA::Any& retval = _req->return_value ();
      // return value
      if (ret_num>1)
        rb_ary_push (result, r2tao_Any2Ruby (retval, _ret_tc, Qnil, Qnil));
      else
        result = r2tao_Any2Ruby (retval, _ret_tc, Qnil, Qnil);

      --ret_num; // return value handled
    }

    // (in)out args
    if (ret_num > 0)
    {
      if (TAO_debug_level > 9)
        ACE_DEBUG ((LM_INFO, "R2TAO (%P|%t) - invoke_request(%C): handle remote twoway (in)out args\n", _req->operation ()));

      for (CORBA::ULong a=0; a<arg_num ;++a)
      {
        VALUE rargspec = rb_ary_entry (arg_list, a);
        VALUE rargtc = rb_ary_entry (rargspec, 2);
        CORBA::TypeCode_ptr atc = r2corba_TypeCode_r2t (rargtc);

        CORBA::NamedValue_ptr _arg = _req->arguments ()->item (a);
        if (ACE_BIT_DISABLED (_arg->flags (), CORBA::ARG_IN))
        {
          if (!NIL_P (result))
            rb_ary_push (result, r2tao_Any2Ruby (*_arg->value (), atc, rargtc, rargtc));
          else
            result = r2tao_Any2Ruby (*_arg->value (), atc, rargtc, rargtc);
        }
      }
    }

    return result;
  }
  else  // invoke oneway
  {
    if (TAO_debug_level > 6)
      ACE_DEBUG ((LM_INFO, "R2TAO (%P|%t) - invoke_request(%C): invoke remote oneway\n", _req->operation ()));

    // oneway
    _req->send_oneway ();

    return Qtrue;
  }
}

//-------------------------------------------------------------------
//  CORBA::Stub methods
//
//===================================================================

VALUE rCORBA_Stub_invoke(int _argc, VALUE *_argv, VALUE self)
{
  if (TAO_debug_level > 9)
    ACE_DEBUG ((LM_INFO, "R2TAO (%P|%t) - Stub::_invoke: entry\n"));

  // since rb_exc_raise () does not return and does *not* honour
  // C++ exception rules we invoke from an inner function and
  // only raise the user exception when returned so all stack
  // unwinding has been correctly handled.
  VALUE ret=Qnil;
  bool _raise = false;
  CORBA::Object_ptr obj;
  VALUE opname = Qnil;
  VALUE arg_list = Qnil;
  VALUE result_type = Qnil;
  VALUE exc_list = Qnil;
  VALUE v1=Qnil;

  // extract and check arguments
  rb_scan_args(_argc, _argv, "20", &opname, &v1);
  Check_Type (v1, T_HASH);

  arg_list = rb_hash_aref (v1, ID_arg_list);
  result_type = rb_hash_aref (v1, ID_result_type);
  exc_list = rb_hash_aref (v1, ID_exc_list);

  Check_Type(opname, T_STRING);
  if (!NIL_P (arg_list))
    Check_Type (arg_list, T_ARRAY);
  if (!NIL_P (result_type))
    r2tao_check_type(result_type, r2corba_cTypeCode);
  if (!NIL_P (exc_list))
    Check_Type (exc_list, T_ARRAY);

  obj = r2corba_Object_r2t (self);

  R2TAO_TRY
  {
    CORBA::Request_var _req = obj->_request (RSTRING_PTR (opname));

    ret = _r2tao_invoke_request(_req.in (), arg_list, result_type, exc_list, _raise);
  }
  R2TAO_CATCH;
  if (_raise) rb_exc_raise (ret);
  return ret;
}

//-------------------------------------------------------------------
//  CORBA::Request methods
//
//===================================================================

VALUE rCORBA_Request_invoke(int _argc, VALUE *_argv, VALUE self)
{
  CORBA::Request_ptr _req =  r2tao_Request_r2t(self);

  if (TAO_debug_level > 5)
    ACE_DEBUG ((LM_INFO, "R2TAO (%P|%t) - Request::_invoke(%@): entry\n", _req->operation ()));

  // since rb_exc_raise () does not return and does *not* honour
  // C++ exception rules we invoke from an inner function and
  // only raise the user exception when returned so all stack
  // unwinding has been correctly handled.
  VALUE ret=Qnil;
  bool _raise = false;
  VALUE arg_list = Qnil;
  VALUE result_type = Qnil;
  VALUE exc_list = Qnil;
  VALUE v1=Qnil;

  // extract and check arguments
  rb_scan_args(_argc, _argv, "10", &v1);
  if (!NIL_P (v1))
  {
    Check_Type (v1, T_HASH);
    arg_list = rb_hash_aref (v1, ID_arg_list);
    result_type = rb_hash_aref (v1, ID_result_type);
    exc_list = rb_hash_aref (v1, ID_exc_list);
  }

  if (!NIL_P (arg_list))
    Check_Type (arg_list, T_ARRAY);
  if (!NIL_P (result_type))
    r2tao_check_type(result_type, r2corba_cTypeCode);
  if (!NIL_P (exc_list))
    Check_Type (exc_list, T_ARRAY);

  R2TAO_TRY
  {
    ret = _r2tao_invoke_request(_req, arg_list, result_type, exc_list, _raise);
  }
  R2TAO_CATCH;

  if (_raise) rb_exc_raise (ret);
  return ret;
}

VALUE rCORBA_Request_send_oneway(VALUE self, VALUE arg_list)
{
  CORBA::Request_ptr _req =  r2tao_Request_r2t(self);

  if (TAO_debug_level > 5)
    ACE_DEBUG ((LM_INFO, "R2TAO (%P|%t) - Request::_send_oneway(%@): entry\n", _req->operation ()));

  if (!NIL_P (arg_list))
  {
    Check_Type (arg_list, T_ARRAY);
  }


  R2TAO_TRY
  {
    if (!NIL_P (arg_list))
      _r2tao_set_request_arguments(_req, arg_list);

    {
      R2TAO_Request_BlockedSendOneway blocked_exec (_req);

      blocked_exec.call ();
    }
  }
  R2TAO_CATCH;

  return Qtrue;
}

VALUE rCORBA_Request_send_deferred(int _argc, VALUE *_argv, VALUE self)
{
  CORBA::Request_ptr _req =  r2tao_Request_r2t(self);

  if (TAO_debug_level > 5)
    ACE_DEBUG ((LM_INFO, "R2TAO (%P|%t) - Request::_send_deferred(%@): entry\n", _req->operation ()));

  VALUE arg_list = Qnil;
  VALUE result_type = Qnil;
  VALUE exc_list = Qnil;
  VALUE v1=Qnil;

  // extract and check arguments
  rb_scan_args(_argc, _argv, "10", &v1);
  if (!NIL_P (v1))
  {
    Check_Type (v1, T_HASH);
    arg_list = rb_hash_aref (v1, ID_arg_list);
    result_type = rb_hash_aref (v1, ID_result_type);
    exc_list = rb_hash_aref (v1, ID_exc_list);
  }

  if (!NIL_P (arg_list))
    Check_Type (arg_list, T_ARRAY);
  if (!NIL_P (result_type))
    r2tao_check_type(result_type, r2corba_cTypeCode);
  if (!NIL_P (exc_list))
    Check_Type (exc_list, T_ARRAY);

  R2TAO_TRY
  {
    if (!NIL_P (arg_list))
      _r2tao_set_request_arguments(_req, arg_list);
    if (!NIL_P (exc_list))
      _r2tao_set_request_exceptions(_req, exc_list);

    if (TAO_debug_level > 9)
      ACE_DEBUG ((LM_INFO, "R2TAO (%P|%t) - Request::_send_deferred(%C): set return type\n", _req->operation ()));

    CORBA::TypeCode_ptr _ret_tc = CORBA::TypeCode::_nil ();
    if (!NIL_P(result_type))
    {
      _ret_tc = r2corba_TypeCode_r2t (result_type);
      // assign type info to Any
      r2tao_Ruby2Any(_req->return_value(), _ret_tc, Qnil);
    }

    {
      R2TAO_Request_BlockedSendDeferred blocked_exec (_req);

      blocked_exec.call ();
    }
  }
  R2TAO_CATCH;

  return Qtrue;
}

VALUE rCORBA_Request_get_response(VALUE self)
{
  CORBA::Request_ptr _req =  r2tao_Request_r2t(self);

  R2TAO_TRY
  {
    {
      R2TAO_Request_BlockedGetResponse blocked_exec (_req);

      blocked_exec.call ();
    }
  }
  R2TAO_CATCH;

  return Qtrue;
}

VALUE rCORBA_Request_poll_response(VALUE self)
{
  CORBA::Request_ptr _req =  r2tao_Request_r2t(self);

  VALUE ret=Qnil;
  R2TAO_TRY
  {
    {
      R2TAO_Request_BlockedPollResponse blocked_exec (_req);

      ret = blocked_exec.call ();
    }
  }
  R2TAO_CATCH;

  return ret;
}

VALUE rCORBA_Request_target(VALUE self)
{
  CORBA::Request_ptr _req =  r2tao_Request_r2t(self);
  R2TAO_TRY
  {
    CORBA::Object_var obj = _req->target ();
    return r2tao_Object_t2r (obj.in ());
  }
  R2TAO_CATCH;
  return Qnil;
}

VALUE rCORBA_Request_operation(VALUE self)
{
  CORBA::Request_ptr _req =  r2tao_Request_r2t(self);
  R2TAO_TRY
  {
    return rb_str_new2 (_req->operation ());
  }
  R2TAO_CATCH;
  return Qnil;
}

VALUE rCORBA_Request_arguments(VALUE self, VALUE arg_list)
{
  CORBA::Request_ptr _req =  r2tao_Request_r2t(self);
  if (arg_list != Qnil)
    Check_Type (arg_list, T_ARRAY);
  CORBA::ULong rarg_len = (CORBA::ULong )RARRAY_LEN (arg_list);
  R2TAO_TRY
  {
    CORBA::ULong arg_len = _req->arguments ()->count ();
    if (arg_len != rarg_len)
    {
      throw CORBA::BAD_PARAM();
    }
    VALUE rargs_new = rb_ary_new ();
    for (CORBA::ULong a=0; a<arg_len ;++a)
    {
      VALUE rargspec = rb_ary_entry (arg_list, a);
      VALUE rargname = rb_ary_entry (rargspec, 0);
      VALUE rargtc = rb_ary_entry (rargspec, 2);
      CORBA::TypeCode_ptr atc = r2corba_TypeCode_r2t (rargtc);

      VALUE rarg_new = rb_ary_new ();
      CORBA::NamedValue_ptr arg = _req->arguments ()->item (a);

      rb_ary_push (rarg_new, rargname);
      if (ACE_BIT_ENABLED (arg->flags (), CORBA::ARG_IN))
        rb_ary_push (rarg_new, ULONG2NUM (r2tao_IN_ARG));
      else if (ACE_BIT_ENABLED (arg->flags (), CORBA::ARG_OUT))
        rb_ary_push (rarg_new, ULONG2NUM (r2tao_OUT_ARG));
      else if (ACE_BIT_ENABLED (arg->flags (), CORBA::ARG_INOUT))
        rb_ary_push (rarg_new, ULONG2NUM (r2tao_INOUT_ARG));
      rb_ary_push (rarg_new, rargtc);
      VALUE arg_val = r2tao_Any2Ruby (*arg->value (), atc, rargtc, rargtc);
      rb_ary_push (rarg_new, arg_val);
      rb_ary_push (rargs_new, rarg_new);
    }
    return rargs_new;
  }
  R2TAO_CATCH;
  return Qnil;
}

VALUE rCORBA_Request_return_value(VALUE self, VALUE result_type)
{
  CORBA::Request_ptr _req =  r2tao_Request_r2t(self);
  CORBA::TypeCode_ptr _ret_tc = r2corba_TypeCode_r2t (result_type);
  R2TAO_TRY
  {
    CORBA::Any& _ret_val = _req->return_value ();
    return r2tao_Any2Ruby (_ret_val, _ret_tc, result_type, result_type);
  }
  R2TAO_CATCH;

  return Qnil;
}
