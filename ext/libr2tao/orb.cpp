/*--------------------------------------------------------------------
# orb.cpp - R2TAO CORBA ORB support
#
# Author: Martin Corino
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the R2CORBA LICENSE which is
# included with this program.
#
# Copyright (c) Remedy IT Expertise BV
#------------------------------------------------------------------*/

#include "orb.h"
#include "exception.h"
#include "object.h"
#include "typecode.h"
#include "values.h"
#include "tao/corba.h"
#include "tao/ORB_Core.h"
#include "ace/Reactor.h"
#include "ace/Signal.h"
#include "ace/Sig_Handler.h"
#include <memory>

#define RUBY_INVOKE_FUNC RUBY_ALLOC_FUNC

R2TAO_EXPORT VALUE r2corba_cORB = 0;
R2TAO_EXPORT VALUE r2tao_cORB = 0;
VALUE r2tao_nsPolicy = 0;

extern VALUE r2tao_cValueFactoryBase;

/* ruby */
static VALUE r2tao_ORB_hash(VALUE self);
static VALUE r2tao_ORB_eql(VALUE self, VALUE that);

/* orb.h */
static VALUE rCORBA_ORB_init(int _argc, VALUE *_argv0, VALUE klass);
static VALUE rCORBA_ORB_object_to_string(VALUE self, VALUE obj);
static VALUE rCORBA_ORB_string_to_object(VALUE self, VALUE str);
static VALUE rCORBA_ORB_get_service_information(VALUE self, VALUE service_type);
static VALUE rCORBA_ORB_get_current(VALUE self);
static VALUE rCORBA_ORB_list_initial_services(VALUE self);
static VALUE rCORBA_ORB_resolve_initial_references(VALUE self, VALUE identifier);
static VALUE rCORBA_ORB_register_initial_reference(VALUE self, VALUE identifier, VALUE obj);

static VALUE rCORBA_ORB_work_pending(int _argc, VALUE *_argv, VALUE self);
static VALUE rCORBA_ORB_perform_work(int _argc, VALUE *_argv, VALUE self);
static VALUE rCORBA_ORB_run(int _argc, VALUE *_argv, VALUE self);
static VALUE rCORBA_ORB_shutdown(int _argc, VALUE *_argv, VALUE self);
static VALUE rCORBA_ORB_destroy(VALUE self);

static VALUE rCORBA_ORB_register_value_factory(VALUE self, VALUE id, VALUE factory);
static VALUE rCORBA_ORB_unregister_value_factory(VALUE self, VALUE id);
static VALUE rCORBA_ORB_lookup_value_factory(VALUE self, VALUE id);

class R2CSigGuard : public ACE_Event_Handler
{
public:
  R2CSigGuard(CORBA::ORB_ptr orb, bool signal_reactor = true);
  virtual ~R2CSigGuard();

  virtual int handle_signal (int signum,
                             siginfo_t * = nullptr,
                             ucontext_t * = nullptr);

  bool has_caught_signal () { return this->m_signal_caught; }

private:
  class Signal : public ACE_Event_Handler
  {
  public:
    Signal(int signum) : m_signum (signum) {}
    ~Signal() override = default;

    int handle_exception (ACE_HANDLE fd = ACE_INVALID_HANDLE) override;

  private:
    int inner_handler ();

    static void* thread_safe_invoke (void * arg);

    int m_signum;
  };

  static VALUE c_signums;
  static int c_nsig;
  static ACE_Auto_Ptr<ACE_SIGACTION> c_sa;

  static void init_ ();

  CORBA::ORB_var  m_orb;
  bool m_signal_reactor;
  ACE_Sig_Handler m_sig_handler;
  ACE_Auto_Ptr<Signal> m_signal;
  bool m_signal_caught;
#if defined (WIN32)
  R2CSigGuard*    m_prev_guard;

public:
  static R2CSigGuard* c_sig_guard;
#endif
};

