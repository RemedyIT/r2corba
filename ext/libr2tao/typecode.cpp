/*--------------------------------------------------------------------
# typecode.cpp - R2TAO CORBA TypeCode support
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
#include "typecode.h"
#include "exception.h"
#include "object.h"
#include "tao/IFR_Client/IFR_BaseC.h"
#include "tao/TypeCodeFactory/TypeCodeFactory_Loader.h"
#include "tao/TypeCodeFactory_Adapter.h"
#include "tao/ORB_Core.h"
#include "ace/Dynamic_Service.h"

VALUE R2TAO_EXPORT r2corba_cTypeCode = 0;
VALUE R2TAO_EXPORT r2tao_cTypeCode = 0;

// CORBA TypeCode instance methods
static VALUE r2tao_TypeCode_kind(VALUE self);
static VALUE r2tao_TypeCode_compact_typecode(VALUE self);
static VALUE r2tao_TypeCode_equal(VALUE self, VALUE tc);
static VALUE r2tao_TypeCode_equivalent(VALUE self, VALUE tc);
static VALUE r2tao_TypeCode_id(VALUE self);
static VALUE r2tao_TypeCode_name(VALUE self);
static VALUE r2tao_TypeCode_member_count(VALUE self);
static VALUE r2tao_TypeCode_member_name(VALUE self, VALUE index);
static VALUE r2tao_TypeCode_member_type(VALUE self, VALUE index);
static VALUE r2tao_TypeCode_member_label(VALUE self, VALUE index);
static VALUE r2tao_TypeCode_member_visibility(VALUE self, VALUE index);
static VALUE r2tao_TypeCode_discriminator_type(VALUE self);
static VALUE r2tao_TypeCode_default_index(VALUE self);
static VALUE r2tao_TypeCode_length(VALUE self);
static VALUE r2tao_TypeCode_content_type(VALUE self);
static VALUE r2tao_TypeCode_fixed_digits(VALUE self);
static VALUE r2tao_TypeCode_fixed_scale(VALUE self);
static VALUE r2tao_TypeCode_type_modifier(VALUE self);
static VALUE r2tao_TypeCode_concrete_basetype(VALUE self);

// CORBA TypeCode class method
static VALUE r2tao_TypeCode_create_recursive_tc(VALUE klass, VALUE id);
static VALUE r2tao_TypeCode_create_tc(int _argc, VALUE *_argv0, VALUE klass);
static VALUE r2tao_TypeCode_get_primitive_tc(VALUE klass, VALUE kind);

static VALUE r2tao_sym_default;

void r2tao_init_Any(); // in any.cpp

void r2tao_init_LongDouble(); // in longdouble.cpp

void r2tao_Init_Typecode()
{
  VALUE k;

  if (r2tao_cTypeCode) return;

  //rb_eval_string("puts 'r2tao_Init_Typecode start' if $VERBOSE");

  r2corba_cTypeCode = rb_eval_string ("::R2CORBA::CORBA::TypeCode");
  k = r2tao_cTypeCode =
    rb_define_class_under (r2tao_nsCORBA_Native, "TypeCode", rb_cObject);

  //rb_eval_string("puts 'r2tao_Init_Typecode 2' if $VERBOSE");

  // define TypeCode methods
  rb_define_method(k, "kind", RUBY_METHOD_FUNC(r2tao_TypeCode_kind), 0);
  rb_define_method(k, "get_compact_typecode", RUBY_METHOD_FUNC(r2tao_TypeCode_compact_typecode), 0);
  rb_define_method(k, "equal", RUBY_METHOD_FUNC(r2tao_TypeCode_equal), 1);
  rb_define_method(k, "equivalent", RUBY_METHOD_FUNC(r2tao_TypeCode_equivalent), 1);
  rb_define_method(k, "id", RUBY_METHOD_FUNC(r2tao_TypeCode_id), 0);
  rb_define_method(k, "name", RUBY_METHOD_FUNC(r2tao_TypeCode_name), 0);
  rb_define_method(k, "member_count", RUBY_METHOD_FUNC(r2tao_TypeCode_member_count), 0);
  rb_define_method(k, "member_name", RUBY_METHOD_FUNC(r2tao_TypeCode_member_name), 1);
  rb_define_method(k, "member_type", RUBY_METHOD_FUNC(r2tao_TypeCode_member_type), 1);
  rb_define_method(k, "member_label", RUBY_METHOD_FUNC(r2tao_TypeCode_member_label), 1);
  rb_define_method(k, "member_visibility", RUBY_METHOD_FUNC(r2tao_TypeCode_member_visibility), 1);
  rb_define_method(k, "discriminator_type", RUBY_METHOD_FUNC(r2tao_TypeCode_discriminator_type), 0);
  rb_define_method(k, "default_index", RUBY_METHOD_FUNC(r2tao_TypeCode_default_index), 0);
  rb_define_method(k, "length", RUBY_METHOD_FUNC(r2tao_TypeCode_length), 0);
  rb_define_method(k, "content_type", RUBY_METHOD_FUNC(r2tao_TypeCode_content_type), 0);
  rb_define_method(k, "fixed_digits", RUBY_METHOD_FUNC(r2tao_TypeCode_fixed_digits), 0);
  rb_define_method(k, "fixed_scale", RUBY_METHOD_FUNC(r2tao_TypeCode_fixed_scale), 0);
  rb_define_method(k, "type_modifier", RUBY_METHOD_FUNC(r2tao_TypeCode_type_modifier), 0);
  rb_define_method(k, "concrete_basetype", RUBY_METHOD_FUNC(r2tao_TypeCode_concrete_basetype), 0);

  rb_define_singleton_method(k, "create_recursive_tc", RUBY_METHOD_FUNC(r2tao_TypeCode_create_recursive_tc), 1);
  rb_define_singleton_method(k, "create_tc", RUBY_METHOD_FUNC(r2tao_TypeCode_create_tc), -1);
  rb_define_singleton_method(k, "get_primitive_tc", RUBY_METHOD_FUNC(r2tao_TypeCode_get_primitive_tc), 1);

  // define TypeCode-kind constants
  rb_define_const (r2tao_nsCORBA, "TK_NULL", INT2NUM (CORBA::tk_null));
  rb_define_const (r2tao_nsCORBA, "TK_VOID", INT2NUM (CORBA::tk_void));
  rb_define_const (r2tao_nsCORBA, "TK_SHORT", INT2NUM (CORBA::tk_short));
  rb_define_const (r2tao_nsCORBA, "TK_LONG", INT2NUM (CORBA::tk_long));
  rb_define_const (r2tao_nsCORBA, "TK_USHORT", INT2NUM (CORBA::tk_ushort));
  rb_define_const (r2tao_nsCORBA, "TK_ULONG", INT2NUM (CORBA::tk_ulong));
  rb_define_const (r2tao_nsCORBA, "TK_FLOAT", INT2NUM (CORBA::tk_float));
  rb_define_const (r2tao_nsCORBA, "TK_DOUBLE", INT2NUM (CORBA::tk_double));
  rb_define_const (r2tao_nsCORBA, "TK_BOOLEAN", INT2NUM (CORBA::tk_boolean));
  rb_define_const (r2tao_nsCORBA, "TK_CHAR", INT2NUM (CORBA::tk_char));
  rb_define_const (r2tao_nsCORBA, "TK_OCTET", INT2NUM (CORBA::tk_octet));
  rb_define_const (r2tao_nsCORBA, "TK_ANY", INT2NUM (CORBA::tk_any));
  rb_define_const (r2tao_nsCORBA, "TK_TYPECODE", INT2NUM (CORBA::tk_TypeCode));
  rb_define_const (r2tao_nsCORBA, "TK_PRINCIPAL", INT2NUM (CORBA::tk_Principal));
  rb_define_const (r2tao_nsCORBA, "TK_OBJREF", INT2NUM (CORBA::tk_objref));
  rb_define_const (r2tao_nsCORBA, "TK_STRUCT", INT2NUM (CORBA::tk_struct));
  rb_define_const (r2tao_nsCORBA, "TK_UNION", INT2NUM (CORBA::tk_union));
  rb_define_const (r2tao_nsCORBA, "TK_ENUM", INT2NUM (CORBA::tk_enum));
  rb_define_const (r2tao_nsCORBA, "TK_STRING", INT2NUM (CORBA::tk_string));
  rb_define_const (r2tao_nsCORBA, "TK_SEQUENCE", INT2NUM (CORBA::tk_sequence));
  rb_define_const (r2tao_nsCORBA, "TK_ARRAY", INT2NUM (CORBA::tk_array));
  rb_define_const (r2tao_nsCORBA, "TK_ALIAS", INT2NUM (CORBA::tk_alias));
  rb_define_const (r2tao_nsCORBA, "TK_EXCEPT", INT2NUM (CORBA::tk_except));
  rb_define_const (r2tao_nsCORBA, "TK_LONGLONG", INT2NUM (CORBA::tk_longlong));
  rb_define_const (r2tao_nsCORBA, "TK_ULONGLONG", INT2NUM (CORBA::tk_ulonglong));
  rb_define_const (r2tao_nsCORBA, "TK_LONGDOUBLE", INT2NUM (CORBA::tk_longdouble));
  rb_define_const (r2tao_nsCORBA, "TK_WCHAR", INT2NUM (CORBA::tk_wchar));
  rb_define_const (r2tao_nsCORBA, "TK_WSTRING", INT2NUM (CORBA::tk_wstring));
  rb_define_const (r2tao_nsCORBA, "TK_FIXED", INT2NUM (CORBA::tk_fixed));
  rb_define_const (r2tao_nsCORBA, "TK_VALUE", INT2NUM (CORBA::tk_value));
  rb_define_const (r2tao_nsCORBA, "TK_VALUE_BOX", INT2NUM (CORBA::tk_value_box));
  rb_define_const (r2tao_nsCORBA, "TK_NATIVE", INT2NUM (CORBA::tk_native));
  rb_define_const (r2tao_nsCORBA, "TK_ABSTRACT_INTERFACE", INT2NUM (CORBA::tk_abstract_interface));
  rb_define_const (r2tao_nsCORBA, "TK_LOCAL_INTERFACE", INT2NUM (CORBA::tk_local_interface));
  rb_define_const (r2tao_nsCORBA, "TK_COMPONENT", INT2NUM (CORBA::tk_component));
  rb_define_const (r2tao_nsCORBA, "TK_HOME", INT2NUM (CORBA::tk_home));
  rb_define_const (r2tao_nsCORBA, "TK_EVENT", INT2NUM (CORBA::tk_event));

  r2tao_sym_default = rb_eval_string(":default");

  r2tao_init_Any(); // initialize CORBA::Any support

  r2tao_init_LongDouble(); // initialize CORBA::LongDouble class

  //rb_eval_string("puts 'r2tao_Init_Typecode end' if $VERBOSE");
}

//-------------------------------------------------------------------
//  CORBA TypeCode methods
//
//===================================================================

static void _tc_free(void* ptr)
{
  if (ptr)
  {
    if (TAO_debug_level > 10)
      ACE_DEBUG ((LM_INFO, "R2TAO (%P|%t) - _tc_free:: dereferencing typecode %@\n", ptr));

    CORBA::release ((CORBA::TypeCode_ptr)ptr);
  }
}

R2TAO_EXPORT VALUE
r2tao_TypeCode_t2r(CORBA::TypeCode_ptr obj)
{
  VALUE ret;
  CORBA::TypeCode_ptr _tc;

  if (TAO_debug_level > 10)
    ACE_DEBUG ((LM_INFO, "R2TAO (%P|%t) - r2tao_TypeCode_t2r:: referencing typecode %@\n", obj));

  _tc = CORBA::TypeCode::_duplicate(obj);
  ret = Data_Wrap_Struct(r2tao_cTypeCode, 0, _tc_free, _tc);

  return ret;
}

R2TAO_EXPORT CORBA::TypeCode_ptr
r2tao_TypeCode_r2t(VALUE obj)
{
  CORBA::TypeCode_ptr ret;

  r2tao_check_type(obj, r2tao_cTypeCode);
  Data_Get_Struct(obj, CORBA::TypeCode, ret);
  return ret;
}

R2TAO_EXPORT VALUE
r2corba_TypeCode_t2r(CORBA::TypeCode_ptr obj)
{
  static ID from_native_ID = rb_intern ("from_native");

  return rb_funcall (r2corba_cTypeCode, from_native_ID, 1, r2tao_TypeCode_t2r (obj));
}

R2TAO_EXPORT CORBA::TypeCode_ptr
r2corba_TypeCode_r2t(VALUE obj)
{
  static ID tc_ID = rb_intern ("tc_");

  return r2tao_TypeCode_r2t (rb_funcall (obj, tc_ID, 0));
}

/*
 * Class methods
 */

