/*--------------------------------------------------------------------
# longdouble.cpp - R2TAO CORBA LongDouble support
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
#include "longdouble.h"

#include <ace/OS_NS_stdio.h>

static VALUE r2tao_cLongDouble;

static VALUE rb_cBigDecimal;

// CORBA LongDouble methods
static VALUE ld_alloc(VALUE klass);
static void ld_free(void* ptr);

static VALUE r2tao_LongDouble_initialize(int _argc, VALUE *_argv0, VALUE klass);
static VALUE r2tao_LongDouble_to_s(int _argc, VALUE *_argv, VALUE self);
static VALUE r2tao_LongDouble_to_f(VALUE self);
static VALUE r2tao_LongDouble_to_i(VALUE self);
static VALUE r2tao_LongDouble_size(VALUE self);

void r2tao_init_LongDouble()
{
  VALUE k;

  k = r2tao_cLongDouble =
    rb_define_class_under (r2tao_nsCORBA, "LongDouble", rb_cObject);
  rb_define_alloc_func (r2tao_cLongDouble, RUBY_ALLOC_FUNC (ld_alloc));
  rb_define_method(k, "initialize", RUBY_METHOD_FUNC(r2tao_LongDouble_initialize), -1);
  rb_define_method(k, "to_s", RUBY_METHOD_FUNC(r2tao_LongDouble_to_s), -1);
  rb_define_method(k, "to_f", RUBY_METHOD_FUNC(r2tao_LongDouble_to_f), 0);
  rb_define_method(k, "to_i", RUBY_METHOD_FUNC(r2tao_LongDouble_to_i), 0);
  rb_define_singleton_method(k, "size", RUBY_METHOD_FUNC(r2tao_LongDouble_size), 0);

  rb_require ("bigdecimal");
  rb_cBigDecimal = rb_eval_string ("::BigDecimal");
}
//-------------------------------------------------------------------
//  CORBA LongDouble methods
//
//===================================================================

static VALUE ld_alloc(VALUE klass)
{
  VALUE obj;

  ACE_CDR::LongDouble* ld = new ACE_CDR::LongDouble;
  ACE_CDR_LONG_DOUBLE_ASSIGNMENT ((*ld), 0.0);
  obj = Data_Wrap_Struct(klass, 0, ld_free, ld);
  return obj;
}

static void ld_free(void* ptr)
{
  if (ptr)
    delete static_cast<ACE_CDR::LongDouble*> (ptr);
}

VALUE r2tao_cld2rld(const NATIVE_LONGDOUBLE& _d)
{
  VALUE _rd = Data_Wrap_Struct(r2tao_cLongDouble, 0, ld_free, new ACE_CDR::LongDouble);
  SETCLD2RLD (_rd, _d);
  return _rd;
}

VALUE r2tao_LongDouble_initialize(int _argc, VALUE *_argv, VALUE self)
{
  VALUE v0, v1 = Qnil;
  rb_scan_args(_argc, _argv, "11", &v0, &v1);

  if (rb_obj_is_kind_of(v0, rb_cFloat) == Qtrue)
  {
    SETCLD2RLD(self, NUM2DBL(v0));
    return self;
  }
  else if (rb_obj_is_kind_of(v0, rb_cBigDecimal) == Qtrue)
  {
    if (v1 != Qnil)
    {
      v0 = rb_funcall (v0, rb_intern ("round"), 1, v1);
    }
    v0 = rb_funcall (v0, rb_intern ("to_s"), 0);
  }

  if (rb_obj_is_kind_of(v0, rb_cString) == Qtrue)
  {
    char* endp = nullptr;
#if defined (NONNATIVE_LONGDOUBLE) && defined (ACE_CDR_IMPLEMENT_WITH_NATIVE_DOUBLE)
    NATIVE_LONGDOUBLE _ld = ::strtod (RSTRING_PTR (v0), &endp);
#else
    NATIVE_LONGDOUBLE _ld = ::strtold (RSTRING_PTR (v0), &endp);
#endif

    if (errno == ERANGE)
      rb_raise (rb_eRangeError, "floating point '%s' out-of-range", RSTRING_PTR (v0));

    if (RSTRING_PTR (v0) == endp)
      rb_raise (rb_eArgError, "floating point string '%s' invalid", RSTRING_PTR (v0));

    SETCLD2RLD(self, _ld);
    return self;
  }

  rb_raise (rb_eTypeError, "wrong argument type %s (expected Float, String or BigDecimal)",
            rb_class2name(CLASS_OF(v0)));

  return Qnil;
}

// silence pesky warnings from MingW cocerning long double format specifier
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wformat"
#pragma GCC diagnostic ignored "-Wformat-extra-args"

VALUE r2tao_LongDouble_to_s(int _argc, VALUE *_argv, VALUE self)
{
  VALUE prec = Qnil;
  rb_scan_args(_argc, _argv, "01", &prec);

  int lprec = (prec == Qnil ? 0 : NUM2LONG (prec));

  R2TAO_TRY
  {
    unsigned long len = (lprec < 512) ? 1024 : 2*lprec;
    CORBA::String_var buf = CORBA::string_alloc (len);
#if defined (NONNATIVE_LONGDOUBLE) && defined (ACE_CDR_IMPLEMENT_WITH_NATIVE_DOUBLE)
    if (prec == Qnil)
      ACE_OS::snprintf ((char*)buf, len-1, "%f", RLD2CLD(self));
    else
      ACE_OS::snprintf ((char*)buf, len-1, "%.*f", lprec, RLD2CLD(self));
#else
    if (prec == Qnil)
      ACE_OS::snprintf ((char*)buf, len-1, "%Lf", RLD2CLD(self));
    else
      ACE_OS::snprintf ((char*)buf, len-1, "%.*Lf", lprec, RLD2CLD(self));
#endif
    return rb_str_new2 ((char*)buf);
  }
  R2TAO_CATCH;

  return Qnil;
}

#pragma GCC diagnostic pop

VALUE r2tao_LongDouble_to_f(VALUE self)
{
  return rb_float_new (RLD2CLD(self));
}

VALUE r2tao_LongDouble_to_i(VALUE self)
{
  unsigned long long l =
    static_cast<unsigned long long> (RLD2CLD(self));
  return ULL2NUM (l);
}

VALUE r2tao_LongDouble_size(VALUE /*self*/)
{
  return INT2FIX (sizeof (NATIVE_LONGDOUBLE) * CHAR_BIT);
}