#if defined (WIN32)
R2CSigGuard* R2CSigGuard::c_sig_guard = nullptr;

BOOL WINAPI CtrlHandlerRoutine (DWORD /*dwCtrlType*/)
{
    if (R2CSigGuard::c_sig_guard)
    {
      R2CSigGuard::c_sig_guard->handle_signal (SIGINT);
    }
    return TRUE;
}
#endif

static void
_orb_free(void *ptr)
{
  CORBA::release ((CORBA::ORB_ptr)ptr);
}

R2TAO_EXPORT VALUE
r2tao_ORB_t2r(CORBA::ORB_ptr obj)
{
  CORBA::ORB_ptr _orb = CORBA::ORB::_duplicate(obj);
  VALUE ret = Data_Wrap_Struct(r2tao_cORB, 0, _orb_free, _orb);

  return ret;
}

R2TAO_EXPORT CORBA::ORB_ptr
r2tao_ORB_r2t(VALUE obj)
{
  CORBA::ORB_ptr ret;

  r2tao_check_type(obj, r2tao_cORB);
  Data_Get_Struct(obj, CORBA::ORB, ret);
  return ret;
}

R2TAO_EXPORT VALUE
r2corba_ORB_t2r(CORBA::ORB_ptr obj)
{
  static ID wrap_native_ID = rb_intern ("_wrap_native");

  return rb_funcall (r2corba_cORB, wrap_native_ID, 1 , r2tao_ORB_t2r (obj));
}

R2TAO_EXPORT CORBA::ORB_ptr
r2corba_ORB_r2t(VALUE obj)
{
  static ID orb_ID = rb_intern ("orb_");

  r2tao_check_type(obj, r2corba_cORB);
  return r2tao_ORB_r2t (rb_funcall (obj, orb_ID, 0));
}