VALUE r2tao_TypeCode_get_primitive_tc(VALUE /*self*/, VALUE rkind)
{
  CORBA::TypeCode_ptr tc = CORBA::TypeCode::_nil ();
  CORBA::TCKind kind = (CORBA::TCKind)NUM2INT (rkind);
  switch (kind)
  {
    case CORBA::tk_null:
      tc = CORBA::_tc_null;
      break;
    case CORBA::tk_void:
      tc = CORBA::_tc_void;
      break;
    case CORBA::tk_short:
      tc = CORBA::_tc_short;
      break;
    case CORBA::tk_long:
      tc = CORBA::_tc_long;
      break;
    case CORBA::tk_ushort:
      tc = CORBA::_tc_ushort;
      break;
    case CORBA::tk_ulong:
      tc = CORBA::_tc_ulong;
      break;
    case CORBA::tk_longlong:
      tc = CORBA::_tc_longlong;
      break;
    case CORBA::tk_ulonglong:
      tc = CORBA::_tc_ulonglong;
      break;
    case CORBA::tk_float:
      tc = CORBA::_tc_float;
      break;
    case CORBA::tk_double:
      tc = CORBA::_tc_double;
      break;
    case CORBA::tk_longdouble:
      tc = CORBA::_tc_longdouble;
      break;
    case CORBA::tk_boolean:
      tc = CORBA::_tc_boolean;
      break;
    case CORBA::tk_char:
      tc = CORBA::_tc_char;
      break;
    case CORBA::tk_octet:
      tc = CORBA::_tc_octet;
      break;
    case CORBA::tk_wchar:
      tc = CORBA::_tc_wchar;
      break;
    case CORBA::tk_any:
      tc = CORBA::_tc_any;
      break;
    case CORBA::tk_TypeCode:
      tc = CORBA::_tc_TypeCode;
      break;
    case CORBA::tk_Principal:
      tc = CORBA::_tc_Principal;
      break;
    case CORBA::tk_objref:
      tc = CORBA::_tc_Object;
      break;
    default:
      return Qnil;
  }

  if (TAO_debug_level > 9)
    ACE_DEBUG ((LM_INFO, "R2TAO (%P|%t) - TypeCode::get_primitive_tc:: "
                         "referencing primitive typecode %d\n",
                         kind));
  return r2tao_TypeCode_t2r (tc);
}

