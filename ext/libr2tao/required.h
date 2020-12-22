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
#ifndef __R2TAO_REQUIRED_H
#define __R2TAO_REQUIRED_H

#if defined (WIN32) || defined (_MSC_VER) || defined (__MINGW32__)
  // prevent inclusion of Ruby Win32 defs which clash with ACE
  // are only important for Ruby internals
  #define RUBY_WIN32_H
  // if we're compiling with MSVC 7.1 this is most probably for
  // the standard Ruby dist which is built with MSVC 6
  // fudge the version macro so Ruby doesn't complain
  #if (_MSC_VER >= 1310) && (_MSC_VER < 1400)
  #define OLD_MSC_VER 1310
  #undef _MSC_VER
  #define _MSC_VER 1200
  #endif
#endif

#define RUBY_EXTCONF_H "r2tao_ext.h"
#include <ruby.h>
// remove conflicting macro(s) defined by Ruby
#undef TYPE
#if defined (uid_t)
#undef uid_t
#endif
#if defined (gid_t)
#undef gid_t
#endif
#if (RUBY_VER_MAJOR>1 || RUBY_VER_MINOR>8)
# undef snprintf
# undef vsnprintf
#endif

#undef RUBY_METHOD_FUNC
extern "C" {
  typedef VALUE (*TfnRuby)(ANYARGS);
  typedef VALUE (*TfnRbAlloc)(VALUE);
};
#define RUBY_METHOD_FUNC(func) ((TfnRuby)func)
#define RUBY_ALLOC_FUNC(func) ((TfnRbAlloc)func)

// includes for Ruby <= 1.8.4 miss this macro
#if !defined (NUM2ULL)
# define NUM2ULL(x) rb_num2ull (x)
#endif

// handle macros missing from older Ruby 1.8.6/7 releases
#if !defined (RFLOAT_VALUE)
#   define RFLOAT_VALUE(v)  NUM2DBL(v)
#endif
#if !defined (RSTRING_PTR)
# define RSTRING_PTR(s) (RSTRING(s)->ptr)
#endif
#if !defined (RSTRING_LEN)
# define RSTRING_LEN(s) (RSTRING(s)->len)
#endif
#if !defined (RSTRING_END)
# define RSTRING_END(s) (RSTRING_PTR(s)+RSTRING_LEN(s))
#endif
#if !defined (RARRAY_PTR)
# define RARRAY_PTR(s) (RARRAY(s)->ptr)
#endif
#if !defined (RARRAY_LEN)
# define RARRAY_LEN(s) (RARRAY(s)->len)
#endif

#include "r2tao_export.h"
#include <tao/Version.h>

#if ((RUBY_VER_MAJOR>1) || (RUBY_VER_MINOR>8)) && defined (HAVE_NATIVETHREAD)
# define R2TAO_THREAD_SAFE

# if RUBY_VER_MAJOR < 2
// acquires GVL before calling func
extern "C" void *
rb_thread_call_with_gvl(void *(*func)(void *), void *data1);

#   define rb_thread_call_without_gvl rb_thread_blocking_region
# else
#   include <ruby/thread.h>
# endif
#endif

extern R2TAO_EXPORT VALUE r2tao_nsCORBA;

extern R2TAO_EXPORT VALUE r2tao_nsCORBA_Native;

extern R2TAO_EXPORT void r2tao_check_type(VALUE x, VALUE t);

extern R2TAO_EXPORT void r2tao_register_object(VALUE rbobj);

extern R2TAO_EXPORT void r2tao_unregister_object(VALUE rbobj);

extern R2TAO_EXPORT void* r2tao_call_thread_safe (void *(*func)(void *), void *data);
extern R2TAO_EXPORT VALUE r2tao_blocking_call (VALUE (*func)(void*), void*data);
extern R2TAO_EXPORT VALUE r2tao_blocking_call_ex (VALUE (*func)(void*), void*data,
                                                  void (*unblock_func)(void*), void*unblock_data);

class R2TAO_EXPORT R2TAO_RBFuncall
{
public:
  R2TAO_RBFuncall (ID fnid, bool throw_on_ex=true);
  R2TAO_RBFuncall (const char* fn, bool throw_on_ex=true);
  ~R2TAO_RBFuncall ();

  VALUE invoke (VALUE rcvr, VALUE args);
  VALUE invoke (VALUE rcvr, int argc, VALUE *args);
  VALUE invoke (VALUE rcvr);

  bool has_caught_exception () { return this->ex_caught_; }

  ID id () { return this->fn_id_; }

protected:
  struct FuncArgs
  {
    virtual ~FuncArgs () {}
    virtual VALUE rb_invoke (ID fnid) const = 0;
  };

  VALUE _invoke (const FuncArgs& fa);

  struct FuncArgArray : public FuncArgs
  {
    FuncArgArray (VALUE rcvr, VALUE args)
     : receiver_ (rcvr), args_ (args) {}
    virtual ~FuncArgArray () {}

    virtual VALUE rb_invoke (ID fnid) const;

    VALUE receiver_;
    VALUE args_;
  };

  struct FuncArgList : public FuncArgs
  {
    FuncArgList (VALUE rcvr, int argc, VALUE* args)
     : receiver_ (rcvr), argc_ (argc), args_ (args) {}
    virtual ~FuncArgList () {}

    virtual VALUE rb_invoke (ID fnid) const;

    VALUE receiver_;
    int argc_;
    VALUE* args_;
  };

  VALUE invoke_inner (const FuncArgs& fnargs);

  struct HelperArgs
  {
    HelperArgs (R2TAO_RBFuncall& c, const FuncArgs& fa)
     : caller_ (c), fnargs_ (fa) {}

    R2TAO_RBFuncall& caller_;
    const FuncArgs& fnargs_;
  };

  static VALUE invoke_helper (VALUE arg);

private:
  ID      fn_id_;
  bool    throw_on_ex_;
  bool    ex_caught_;
};

#if defined (ACE_HAS_CPP11)
# define R2CORBA_NO_EXCEPT_FALSE noexcept(false)
#else
# define R2CORBA_NO_EXCEPT_FALSE
#endif /* ACE_HAS_CPP11 */


#endif