void
r2tao_Init_ORB()
{
  VALUE klass;

  if (r2tao_cORB) return;
  r2tao_Init_Object();

  // CORBA::ORB
  r2corba_cORB = rb_eval_string ("::R2CORBA::CORBA::ORB");
  // CORBA::Native::ORB
  klass = r2tao_cORB =
    rb_define_class_under (r2tao_nsCORBA_Native, "ORB", rb_cObject);

  rb_define_method(klass, "==", RUBY_METHOD_FUNC(r2tao_ORB_eql), 1);
  rb_define_method(klass, "hash", RUBY_METHOD_FUNC(r2tao_ORB_hash), 0);
  rb_define_method(klass, "eql?", RUBY_METHOD_FUNC(r2tao_ORB_eql), 1);

  rb_define_singleton_method(klass, "init", RUBY_METHOD_FUNC(rCORBA_ORB_init), -1);

#define DEF_METHOD(NAME, NUM)\
  rb_define_method(klass, #NAME, RUBY_METHOD_FUNC( rCORBA_ORB_ ## NAME ), NUM);

  DEF_METHOD(object_to_string, 1);
  DEF_METHOD(string_to_object, 1);
  DEF_METHOD(get_service_information, 1);
  DEF_METHOD(get_current, 0);
  DEF_METHOD(list_initial_services, 0);
  DEF_METHOD(resolve_initial_references, 1);
  DEF_METHOD(register_initial_reference, 2);
  DEF_METHOD(work_pending, -1);
  DEF_METHOD(perform_work, -1);
  DEF_METHOD(shutdown, -1);
  DEF_METHOD(run, -1);
  DEF_METHOD(destroy, 0);
  DEF_METHOD(register_value_factory, 2);
  DEF_METHOD(unregister_value_factory, 1);
  DEF_METHOD(lookup_value_factory, 1);
#undef DEF_METHOD

#if defined (WIN32)
  if (!::SetConsoleCtrlHandler(CtrlHandlerRoutine, TRUE))
  {
    ACE_DEBUG ((LM_ERROR, ACE_TEXT ("Failed to set Console Ctrl handler!\n")));
  }
#endif
}

//-------------------------------------------------------------------
//  CORBA ORB methods
//
//===================================================================

static
VALUE r2tao_ORB_hash(VALUE self)
{
  return ULONG2NUM((unsigned long)self);
}

static
VALUE r2tao_ORB_eql(VALUE self, VALUE _other)
{
  CORBA::ORB_ptr obj = r2tao_ORB_r2t (self);
  r2tao_check_type (_other, r2tao_cORB);
  CORBA::ORB_ptr other = r2tao_ORB_r2t (_other);

  if (obj == other)
    return Qtrue;
  else
    return Qfalse;
}

static
VALUE rCORBA_ORB_init(int _argc, VALUE *_argv, VALUE /*klass*/) {
  VALUE v0,v1, args0, id0;
  char *id;
  int argc;
  char **argv;
  int i;
  CORBA::ORB_var orb;
  std::unique_ptr<char*[]> argv_safe;

  rb_scan_args(_argc, _argv, "02", &v0, &v1);

  args0 = Qnil;
  id0 = Qnil;
  if (NIL_P(v0))  /* ORB.init() */
  {
    ;
  }
  else  /* ORB.init(args [, orb_identifier]) */
  {
    Check_Type(v0, T_ARRAY);
    if (!NIL_P(v1))
    {
      Check_Type(v1, T_STRING);
    }

    args0 = v0;
    id0 = v1;
  }

  if (NIL_P(id0))
  {
    id = 0;
  }
  else
  {
    id = StringValuePtr (id0);
  }

  if (NIL_P(args0))
  {
    argc = 1;
    argv = new char*[argc];
    argv_safe.reset (argv);   /* make sure memory gets clean up */
    argv[0] = RSTRING_PTR (rb_argv0); /* rb_argv0 is program name */
  }
  else
  {
    argc = RARRAY_LEN (args0) + 1;
    argv = new char*[argc];
    argv_safe.reset (argv);   /* make sure memory gets clean up */
    argv[0] = (RSTRING_PTR (rb_argv0)); /* rb_argv0 is program name */
    for (i=1; i<argc; i++)
    {
      VALUE av = RARRAY_PTR (args0)[i-1];
      av = rb_check_convert_type(av, T_STRING, "String", "to_s");
      argv[i] = StringValueCStr(av);
    }
  }

  R2TAO_TRY
  {
    orb = CORBA::ORB_init(argc, argv, id);
  }
  R2TAO_CATCH;

  return r2tao_ORB_t2r(orb.in ());
}

static
VALUE rCORBA_ORB_object_to_string(VALUE self, VALUE _obj)
{
  char *str = nullptr;

  CORBA::ORB_ptr orb = r2tao_ORB_r2t (self);
  CORBA::Object_ptr obj = r2tao_Object_r2t (_obj);

  if (obj->_is_local ())
  {
    rb_raise (r2tao_cMARSHAL, "local object");
  }

  R2TAO_TRY
  {
    str = orb->object_to_string (obj);
  }
  R2TAO_CATCH;

  return rb_str_new2(str);
}

static
VALUE rCORBA_ORB_string_to_object(VALUE self, VALUE _str)
{
  CORBA::Object_var obj;
  char *str = nullptr;

  CORBA::ORB_ptr orb = r2tao_ORB_r2t (self);
  Check_Type(_str, T_STRING);
  str = RSTRING_PTR (_str);

  R2TAO_TRY
  {
    obj = orb->string_to_object (str);
  }
  R2TAO_CATCH;

  return r2tao_Object_t2r(obj.in ());
}

static
VALUE rCORBA_ORB_get_service_information(VALUE /*self*/, VALUE /*service_type*/)
{
  X_CORBA(NO_IMPLEMENT);
  return Qnil;
}

static
VALUE rCORBA_ORB_get_current(VALUE /*self*/)
{
  X_CORBA(NO_IMPLEMENT);
  return Qnil;
}

static
VALUE rCORBA_ORB_list_initial_services(VALUE self)
{
  CORBA::ORB::ObjectIdList_var list;
  CORBA::ORB_ptr orb = r2tao_ORB_r2t (self);

  R2TAO_TRY
  {
    list = orb->orb_core ()->list_initial_references ();
  }
  R2TAO_CATCH;

  VALUE ary = rb_ary_new2(list->length ());
  for (CORBA::ULong i = 0; i < list->length (); i++)
  {
    char const * id = list[i];
    rb_ary_push (ary, rb_str_new2 (id));
  }

  return ary;
}

static
VALUE rCORBA_ORB_resolve_initial_references(VALUE self, VALUE _id)
{
  CORBA::Object_var obj;
  CORBA::ORB_ptr orb = r2tao_ORB_r2t (self);

  Check_Type(_id, T_STRING);
  char *id = RSTRING_PTR (_id);

  R2TAO_TRY
  {
    try
    {
      obj = orb->resolve_initial_references(id);
    }
    catch (const CORBA::ORB::InvalidName& ex)
    {
      rb_exc_raise (rb_class_new_instance (0, 0, rb_const_get (r2corba_cORB, rb_intern ("InvalidName"))));
    }
  }
  R2TAO_CATCH;

  return r2tao_Object_t2r (obj.in ());
}

static
VALUE rCORBA_ORB_register_initial_reference(VALUE self, VALUE _id, VALUE _obj)
{
  CORBA::ORB_ptr orb = r2tao_ORB_r2t (self);

  Check_Type(_id, T_STRING);
  char *id = RSTRING_PTR (_id);
  CORBA::Object_var obj = r2tao_Object_r2t(_obj);

  R2TAO_TRY
  {
    try
    {
      orb->register_initial_reference(id, obj.in ());
    }
    catch (const CORBA::ORB::InvalidName& ex)
    {
      rb_exc_raise (rb_class_new_instance (0, 0, rb_const_get (r2corba_cORB, rb_intern ("InvalidName"))));
    }
  }
  R2TAO_CATCH;

  return Qnil;
}

class R2TAO_ORB_BlockedRegionCaller
{
public:
  R2TAO_ORB_BlockedRegionCaller (CORBA::ORB_ptr orb)
    : orb_ (orb) {}
  R2TAO_ORB_BlockedRegionCaller (CORBA::ORB_ptr orb, ACE_Time_Value& to)
    : orb_ (orb),
      timeout_ (std::addressof(to)) {}
  virtual ~R2TAO_ORB_BlockedRegionCaller () noexcept(false);

  VALUE call (bool with_unblock=true);

  static VALUE blocking_func_exec (void *arg);
  static void unblock_func_exec (void *arg);

protected:
  VALUE  execute ();

  void  shutdown ();

  virtual VALUE do_exec () = 0;

  CORBA::ORB_ptr orb_;
  ACE_Time_Value* timeout_ {};
  bool exception_ {};
  CORBA::Exception* corba_ex_ {};
};

R2TAO_ORB_BlockedRegionCaller::~R2TAO_ORB_BlockedRegionCaller() noexcept(false)
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

VALUE R2TAO_ORB_BlockedRegionCaller::call (bool with_unblock)
{
  if (with_unblock)
    return r2tao_blocking_call_ex (R2TAO_ORB_BlockedRegionCaller::blocking_func_exec, this,
                                   R2TAO_ORB_BlockedRegionCaller::unblock_func_exec, this);
  else
    return r2tao_blocking_call (R2TAO_ORB_BlockedRegionCaller::blocking_func_exec, this);
}

VALUE R2TAO_ORB_BlockedRegionCaller::blocking_func_exec (void *arg)
{
  R2TAO_ORB_BlockedRegionCaller* call_obj =
      reinterpret_cast<R2TAO_ORB_BlockedRegionCaller*> (arg);

  return call_obj->execute ();
}

void R2TAO_ORB_BlockedRegionCaller::unblock_func_exec (void *arg)
{
  R2TAO_ORB_BlockedRegionCaller* call_obj =
      reinterpret_cast<R2TAO_ORB_BlockedRegionCaller*> (arg);

  call_obj->shutdown ();
}

VALUE R2TAO_ORB_BlockedRegionCaller::execute ()
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

void R2TAO_ORB_BlockedRegionCaller::shutdown ()
{
  this->orb_->shutdown (false);
}

class R2TAO_ORB_BlockedRun : public R2TAO_ORB_BlockedRegionCaller
{
public:
  R2TAO_ORB_BlockedRun (CORBA::ORB_ptr orb)
    : R2TAO_ORB_BlockedRegionCaller (orb) {}
  R2TAO_ORB_BlockedRun (CORBA::ORB_ptr orb, ACE_Time_Value& to)
    : R2TAO_ORB_BlockedRegionCaller (orb, to) {}
  ~R2TAO_ORB_BlockedRun () override = default;

protected:
  VALUE do_exec () override;
};

VALUE R2TAO_ORB_BlockedRun::do_exec ()
{
  if (this->timeout_ != 0)
    this->orb_->run (*this->timeout_);
  else
    this->orb_->run ();
  return Qnil;
}

class R2TAO_ORB_BlockedWorkPending : public R2TAO_ORB_BlockedRegionCaller
{
public:
  R2TAO_ORB_BlockedWorkPending (R2CSigGuard& sg, CORBA::ORB_ptr orb)
    : R2TAO_ORB_BlockedRegionCaller (orb), sg_(sg) {}
  R2TAO_ORB_BlockedWorkPending (R2CSigGuard& sg, CORBA::ORB_ptr orb, ACE_Time_Value& to)
    : R2TAO_ORB_BlockedRegionCaller (orb, to), sg_(sg) {}
  virtual ~R2TAO_ORB_BlockedWorkPending () noexcept(false);

protected:
  VALUE do_exec () override;

private:
  R2CSigGuard& sg_;
};

R2TAO_ORB_BlockedWorkPending::~R2TAO_ORB_BlockedWorkPending() noexcept(false)
{
  if (this->exception_)
  {
    this->exception_ = false; // reset for base destructor
    try {
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
    catch (const CORBA::INTERNAL& ex) {
      // Fix; TAO throws CORBA::INTERNAL when work_pending
      // returns with an EINTR error
      if (!this->sg_.has_caught_signal ())
      {
        // propagate exception if no signal caught
        throw;
      }
      // else ignore exception
    }
  }
}

VALUE R2TAO_ORB_BlockedWorkPending::do_exec ()
{
  CORBA::Boolean rc = false;
  if (this->timeout_ != 0)
    rc = this->orb_->work_pending (*this->timeout_);
  else
    rc = this->orb_->work_pending ();
  return rc ? Qtrue : Qfalse;
}

class R2TAO_ORB_BlockedPerformWork : public R2TAO_ORB_BlockedRegionCaller
{
public:
  R2TAO_ORB_BlockedPerformWork (CORBA::ORB_ptr orb)
    : R2TAO_ORB_BlockedRegionCaller (orb) {}
  R2TAO_ORB_BlockedPerformWork (CORBA::ORB_ptr orb, ACE_Time_Value& to)
    : R2TAO_ORB_BlockedRegionCaller (orb, to) {}
  ~R2TAO_ORB_BlockedPerformWork () override = default;

protected:
  VALUE do_exec () override;
};

VALUE R2TAO_ORB_BlockedPerformWork::do_exec ()
{
  if (this->timeout_ != 0)
    this->orb_->perform_work (*this->timeout_);
  else
    this->orb_->perform_work ();
  return Qnil;
}

class R2TAO_ORB_BlockedShutdown : public R2TAO_ORB_BlockedRegionCaller
{
public:
  R2TAO_ORB_BlockedShutdown (CORBA::ORB_ptr orb, bool wait = false)
    : R2TAO_ORB_BlockedRegionCaller (orb),
      wait_ (wait) {}
  ~R2TAO_ORB_BlockedShutdown () override = default;

protected:
  virtual VALUE do_exec ();

private:
  bool wait_;
};

VALUE R2TAO_ORB_BlockedShutdown::do_exec ()
{
  this->orb_->shutdown (this->wait_);
  return Qnil;
}

static
VALUE rCORBA_ORB_run(int _argc, VALUE *_argv, VALUE self)
{
  VALUE rtimeout = Qnil;
  ACE_Time_Value timeout;
  double tmleft=0.0;

  rb_scan_args(_argc, _argv, "01", &rtimeout);
  if (!NIL_P (rtimeout))
  {
    if (rb_type (rtimeout) == T_FLOAT)
    {
      timeout.set (RFLOAT_VALUE (rtimeout));
    }
    else
    {
      unsigned long sec = NUM2ULONG (rtimeout);
      timeout.set (static_cast<time_t> (sec));
    }
    // convert to ACE_Time_Value
  }

  CORBA::ORB_ptr orb = r2tao_ORB_r2t (self);

  R2TAO_TRY
  {
    R2CSigGuard sg(orb);

    if (NIL_P (rtimeout))
    {
      R2TAO_ORB_BlockedRun  blocked_exec (orb);

      blocked_exec.call ();
    }
    else
    {
      R2TAO_ORB_BlockedRun  blocked_exec (orb, timeout);

      blocked_exec.call ();
    }
  }
  R2TAO_CATCH;
  if (!NIL_P (rtimeout))
  {
    tmleft = (double)timeout.usec ();
    tmleft /= 1000000;
    tmleft += timeout.sec ();
  }

  return NIL_P (rtimeout) ? Qnil : rb_float_new (tmleft);
}

static
VALUE rCORBA_ORB_work_pending(int _argc, VALUE *_argv, VALUE self)
{
  VALUE rtimeout = Qnil;
  ACE_Time_Value timeout;
  double tmleft=0.0;

  rb_scan_args(_argc, _argv, "01", &rtimeout);
  if (!NIL_P (rtimeout))
  {
    if (rb_type (rtimeout) == T_FLOAT)
    {
      timeout.set (RFLOAT_VALUE (rtimeout));
    }
    else
    {
      unsigned long sec = NUM2ULONG (rtimeout);
      timeout.set (static_cast<time_t> (sec));
    }
    // convert to ACE_Time_Value
  }

  CORBA::ORB_ptr orb = r2tao_ORB_r2t (self);

  VALUE _rc = Qfalse;

  R2TAO_TRY
  {
    R2CSigGuard sg(orb, false);

    if (NIL_P (rtimeout))
    {
      R2TAO_ORB_BlockedWorkPending  blocked_exec (sg, orb);

      _rc = blocked_exec.call ();
    }
    else
    {
      R2TAO_ORB_BlockedWorkPending  blocked_exec (sg, orb, timeout);

      _rc = blocked_exec.call ();
    }
  }
  R2TAO_CATCH;

  if (NIL_P (rtimeout))
  {
    return _rc;
  }
  else
  {
    VALUE rcarr = rb_ary_new2 (2);
    rb_ary_push (rcarr, _rc);
    tmleft = (double)timeout.usec ();
    tmleft /= 1000000;
    tmleft += timeout.sec ();
    rb_ary_push (rcarr, rb_float_new (tmleft));
    return rcarr;
  }
}

static
VALUE rCORBA_ORB_perform_work(int _argc, VALUE *_argv, VALUE self)
{
  CORBA::ORB_ptr orb;
  VALUE rtimeout = Qnil;
  ACE_Time_Value timeout;
  double tmleft=0.0;

  rb_scan_args(_argc, _argv, "01", &rtimeout);
  if (!NIL_P (rtimeout))
  {
    if (rb_type (rtimeout) == T_FLOAT)
    {
      timeout.set (RFLOAT_VALUE (rtimeout));
    }
    else
    {
      unsigned long sec = NUM2ULONG (rtimeout);
      timeout.set (static_cast<time_t> (sec));
    }
    // convert to ACE_Time_Value
  }

  orb = r2tao_ORB_r2t (self);

  R2TAO_TRY
  {
    R2CSigGuard sg(orb);

    if (NIL_P (rtimeout))
    {
      R2TAO_ORB_BlockedPerformWork  blocked_exec (orb);

      blocked_exec.call ();
    }
    else
    {
      R2TAO_ORB_BlockedPerformWork  blocked_exec (orb, timeout);

      blocked_exec.call ();
    }
  }
  R2TAO_CATCH;
  if (!NIL_P (rtimeout))
  {
    tmleft = (double)timeout.usec ();
    tmleft /= 1000000;
    tmleft += timeout.sec ();
  }

  return NIL_P (rtimeout) ? Qnil : rb_float_new (tmleft);
}

static
VALUE rCORBA_ORB_shutdown(int _argc, VALUE *_argv, VALUE self)
{
  CORBA::ORB_ptr orb;
  VALUE rwait;
  bool wait = false;

  rb_scan_args(_argc, _argv, "01", &rwait);
  if (rwait == Qtrue)
    wait = true;

  orb = r2tao_ORB_r2t (self);

  R2TAO_TRY
  {
    R2CSigGuard sg(orb);

    {
      R2TAO_ORB_BlockedShutdown  blocked_exec (orb, wait);

      blocked_exec.call (false);
    }
  }
  R2TAO_CATCH;

  return Qnil;
}

static
VALUE rCORBA_ORB_destroy(VALUE self)
{
  CORBA::ORB_ptr orb = r2tao_ORB_r2t (self);
  R2TAO_TRY
  {
    orb->destroy ();
  }
  R2TAO_CATCH;

  return Qnil;
}

static
VALUE rCORBA_ORB_register_value_factory(VALUE /*self*/, VALUE id, VALUE rfact)
{
  return r2tao_VFB_register_value_factory(Qnil, id, rfact);
}

static
VALUE rCORBA_ORB_unregister_value_factory(VALUE /*self*/, VALUE id)
{
  return r2tao_VFB_unregister_value_factory(Qnil, id);;
}

static
VALUE rCORBA_ORB_lookup_value_factory(VALUE /*self*/, VALUE id)
{
  return r2tao_VFB_lookup_value_factory(Qnil, id);
}

//-------------------------------------------------------------------
//  Signal handling class/methods
//
//===================================================================

VALUE R2CSigGuard::c_signums = Qnil;
int R2CSigGuard::c_nsig = 0;
ACE_Auto_Ptr<ACE_SIGACTION> R2CSigGuard::c_sa;

void R2CSigGuard::init_ ()
{
  if (NIL_P(R2CSigGuard::c_signums))
  {
    R2CSigGuard::c_signums = rb_funcall (r2tao_nsCORBA, rb_intern("signal_numbers"), 0);
    // prevent GC as long as app lives
    rb_gc_register_address (&R2CSigGuard::c_signums);

    // signum count
    R2CSigGuard::c_nsig = RARRAY_LEN (R2CSigGuard::c_signums);
    // backup storage space
    R2CSigGuard::c_sa.reset (new ACE_SIGACTION[R2CSigGuard::c_nsig]);
  }
}

R2CSigGuard::R2CSigGuard(CORBA::ORB_ptr orb, bool signal_reactor)
  : m_orb (CORBA::ORB::_duplicate (orb)),
    m_signal_reactor (signal_reactor),
    m_signal_caught (false)
{
  // make sure initialization is done
  R2CSigGuard::init_ ();

  // initialize sigaction to set all signals to default (recording current handlers)
  ACE_SIGACTION sa_;
  sa_.sa_handler = SIG_DFL;
  ACE_OS::sigemptyset (&sa_.sa_mask);
  sa_.sa_flags = 0;

  // reset and backup all current signal handlers
  for (int i=0; i<R2CSigGuard::c_nsig ;++i)
  {
    int signum = NUM2INT (rb_ary_entry (R2CSigGuard::c_signums, i));
    ACE_SIGACTION* sa = &(R2CSigGuard::c_sa.get ()[i]);
    ACE_OS::sigaction (signum, &sa_, sa);
  }

  // get array with signal numbers to handle (not DEFAULT)
  VALUE signum_arr = rb_funcall (r2tao_nsCORBA, rb_intern("handled_signals"), 0);
  // signum count
  int nsig = RARRAY_LEN (signum_arr);
  // set signal handler for handled signals
  bool fINT = false;
  for (int i=0; i<nsig ;++i)
  {
    int signum = NUM2INT (rb_ary_entry (signum_arr, i));
    fINT = fINT || (signum == SIGINT);
    m_sig_handler.register_handler (signum, this);
  }

#if defined (WIN32)
  m_prev_guard = c_sig_guard;
  c_sig_guard =  fINT ? this : 0;
#endif
}

R2CSigGuard::~R2CSigGuard()
{
  if (this->m_signal.get ()!=0 )
  {
    // delayed signal handling for cases like ORB#perform_work()
    m_signal->handle_exception ();
  }

#if defined (WIN32)
  c_sig_guard = m_prev_guard;
#endif

  // invalidate ORB
  m_orb = CORBA::ORB::_nil ();

  // restore signal handlers
  for (int i=0; i<R2CSigGuard::c_nsig ;++i)
  {
    int signum = NUM2INT (rb_ary_entry (R2CSigGuard::c_signums, i));
    ACE_SIGACTION* sa = &(R2CSigGuard::c_sa.get ()[i]);
    ACE_OS::sigaction (signum, sa, 0);
  }
  // clean up
  ACE_OS::memset (R2CSigGuard::c_sa.get (), 0, R2CSigGuard::c_nsig * sizeof(ACE_SIGACTION));
}

int R2CSigGuard::handle_signal (int signum,
                                siginfo_t *,
                                ucontext_t *)
{
  this->m_signal_caught = true;
  if (this->m_signal_reactor && !CORBA::is_nil (m_orb))
  {
    // do not handle signal here but reroute as notification to ORB reactor
    m_orb->orb_core ()->reactor ()->notify (new Signal (signum));
  }
  else
  {
    m_signal.reset (new Signal (signum));
  }
  return 0;
}

int R2CSigGuard::Signal::handle_exception (ACE_HANDLE)
{
  r2tao_call_thread_safe (R2CSigGuard::Signal::thread_safe_invoke, this);
  return 0;
}

// invocation helper for threadsafe calling of Ruby code
void* R2CSigGuard::Signal::thread_safe_invoke (void * arg)
{
  R2CSigGuard::Signal* sig = reinterpret_cast<R2CSigGuard::Signal*> (arg);

  sig->inner_handler ();
  return 0;
}

int R2CSigGuard::Signal::inner_handler ()
{
  static R2TAO_RBFuncall FN_handle_signal ("handle_signal", false);

  VALUE rargs = rb_ary_new2 (1);
  rb_ary_push (rargs, INT2NUM(m_signum));
  FN_handle_signal.invoke (r2tao_nsCORBA, rargs);
  if (FN_handle_signal.has_caught_exception ())
  {
    rb_eval_string ("STDERR.puts $!.to_s+\"\\n\"+$!.backtrace.join(\"\\n\")");
  }

  return 0;
}

// end of orb.cpp