/*
 *  TypeCode creation
 */

VALUE r2tao_TypeCode_create_recursive_tc(VALUE /*klass*/, VALUE id)
{
  TAO_TypeCodeFactory_Adapter *adapter =
    ACE_Dynamic_Service<TAO_TypeCodeFactory_Adapter>::instance (
        TAO_ORB_Core::typecodefactory_adapter_name ());

  if (adapter == 0)
  {
    X_CORBA(INTERNAL);
  }

  CORBA::TypeCode_var _tc = CORBA::TypeCode::_nil ();

  R2TAO_TRY
  {
    CHECK_RTYPE(id, T_STRING);

    if (TAO_debug_level > 9)
      ACE_DEBUG ((LM_INFO, "R2TAO (%P|%t) - TypeCode::create_recursive_tc:: "
                           "creating recursive typecode %s\n",
                           RSTRING_PTR (id)));

    _tc = adapter->create_recursive_tc(RSTRING_PTR (id));
  }
  R2TAO_CATCH;

  return r2tao_TypeCode_t2r (_tc);
}

VALUE r2tao_TypeCode_create_tc(int _argc, VALUE *_argv0, VALUE /*klass*/)
{
  TAO_TypeCodeFactory_Adapter *adapter =
    ACE_Dynamic_Service<TAO_TypeCodeFactory_Adapter>::instance (
        TAO_ORB_Core::typecodefactory_adapter_name ());

  if (adapter == 0)
  {
    X_CORBA(INTERNAL);
  }

  VALUE rkind;
  VALUE args;
  rb_scan_args(_argc, _argv0, "1*", &rkind, &args);

  CORBA::TypeCode_ptr _tc = CORBA::TypeCode::_nil ();

  R2TAO_TRY
  {
    CORBA::TCKind _kind = (CORBA::TCKind)NUM2INT (rkind);

    if (TAO_debug_level > 9)
      ACE_DEBUG ((LM_INFO, "R2TAO (%P|%t) - TypeCode::create_tc:: "
                           "creating typecode of kind %d\n",
                           _kind));

    switch (_kind)
    {
      case CORBA::tk_abstract_interface:
      {
        VALUE rid = rb_ary_shift (args);
        VALUE rname = rb_ary_shift (args);
        CHECK_RTYPE(rid, T_STRING);
        CHECK_RTYPE(rname, T_STRING);
        _tc = adapter->create_abstract_interface_tc (RSTRING_PTR (rid), RSTRING_PTR (rname));
      }
      break;

      case CORBA::tk_objref:
      {
        VALUE rid = rb_ary_shift (args);
        VALUE rname = rb_ary_shift (args);
        CHECK_RTYPE(rid, T_STRING);
        CHECK_RTYPE(rname, T_STRING);
        _tc = adapter->create_interface_tc (RSTRING_PTR (rid), RSTRING_PTR (rname));
      }
      break;

      case CORBA::tk_home:
      {
        VALUE rid = rb_ary_shift (args);
        VALUE rname = rb_ary_shift (args);
        CHECK_RTYPE(rid, T_STRING);
        CHECK_RTYPE(rname, T_STRING);
        _tc = adapter->create_home_tc (RSTRING_PTR (rid), RSTRING_PTR (rname));
      }
      break;

      case CORBA::tk_component:
      {
        VALUE rid = rb_ary_shift (args);
        VALUE rname = rb_ary_shift (args);
        CHECK_RTYPE(rid, T_STRING);
        CHECK_RTYPE(rname, T_STRING);
        _tc = adapter->create_component_tc (RSTRING_PTR (rid), RSTRING_PTR (rname));
      }
      break;

      case CORBA::tk_value_box:
      case CORBA::tk_alias:
      {
        VALUE rid = rb_ary_shift (args);
        VALUE rname = rb_ary_shift (args);
        CHECK_RTYPE(rid, T_STRING);
        CHECK_RTYPE(rname, T_STRING);
        VALUE raliased_tc = rb_ary_shift (args);
        CORBA::TypeCode_ptr _aliased_tc = r2tao_TypeCode_r2t (raliased_tc);
        if (CORBA::tk_alias == _kind)
          _tc = adapter->create_alias_tc (RSTRING_PTR (rid), RSTRING_PTR (rname),
                                          _aliased_tc);
        else
          _tc = adapter->create_value_box_tc (RSTRING_PTR (rid), RSTRING_PTR (rname),
                                              _aliased_tc);
      }
      break;

      case CORBA::tk_value:
      case CORBA::tk_event:
      {
        VALUE rid = rb_ary_shift (args);
        VALUE rname = rb_ary_shift (args);
        CHECK_RTYPE(rid, T_STRING);
        CHECK_RTYPE(rname, T_STRING);
        VALUE rmodifier = rb_ary_shift (args);
        CORBA::ValueModifier modifier =
            static_cast <CORBA::ValueModifier> (NUM2INT (rmodifier));
        VALUE rbase_tc = rb_ary_shift (args);
        CORBA::TypeCode_ptr base_tc = CORBA::TypeCode::_nil ();
        if (! NIL_P(rbase_tc))
        {
          base_tc = r2tao_TypeCode_r2t (rbase_tc);
        }
        VALUE rmembers = rb_ary_shift (args);
        CHECK_RTYPE(rmembers, T_ARRAY);
        CORBA::ULong count = static_cast<unsigned long> (RARRAY_LEN (rmembers));
        CORBA::ValueMemberSeq members (count);
        members.length (count);
        for (unsigned long m=0; m<count ;++m)
        {
          VALUE mset = rb_ary_entry (rmembers, m);
          CHECK_RTYPE(mset, T_ARRAY);
          VALUE mname = rb_ary_entry (mset, 0);
          CHECK_RTYPE(mname, T_STRING);
          VALUE rmtc = rb_ary_entry (mset, 1);
          CORBA::TypeCode_ptr mtc = r2tao_TypeCode_r2t (rmtc);
          VALUE raccess = rb_ary_entry (mset, 2);
          CORBA::Visibility access = static_cast<CORBA::Visibility> (NUM2INT (raccess));
          members[m].name = CORBA::string_dup (RSTRING_PTR (mname));
          members[m].type = CORBA::TypeCode::_duplicate (mtc);
          members[m].access = access;
        }
        if (CORBA::tk_value == _kind)
          _tc = adapter->create_value_tc(RSTRING_PTR (rid),
                                         RSTRING_PTR (rname),
                                         modifier,
                                         base_tc,
                                         members);
        else
          _tc = adapter->create_event_tc(RSTRING_PTR (rid),
                                         RSTRING_PTR (rname),
                                         modifier,
                                         base_tc,
                                         members);
      }
      break;

      case CORBA::tk_sequence:
      case CORBA::tk_array:
      {
        VALUE rcont_bound = rb_ary_shift (args);
        CHECK_RTYPE(rcont_bound, T_FIXNUM);
        VALUE rcontent_tc = rb_ary_shift (args);
        CORBA::TypeCode_ptr _content_tc = r2tao_TypeCode_r2t (rcontent_tc);
        CORBA::ULong _bound = NUM2ULONG (rcont_bound);
        if (CORBA::tk_sequence == _kind)
          _tc = adapter->create_sequence_tc (_bound, _content_tc);
        else
          _tc = adapter->create_array_tc (_bound, _content_tc);
      }
      break;

      case CORBA::tk_string:
      {
        VALUE rlength = rb_ary_shift (args);
        CHECK_RTYPE(rlength, T_FIXNUM);
        CORBA::ULong _length = NUM2ULONG (rlength);
        if (_length)
        {
          _tc = adapter->create_string_tc (_length);
        }
        else
        {
          _tc = CORBA::_tc_string;
        }
      }
      break;

      case CORBA::tk_wstring:
      {
        VALUE rlength = rb_ary_shift (args);
        CHECK_RTYPE(rlength, T_FIXNUM);
        CORBA::ULong _length = NUM2ULONG (rlength);
        if (_length)
        {
          _tc = adapter->create_wstring_tc (_length);
        }
        else
        {
          _tc = CORBA::_tc_wstring;
        }
      }
      break;

      case CORBA::tk_except:
      case CORBA::tk_struct:
      {
        VALUE rid = rb_ary_shift (args);
        VALUE rname = rb_ary_shift (args);
        CHECK_RTYPE(rid, T_STRING);
        CHECK_RTYPE(rname, T_STRING);
        VALUE rmembers = rb_ary_shift (args);
        CHECK_RTYPE(rmembers, T_ARRAY);
        CORBA::ULong count = static_cast<unsigned long> (RARRAY_LEN (rmembers));
        CORBA::StructMemberSeq members (count);
        members.length (count);
        for (unsigned long m=0; m<count ;++m)
        {
          VALUE mset = rb_ary_entry (rmembers, m);
          CHECK_RTYPE(mset, T_ARRAY);
          VALUE mname = rb_ary_entry (mset, 0);
          CHECK_RTYPE(mname, T_STRING);
          VALUE rmtc = rb_ary_entry (mset, 1);
          CORBA::TypeCode_ptr mtc = r2tao_TypeCode_r2t (rmtc);
          members[m].name = CORBA::string_dup (RSTRING_PTR (mname));
          members[m].type = CORBA::TypeCode::_duplicate (mtc);
        }
        if (CORBA::tk_struct == _kind)
          _tc = adapter->create_struct_tc (RSTRING_PTR (rid),
                                        RSTRING_PTR (rname),
                                        members);
        else
          _tc = adapter->create_exception_tc (RSTRING_PTR (rid),
                                           RSTRING_PTR (rname),
                                           members);
      }
      break;

      case CORBA::tk_enum:
      {
        VALUE rid = rb_ary_shift (args);
        VALUE rname = rb_ary_shift (args);
        CHECK_RTYPE(rid, T_STRING);
        CHECK_RTYPE(rname, T_STRING);
        VALUE rmembers = rb_ary_shift (args);
        CHECK_RTYPE(rmembers, T_ARRAY);
        CORBA::ULong count = static_cast<unsigned long> (RARRAY_LEN (rmembers));
        CORBA::EnumMemberSeq members (count);
        members.length (count);
        for (unsigned long m=0; m<count ;++m)
        {
          VALUE el = rb_ary_entry (rmembers, m);
          CHECK_RTYPE(el, T_STRING);
          members[m] = CORBA::string_dup (RSTRING_PTR (el));
        }
        _tc = adapter->create_enum_tc (RSTRING_PTR (rid),
                                       RSTRING_PTR (rname),
                                       members);
      }
      break;

      case CORBA::tk_union:
      {
        static ID _eq_id = rb_intern ("==");

        VALUE rid = rb_ary_shift (args);
        VALUE rname = rb_ary_shift (args);
        CHECK_RTYPE(rid, T_STRING);
        CHECK_RTYPE(rname, T_STRING);
        VALUE rswtc = rb_ary_shift (args);
        CORBA::TypeCode_ptr swtc = r2tao_TypeCode_r2t (rswtc);
        VALUE rmembers = rb_ary_shift (args);
        CHECK_RTYPE(rmembers, T_ARRAY);
        CORBA::ULong count = static_cast<unsigned long> (RARRAY_LEN (rmembers));
        CORBA::UnionMemberSeq members (count);
        members.length (count);
        for (unsigned long m=0; m<count ;++m)
        {
          VALUE mset = rb_ary_entry (rmembers, m);
          CHECK_RTYPE(mset, T_ARRAY);
          VALUE mlabel = rb_ary_shift (mset);
          VALUE mname = rb_ary_shift (mset);
          CHECK_RTYPE(mname, T_STRING);
          VALUE rmtc = rb_ary_shift (mset);
          CORBA::TypeCode_ptr mtc = r2tao_TypeCode_r2t (rmtc);
          if (Qtrue == rb_funcall (mlabel, _eq_id, 1, r2tao_sym_default))
          {
            CORBA::Octet defval = 0;
            members[m].label <<= CORBA::Any::from_octet(defval);
          }
          else
          {
            r2tao_Ruby2Any(members[m].label, swtc, mlabel);
          }
          members[m].name = CORBA::string_dup (RSTRING_PTR (mname));
          members[m].type = CORBA::TypeCode::_duplicate (mtc);
        }
        _tc = adapter->create_union_tc (RSTRING_PTR (rid),
                                        RSTRING_PTR (rname),
                                        swtc,
                                        members);
      }
      break;

      default:
      {
        return Qnil;
      }
    }
  }
  R2TAO_CATCH;

  return r2tao_TypeCode_t2r (_tc);
}

