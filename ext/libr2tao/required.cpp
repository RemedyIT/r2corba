/*--------------------------------------------------------------------
# required.h - R2TAO CORBA basic support
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
#include "exception.h"
#include "typecode.h"
#include "ace/Env_Value_T.h"
#include "ace/Null_Mutex.h"
#include "ace/Singleton.h"
#include "ace/TSS_T.h"
#include "tao/AnyTypeCode/Any.h"
#include "tao/DynamicInterface/Unknown_User_Exception.h"
#include "tao/debug.h"
#include <memory>

#define RUBY_INVOKE_FUNC RUBY_ALLOC_FUNC

R2TAO_EXPORT VALUE r2tao_nsCORBA = 0;
R2TAO_EXPORT VALUE r2tao_nsCORBA_Native = 0;

extern void r2tao_Init_Exception();
extern void r2tao_Init_Object();
extern void r2tao_Init_ORB();
extern void r2tao_Init_Typecode();
extern void r2tao_init_Values();

class R2TAO_ObjectRegistry
{
  friend class ACE_Singleton<R2TAO_ObjectRegistry, ACE_Null_Mutex>;
private:
  R2TAO_ObjectRegistry()
    : registry_ (Qnil)
  {
    // create an anchoring object
    R2TAO_ObjectRegistry::registry_anchor_ = Data_Wrap_Struct (rb_cObject, 0, R2TAO_ObjectRegistry::registry_free, this);
    // prevent GC while Ruby lives
    rb_gc_register_address (&R2TAO_ObjectRegistry::registry_anchor_);
    // create registry Hash
    this->registry_ = rb_hash_new ();
    // create an instance variable to hold registry (prevents GC since anchor is registered)
    rb_ivar_set (R2TAO_ObjectRegistry::registry_anchor_, rb_intern ("@registry_"), this->registry_);
    R2TAO_ObjectRegistry::has_singleton_ = true;
  }

  static VALUE registry_anchor_;
  static bool has_singleton_;

public:
  ~R2TAO_ObjectRegistry()
  {
    // no need to unregister; as we live as long as Ruby does
    // we had better let Ruby take care of cleaning up otherwise
    // we may end up in a race condition
    // Just mark the registry as destroyed
    R2TAO_ObjectRegistry::has_singleton_ = false;
    this->registry_ = Qnil;
  }

  void register_object (VALUE rbobj)
  {
    if (TAO_debug_level > 9)
      ACE_DEBUG ((LM_INFO, "R2TAO (%P|%t) - R2TAO_ObjectRegistry::register_object(%@) - reg=%@\n", rbobj, this->registry_));

    if (!NIL_P(this->registry_))
    {
      rb_hash_aset (this->registry_, rbobj, rbobj);
    }
    else
    {
      if (TAO_debug_level > 1)
        ACE_DEBUG ((LM_INFO, "R2TAO (%P|%t) - R2TAO_ObjectRegistry::register_object(%@) - "
                             "not registring since registry is nil\n", rbobj));
    }
  }

  void unregister_object (VALUE rbobj)
  {
    if (TAO_debug_level > 9)
      ACE_DEBUG ((LM_INFO, "R2TAO (%P|%t) - R2TAO_ObjectRegistry::unregister_object(%@) - reg=%@\n", rbobj, this->registry_));

    if (!NIL_P(this->registry_))
    {
      rb_hash_delete (this->registry_, rbobj);
    }
  }

  static bool has_singleton ();

private:
  VALUE   registry_;

  void clear_registry ()
  {
    this->registry_ = Qnil;
  }

  static void registry_free(void *ptr)
  {
    // what came first? is registry singleton still there?
    if (R2TAO_ObjectRegistry::has_singleton ())
    {
      // registry anchor is being GC-ed so clean up to prevent illegal access
      R2TAO_ObjectRegistry* objreg = reinterpret_cast<R2TAO_ObjectRegistry*> (ptr);
      objreg->clear_registry ();
    }
  }
};

VALUE R2TAO_ObjectRegistry::registry_anchor_ = Qnil;
bool R2TAO_ObjectRegistry::has_singleton_ = false;

bool R2TAO_ObjectRegistry::has_singleton ()
{
  return R2TAO_ObjectRegistry::has_singleton_;
}

typedef ACE_Singleton<R2TAO_ObjectRegistry, ACE_Null_Mutex> R2TAO_OBJECTREGISTRY;

#if defined(WIN32) && defined(_DEBUG)
extern "C" R2TAO_EXPORT void Init_libr2taod()
#else
extern "C" R2TAO_EXPORT void Init_libr2tao()
#endif
{
  rb_eval_string("puts 'Init_libr2tao start' if $VERBOSE");

  if (r2tao_nsCORBA) return;

  // TAO itself only does this when an ORB is initialized; we want it sooner
  if (TAO_debug_level <= 0)
    TAO_debug_level = ACE_Env_Value<u_int> ("TAO_ORB_DEBUG", 0);

  rb_eval_string("puts 'Init_libr2tao 2' if $VERBOSE");

  VALUE klass = rb_define_module_under (rb_eval_string ("::R2CORBA"), "TAO");
  rb_define_const (klass, "MAJOR_VERSION", INT2NUM (TAO_MAJOR_VERSION));
  rb_define_const (klass, "MINOR_VERSION", INT2NUM (TAO_MINOR_VERSION));
  rb_define_const (klass, "MICRO_VERSION", INT2NUM (TAO_MICRO_VERSION));
  rb_define_const (klass, "VERSION", rb_str_new2 (TAO_VERSION));
  rb_define_const (klass, "RUBY_THREAD_SUPPORT",
#ifdef R2TAO_THREAD_SAFE
                   Qtrue
#else
                   Qfalse
#endif
                   );

  r2tao_nsCORBA = rb_eval_string("::R2CORBA::CORBA");

  r2tao_nsCORBA_Native = rb_define_module_under (r2tao_nsCORBA, "Native");

  rb_eval_string("puts 'Init_libr2tao r2tao_Init_Exception' if $VERBOSE");

  r2tao_Init_Exception();

  rb_eval_string("puts 'Init_libr2tao r2tao_Init_Object' if $VERBOSE");

  r2tao_Init_Object();

  rb_eval_string("puts 'Init_libr2tao r2tao_Init_ORB' if $VERBOSE");

  r2tao_Init_ORB();

  rb_eval_string("puts 'Init_libr2tao r2tao_Init_Typecode' if $VERBOSE");

  r2tao_Init_Typecode();

  rb_eval_string("puts 'Init_libr2tao r2tao_Init_Values' if $VERBOSE");

  r2tao_init_Values();
}

R2TAO_EXPORT void r2tao_check_type(VALUE x, VALUE t)
{
  if (rb_obj_is_kind_of(x, t) != Qtrue)
  {
    VALUE rb_dump = rb_funcall (x, rb_intern ("inspect"), 0);
    rb_raise(r2tao_cBAD_PARAM, "wrong argument type %s (expected %s)\n",
       RSTRING_PTR(rb_dump), rb_class2name(t));
  }
}

R2TAO_EXPORT void r2tao_register_object(VALUE rbobj)
{
  R2TAO_OBJECTREGISTRY::instance ()->register_object (rbobj);
}

R2TAO_EXPORT void r2tao_unregister_object(VALUE rbobj)
{
  if (R2TAO_ObjectRegistry::has_singleton ())
  {
    R2TAO_OBJECTREGISTRY::instance ()->unregister_object (rbobj);
  }
}

#if defined (R2TAO_THREAD_SAFE)
class R2TAO_GVLGuard
{
public:
  R2TAO_GVLGuard (bool lock=true) : lock_(lock) { TSSManager::set_indicator (this->lock_); }
  ~R2TAO_GVLGuard () { TSSManager::set_indicator (!this->lock_); }

  static bool gvl_locked (bool start_locked=false)
  {
    if (start_locked && !TSSManager::has_indicator ())
    {
      TSSManager::set_indicator (start_locked);
    }
    return TSSManager::indicator ();
  }
private:
  bool lock_;

  class TSSManager
  {
  public:
    TSSManager ()
    {
      gvl_indicator_ = new ACE_TSS< ACE_TSS_Type_Adapter<u_int> > ();
    }
    ~TSSManager ()
    {
      delete gvl_indicator_;
      gvl_indicator_ = nullptr;
    }

    static void set_indicator (bool val)
    {
      if (gvl_indicator_)
        (*gvl_indicator_)->operator u_int & () = (val ? 1 : 0);
    }

    static bool has_indicator ()
    {
      return (gvl_indicator_ && (*gvl_indicator_).ts_object ());
    }

    static bool indicator ()
    {
      // if the TSS storage has alredy been destroyed we're in the exit procedure and the
      // GVL is always locked
      return (gvl_indicator_ == 0 || (*gvl_indicator_)->operator u_int () == 1);
    }

  private:
    static ACE_TSS< ACE_TSS_Type_Adapter<u_int> >* gvl_indicator_;
  };

  static TSSManager tss_gvl_flag_;
};

ACE_TSS< ACE_TSS_Type_Adapter<u_int> >* R2TAO_GVLGuard::TSSManager::gvl_indicator_;
R2TAO_GVLGuard::TSSManager R2TAO_GVLGuard::tss_gvl_flag_;

template <typename FTYPE>
struct r2tao_gvl_call_arg
{
  r2tao_gvl_call_arg (FTYPE func, void* data)
   : func_ (func), data_ (data) {}
  FTYPE func_;
  void* data_;
};

void* r2tao_call_with_gvl (void *data)
{
  R2TAO_GVLGuard gvl_guard_;
  r2tao_gvl_call_arg<void*(*)(void*)>& arg = *reinterpret_cast<r2tao_gvl_call_arg<void*(*)(void*)>*> (data);
  return (*arg.func_) (arg.data_);
}

void* r2tao_call_without_gvl (void *data)
{
  R2TAO_GVLGuard gvl_guard_ (false);
  r2tao_gvl_call_arg<void*(*)(void*)>& arg = *reinterpret_cast<r2tao_gvl_call_arg<void*(*)(void*)>*> (data);
  return (*arg.func_) (arg.data_);
}
#endif

R2TAO_EXPORT void* r2tao_call_thread_safe (void *(*func)(void *), void *data)
{
#if defined (R2TAO_THREAD_SAFE)
  if (!R2TAO_GVLGuard::gvl_locked ())
  {
    r2tao_gvl_call_arg<void*(*)(void*)> arg(func, data);
    return rb_thread_call_with_gvl(r2tao_call_with_gvl, &arg);
  }
#endif
  return (*func) (data);
}

R2TAO_EXPORT VALUE r2tao_blocking_call (VALUE (*func)(void*), void*data)
{
#if defined (R2TAO_THREAD_SAFE)
  if (R2TAO_GVLGuard::gvl_locked (true))
  {
    r2tao_gvl_call_arg<VALUE(*)(void*)> arg(func, data);
    void *rc = rb_thread_call_without_gvl(r2tao_call_without_gvl, &arg, RUBY_UBF_IO, 0);
    return reinterpret_cast<VALUE> (rc);
  }
#endif
  return (*func) (data);
}

R2TAO_EXPORT VALUE r2tao_blocking_call_ex (VALUE (*func)(void*), void*data,
                                           void (*unblock_func)(void*), void*unblock_data)
{
#if defined (R2TAO_THREAD_SAFE)
  if (R2TAO_GVLGuard::gvl_locked (true))
  {
    r2tao_gvl_call_arg<VALUE(*)(void*)> arg(func, data);
    void *rc = rb_thread_call_without_gvl(r2tao_call_without_gvl, &arg,
                                          unblock_func, unblock_data);
    return reinterpret_cast<VALUE> (rc);
  }
#else
  ACE_UNUSED_ARG(unblock_func);
  ACE_UNUSED_ARG(unblock_data);
#endif
  return (*func) (data);
}

R2TAO_RBFuncall::R2TAO_RBFuncall (ID fnid, bool throw_on_ex)
 : fn_id_ (fnid),
   throw_on_ex_ (throw_on_ex),
   ex_caught_ (false)
{
}

R2TAO_RBFuncall::R2TAO_RBFuncall (const char* fn, bool throw_on_ex)
: fn_id_ (rb_intern (fn)),
  throw_on_ex_ (throw_on_ex),
  ex_caught_ (false)
{
}

VALUE R2TAO_RBFuncall::invoke (VALUE rcvr, VALUE args)
{
  return this->_invoke (FuncArgArray (rcvr, args));
}

VALUE R2TAO_RBFuncall::invoke (VALUE rcvr, int argc, VALUE *args)
{
  return this->_invoke (FuncArgList (rcvr, argc, args));
}

VALUE R2TAO_RBFuncall::invoke (VALUE rcvr)
{
  return this->_invoke (FuncArgList (rcvr, 0, 0));
}

VALUE R2TAO_RBFuncall::_invoke (const FuncArgs& fa)
{
  static ID interface_repository_id_ID = rb_intern ("_interface_repository_id");;

  this->ex_caught_ = false; // reset

  int invoke_state = 0;
  HelperArgs ha (*this, fa);
  VALUE result = rb_protect (RUBY_INVOKE_FUNC (R2TAO_RBFuncall::invoke_helper),
                             (VALUE)&ha,
                             &invoke_state);
  if (invoke_state)
  {
    if (this->throw_on_ex_)
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
          throw ::CORBA::UnknownUserException (_xval);
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

        std::unique_ptr<CORBA::SystemException> e_ptr(_exc);
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
      this->ex_caught_ = true;
    }
  }
  else
  {
    return result;
  }
  return Qnil;
}

VALUE R2TAO_RBFuncall::FuncArgArray::rb_invoke (ID fnid) const
{
  return rb_apply (this->receiver_, fnid, this->args_);
}

VALUE R2TAO_RBFuncall::FuncArgList::rb_invoke (ID fnid) const
{
  return rb_funcall2 (this->receiver_, fnid, this->argc_, this->args_);
}

VALUE R2TAO_RBFuncall::invoke_inner (const FuncArgs& fnargs)
{
  return fnargs.rb_invoke (this->fn_id_);
}

VALUE R2TAO_RBFuncall::invoke_helper (VALUE arg)
{
  HelperArgs* ha = reinterpret_cast<HelperArgs*> (arg);
  return ha->caller_.invoke_inner (ha->fnargs_);
}
