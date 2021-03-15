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
#if defined (snprintf)
# undef snprintf
#endif
#if defined (vsnprintf)
# undef vsnprintf
#endif
#if defined (access)
# undef access
#endif
#if defined (memcpy)
# undef memcpy
#endif

#undef RUBY_METHOD_FUNC
extern "C" {
  typedef VALUE (*TfnRuby)(ANYARGS);
  typedef VALUE (*TfnRbAlloc)(VALUE);
};
#define RUBY_METHOD_FUNC(func) ((TfnRuby)func)
#define RUBY_ALLOC_FUNC(func) ((TfnRbAlloc)func)

#include "r2tao_export.h"

#if defined (HAVE_NATIVETHREAD)
# define R2TAO_THREAD_SAFE
# include <ruby/thread.h>
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

  bool has_caught_exception () const { return this->ex_caught_; }

  ID id () const { return this->fn_id_; }

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
  ID fn_id_;
  bool const throw_on_ex_;
  bool ex_caught_;
};

#endif