/*
 * Instance methods
 */
VALUE r2tao_TypeCode_kind(VALUE self)
{
  VALUE ret = Qnil;
  CORBA::TypeCode_ptr tc = r2tao_TypeCode_r2t (self);

  R2TAO_TRY
  {
    ret = INT2NUM ((int)tc->kind ());
  }
  R2TAO_CATCH;

  return ret;
}

VALUE r2tao_TypeCode_compact_typecode(VALUE self)
{
  VALUE ret = Qnil;
  CORBA::TypeCode_ptr tc = r2tao_TypeCode_r2t (self);

  R2TAO_TRY
  {
    ret = r2tao_TypeCode_t2r (tc->get_compact_typecode ());
  }
  R2TAO_CATCH;

  return ret;
}

VALUE r2tao_TypeCode_equal(VALUE self, VALUE rtc)
{
  VALUE ret = Qnil;
  CORBA::TypeCode_ptr tc = r2tao_TypeCode_r2t (self);
  CORBA::TypeCode_ptr other_tc = r2tao_TypeCode_r2t (rtc);

  R2TAO_TRY
  {
    ret = tc->equal (other_tc) ? Qtrue : Qfalse;
  }
  R2TAO_CATCH;

  return ret;
}

VALUE r2tao_TypeCode_equivalent(VALUE self, VALUE rtc)
{
  VALUE ret = Qnil;
  CORBA::TypeCode_ptr tc = r2tao_TypeCode_r2t (self);
  CORBA::TypeCode_ptr other_tc = r2tao_TypeCode_r2t (rtc);

  R2TAO_TRY
  {
    ret = tc->equivalent (other_tc) ? Qtrue : Qfalse;
  }
  R2TAO_CATCH;

  return ret;
}

VALUE r2tao_TypeCode_id(VALUE self)
{
  VALUE ret = Qnil;
  CORBA::TypeCode_ptr tc = r2tao_TypeCode_r2t (self);

  R2TAO_TRY
  {
    ret = rb_str_new2 (tc->id ());
  }
  R2TAO_CATCH;

  return ret;
}

VALUE r2tao_TypeCode_name(VALUE self)
{
  VALUE ret = Qnil;
  CORBA::TypeCode_ptr tc = r2tao_TypeCode_r2t (self);

  R2TAO_TRY
  {
    ret = rb_str_new2 (tc->name ());
  }
  R2TAO_CATCH;

  return ret;
}

VALUE r2tao_TypeCode_member_count(VALUE self)
{
  VALUE ret = Qnil;
  CORBA::TypeCode_ptr tc = r2tao_TypeCode_r2t (self);

  R2TAO_TRY
  {
    ret = ULONG2NUM (tc->member_count ());
  }
  R2TAO_CATCH;

  return ret;
}

VALUE r2tao_TypeCode_member_name(VALUE self, VALUE index)
{
  VALUE ret = Qnil;
  CORBA::TypeCode_ptr tc = r2tao_TypeCode_r2t (self);

  R2TAO_TRY
  {
    CHECK_RTYPE (index, T_FIXNUM);
    ret = rb_str_new2 (tc->member_name (NUM2ULONG (index)));
  }
  R2TAO_CATCH;

  return ret;
}

VALUE r2tao_TypeCode_member_type(VALUE self, VALUE index)
{
  VALUE ret = Qnil;
  CORBA::TypeCode_ptr tc = r2tao_TypeCode_r2t (self);

  R2TAO_TRY
  {
    CHECK_RTYPE (index, T_FIXNUM);
    CORBA::TypeCode_var mtc = tc->member_type (NUM2ULONG (index));
    ret = r2tao_TypeCode_t2r (mtc.in ());
  }
  R2TAO_CATCH;

  return ret;
}

VALUE r2tao_TypeCode_member_label(VALUE self, VALUE index)
{
  VALUE ret = Qnil;
  CORBA::TypeCode_ptr tc = r2tao_TypeCode_r2t (self);

  R2TAO_TRY
  {
    CHECK_RTYPE (index, T_FIXNUM);
    CORBA::Any* ml = tc->member_label (NUM2ULONG (index));
    CORBA::TypeCode_var mt = tc->member_type (NUM2ULONG (index));
    VALUE rtc = r2corba_TypeCode_t2r (mt.in ());
    ret = r2tao_Any2Ruby (*ml, mt.in (), rtc, rtc);
  }
  R2TAO_CATCH;

  return ret;
}

VALUE r2tao_TypeCode_member_visibility(VALUE self, VALUE index)
{
  VALUE ret = Qnil;
  CORBA::TypeCode_ptr tc = r2tao_TypeCode_r2t (self);

  R2TAO_TRY
  {
    CHECK_RTYPE (index, T_FIXNUM);
    ret = INT2NUM ((int)tc->member_visibility (NUM2ULONG (index)));
  }
  R2TAO_CATCH;

  return ret;
}

VALUE r2tao_TypeCode_discriminator_type(VALUE self)
{
  VALUE ret = Qnil;
  CORBA::TypeCode_ptr tc = r2tao_TypeCode_r2t (self);

  R2TAO_TRY
  {
    CORBA::TypeCode_var dtc = tc->discriminator_type ();
    ret = r2tao_TypeCode_t2r (dtc.in ());
  }
  R2TAO_CATCH;

  return ret;
}

VALUE r2tao_TypeCode_default_index(VALUE self)
{
  VALUE ret = Qnil;
  CORBA::TypeCode_ptr tc = r2tao_TypeCode_r2t (self);

  R2TAO_TRY
  {
    ret = LONG2NUM (tc->default_index ());
  }
  R2TAO_CATCH;

  return ret;
}

VALUE r2tao_TypeCode_length(VALUE self)
{
  VALUE ret = Qnil;
  CORBA::TypeCode_ptr tc = r2tao_TypeCode_r2t (self);

  R2TAO_TRY
  {
    ret = ULONG2NUM (tc->length ());
  }
  R2TAO_CATCH;

  return ret;
}

VALUE r2tao_TypeCode_content_type(VALUE self)
{
  VALUE ret = Qnil;
  CORBA::TypeCode_ptr tc = r2tao_TypeCode_r2t (self);

  R2TAO_TRY
  {
    CORBA::TypeCode_var ctc = tc->content_type ();
    ret = r2tao_TypeCode_t2r (ctc.in ());
  }
  R2TAO_CATCH;

  return ret;
}

VALUE r2tao_TypeCode_fixed_digits(VALUE self)
{
  VALUE ret = Qnil;
  CORBA::TypeCode_ptr tc = r2tao_TypeCode_r2t (self);

  R2TAO_TRY
  {
    ret = UINT2NUM (tc->fixed_digits ());
  }
  R2TAO_CATCH;

  return ret;
}

VALUE r2tao_TypeCode_fixed_scale(VALUE self)
{
  VALUE ret = Qnil;
  CORBA::TypeCode_ptr tc = r2tao_TypeCode_r2t (self);

  R2TAO_TRY
  {
    ret = UINT2NUM (tc->fixed_scale ());
  }
  R2TAO_CATCH;

  return ret;
}

VALUE r2tao_TypeCode_type_modifier(VALUE self)
{
  VALUE ret = Qnil;
  CORBA::TypeCode_ptr tc = r2tao_TypeCode_r2t (self);

  R2TAO_TRY
  {
    ret = INT2NUM (tc->type_modifier ());
  }
  R2TAO_CATCH;

  return ret;
}

VALUE r2tao_TypeCode_concrete_basetype(VALUE self)
{
  VALUE ret = Qnil;
  CORBA::TypeCode_ptr tc = r2tao_TypeCode_r2t (self);

  R2TAO_TRY
  {
    CORBA::TypeCode_var ctc = tc->concrete_base_type ();
    ret = r2tao_TypeCode_t2r (ctc.in ());
  }
  R2TAO_CATCH;

  return ret;
}
