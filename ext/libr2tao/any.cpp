/*--------------------------------------------------------------------
# any.cpp - R2TAO CORBA Any support
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
#include "object.h"
#include "typecode.h"
#include "longdouble.h"
#include "values.h"
#include "tao/AnyTypeCode/True_RefCount_Policy.h"
#include "tao/AnyTypeCode/Sequence_TypeCode.h"
#include "tao/AnyTypeCode/Any.h"
#include "tao/AnyTypeCode/BooleanSeqA.h"
#include "tao/AnyTypeCode/CharSeqA.h"
#include "tao/AnyTypeCode/DoubleSeqA.h"
#include "tao/AnyTypeCode/FloatSeqA.h"
#include "tao/AnyTypeCode/LongDoubleSeqA.h"
#include "tao/AnyTypeCode/LongSeqA.h"
#include "tao/AnyTypeCode/OctetSeqA.h"
#include "tao/AnyTypeCode/ShortSeqA.h"
#include "tao/AnyTypeCode/StringSeqA.h"
#include "tao/AnyTypeCode/ULongSeqA.h"
#include "tao/AnyTypeCode/UShortSeqA.h"
#include "tao/AnyTypeCode/WCharSeqA.h"
#include "tao/AnyTypeCode/WStringSeqA.h"
#include "tao/AnyTypeCode/LongLongSeqA.h"
#include "tao/AnyTypeCode/ULongLongSeqA.h"
#include "tao/AnyTypeCode/Any_Dual_Impl_T.h"
#include "tao/BooleanSeqC.h"
#include "tao/CharSeqC.h"
#include "tao/DoubleSeqC.h"
#include "tao/FloatSeqC.h"
#include "tao/LongDoubleSeqC.h"
#include "tao/LongSeqC.h"
#include "tao/OctetSeqC.h"
#include "tao/ShortSeqC.h"
#include "tao/StringSeqC.h"
#include "tao/ULongSeqC.h"
#include "tao/UShortSeqC.h"
#include "tao/WCharSeqC.h"
#include "tao/WStringSeqC.h"
#include "tao/LongLongSeqC.h"
#include "tao/ULongLongSeqC.h"
#include "tao/DynamicAny/DynamicAny.h"
#include "tao/Object_Loader.h"
#include "tao/ORB_Core.h"
#include "ace/Dynamic_Service.h"

#define RUBY_INVOKE_FUNC RUBY_ALLOC_FUNC

static VALUE r2tao_cAny;

static ID get_type_ID;
static ID typecode_for_value_ID;
static ID value_for_any_ID;
//static ID from_native_ID;
static ID member_type_ID;
static ID content_type_ID;
static ID _narrow_ID;
static ID value_ID;


void r2tao_init_Any()
{
  r2tao_cAny = rb_eval_string ("R2CORBA::CORBA::Any");

  get_type_ID = rb_intern ("get_type");
  typecode_for_value_ID = rb_intern ("typecode_for_value");
  value_for_any_ID = rb_intern ("value_for_any");
  //from_native_ID = rb_intern ("from_native");
  member_type_ID = rb_intern ("member_type");
  content_type_ID = rb_intern ("content_type");
  _narrow_ID = rb_intern ("_narrow");
  value_ID = rb_intern ("value");
}

/*===================================================================
 *  Dynamic Any factory
 *
 */
static DynamicAny::DynAnyFactory_var g_dynany_factory;

static DynamicAny::DynAnyFactory_ptr get_dynany_factory()
{
  if (CORBA::is_nil (g_dynany_factory.in ()))
  {
    TAO_Object_Loader *loader =
      ACE_Dynamic_Service<TAO_Object_Loader>::instance
        (ACE_TEXT ("DynamicAny_Loader"));

    if (loader != 0)
    {
      g_dynany_factory = DynamicAny::DynAnyFactory::_narrow (
                            loader->create_object (CORBA::ORB::_nil(), 0, 0));
    }

    if (CORBA::is_nil (g_dynany_factory.in ()))
    {
      ACE_ERROR ((LM_ERROR, "R2TAO::Unable to resolve DynAnyFactory\n"));

      throw ::CORBA::INTERNAL ();
    }
  }
  return g_dynany_factory.in ();
}

#define DYNANY_FACTORY  get_dynany_factory ()

static DynamicAny::DynAny_ptr r2tao_CreateDynAny (const CORBA::Any& _any)
{
  DynamicAny::DynAny_ptr da =
      DYNANY_FACTORY->create_dyn_any (_any);

  return da;
}

static DynamicAny::DynAny_ptr r2tao_CreateDynAny4tc (CORBA::TypeCode_ptr _tc)
{
  DynamicAny::DynAny_ptr da =
      DYNANY_FACTORY->create_dyn_any_from_type_code (_tc);

  return da;
}

/*===================================================================
 *  Data conversion Ruby VALUE --> CORBA Any
 *
 */
static void r2tao_Ruby2Struct (CORBA::Any& _any, CORBA::TypeCode_ptr _tc, VALUE rs)
{
  if (TAO_debug_level > 9)
    ACE_DEBUG ((LM_INFO, "R2TAO (%P|%t) - Ruby2Struct:: kind=%d, rval=%@\n", _tc->kind (), rs));

  DynamicAny::DynAny_var da = r2tao_CreateDynAny4tc (_tc);
  DynamicAny::DynStruct_var das = DynamicAny::DynStruct::_narrow (da.in ());

  if (!NIL_P (rs))
  {
    CORBA::ULong mcount = _tc->member_count ();

    DynamicAny::NameValuePairSeq_var nvps = das->get_members ();

    for (CORBA::ULong m=0; m<mcount ;++m)
    {
      CORBA::TypeCode_var mtc = _tc->member_type (m);
      VALUE mval = rb_funcall (rs, rb_intern (_tc->member_name (m)), 0);
      r2tao_Ruby2Any (nvps[m].value, mtc.in (), mval);
    }

    das->set_members (nvps);
  }

  CORBA::Any_var av = das->to_any ();
  _any = av.in ();

  das->destroy ();
}

void r2tao_Ruby2Union (CORBA::Any& _any, CORBA::TypeCode_ptr _tc, VALUE ru)
{
  if (TAO_debug_level > 9)
    ACE_DEBUG ((LM_INFO, "R2TAO (%P|%t) - Ruby2Union:: kind=%d, rval=%@\n", _tc->kind (), ru));

  DynamicAny::DynAny_var da = r2tao_CreateDynAny4tc (_tc);
  DynamicAny::DynUnion_var dau = DynamicAny::DynUnion::_narrow (da.in ());

  if (!NIL_P (ru))
  {
    static ID _is_at_default_ID = rb_intern ("_is_at_default?");

    VALUE at_default = rb_funcall (ru, _is_at_default_ID, 0);
    VALUE value = rb_iv_get (ru, "@value");
    VALUE disc = rb_iv_get (ru, "@discriminator");
    if (at_default == Qfalse)
    {
      if (NIL_P (disc))
      {
        dau->set_to_no_active_member ();
      }
      else
      {
        CORBA::Any_var _any = new CORBA::Any;
        CORBA::TypeCode_var dtc = _tc->discriminator_type ();
        r2tao_Ruby2Any(*_any, dtc.in (), disc);
        DynamicAny::DynAny_var _dyna = r2tao_CreateDynAny (*_any);
        dau->set_discriminator (_dyna.in ());
      }
    }
    else
    {
      dau->set_to_default_member ();
    }

    if (!NIL_P (disc) && !NIL_P (value))
    {
      static ID _value_tc_ID = rb_intern("_value_tc");

      VALUE rvaltc = rb_funcall (ru, _value_tc_ID, 0);
      CORBA::TypeCode_ptr valtc = r2corba_TypeCode_r2t (rvaltc);
      CORBA::Any_var _any = new CORBA::Any;
      r2tao_Ruby2Any(*_any, valtc, value);
      DynamicAny::DynAny_var dynval = dau->member ();
      dynval->from_any (*_any);
    }
  }

  CORBA::Any_var av = dau->to_any ();
  _any = av.in ();

  dau->destroy ();
}

void r2tao_Ruby2Sequence(CORBA::Any& _any, CORBA::TypeCode_ptr _tc, VALUE rarr)
{
  CORBA::TypeCode_var _ctc = _tc->content_type ();
  if (TAO_debug_level > 9)
    ACE_DEBUG ((LM_INFO, "R2TAO (%P|%t) - Ruby2Sequence:: content kind=%d, rval type=%d\n", _ctc->kind (), rb_type (rarr)));

  CORBA::ULong alen = 0;
  if (!NIL_P (rarr))
  {
    switch (_ctc->kind ())
    {
      case CORBA::tk_char:
      case CORBA::tk_octet:
        CHECK_RTYPE(rarr, T_STRING);
        alen = static_cast<unsigned long> (RSTRING_LEN (rarr));
        break;
      default:
        CHECK_RTYPE(rarr, T_ARRAY);
        alen = static_cast<unsigned long> (RARRAY_LEN (rarr));
        break;
    }
  }

  switch (_ctc->kind ())
  {
    case CORBA::tk_short:
    {
      CORBA::ShortSeq_var tmp = new CORBA::ShortSeq();
      tmp->length (alen);
      for (CORBA::ULong l=0; l<alen ;++l)
      {
        VALUE el = rb_ary_entry (rarr, l);
        tmp[l] = (CORBA::Short)NUM2INT (el);
      }
      _any <<= tmp;
      return;
    }
    case CORBA::tk_long:
    {
      CORBA::LongSeq_var tmp = new CORBA::LongSeq();
      tmp->length (alen);
      for (CORBA::ULong l=0; l<alen ;++l)
      {
        VALUE el = rb_ary_entry (rarr, l);
        tmp[l] = (CORBA::Long)NUM2LONG (el);
      }
      _any <<= tmp;
      return;
    }
    case CORBA::tk_ushort:
    {
      CORBA::UShortSeq_var tmp = new CORBA::UShortSeq();
      tmp->length (alen);
      for (CORBA::ULong l=0; l<alen ;++l)
      {
        VALUE el = rb_ary_entry (rarr, l);
        tmp[l] = (CORBA::UShort)NUM2UINT (el);
      }
      _any <<= tmp;
      return;
    }
    case CORBA::tk_ulong:
    {
      CORBA::ULongSeq_var tmp = new CORBA::ULongSeq();
      tmp->length (alen);
      for (CORBA::ULong l=0; l<alen ;++l)
      {
        VALUE el = rb_ary_entry (rarr, l);
        tmp[l] = (CORBA::ULong)NUM2ULONG (el);
      }
      _any <<= tmp;
      return;
    }
    case CORBA::tk_longlong:
    {
      CORBA::LongLongSeq_var tmp = new CORBA::LongLongSeq();
      tmp->length (alen);
      for (CORBA::ULong l=0; l<alen ;++l)
      {
        VALUE el = rb_ary_entry (rarr, l);
        tmp[l] = (CORBA::LongLong)NUM2LL (el);
      }
      _any <<= tmp;
      return;
    }
    case CORBA::tk_ulonglong:
    {
      CORBA::ULongLongSeq_var tmp = new CORBA::ULongLongSeq();
      tmp->length (alen);
      for (CORBA::ULong l=0; l<alen ;++l)
      {
        VALUE el = rb_ary_entry (rarr, l);
        tmp[l] = (CORBA::ULongLong)NUM2ULL (el);
      }
      _any <<= tmp;
      return;
    }
    case CORBA::tk_float:
    {
      CORBA::FloatSeq_var tmp = new CORBA::FloatSeq();
      tmp->length (alen);
      for (CORBA::ULong l=0; l<alen ;++l)
      {
        VALUE el = rb_ary_entry (rarr, l);
        tmp[l] = (CORBA::Float)NUM2DBL (el);
      }
      _any <<= tmp;
      return;
    }
    case CORBA::tk_double:
    {
      CORBA::DoubleSeq_var tmp = new CORBA::DoubleSeq();
      tmp->length (alen);
      for (CORBA::ULong l=0; l<alen ;++l)
      {
        VALUE el = rb_ary_entry (rarr, l);
        tmp[l] = (CORBA::Double)NUM2DBL (el);
      }
      _any <<= tmp;
      return;
    }
    case CORBA::tk_longdouble:
    {
      CORBA::LongDoubleSeq_var tmp = new CORBA::LongDoubleSeq();
      tmp->length (alen);
      for (CORBA::ULong l=0; l<alen ;++l)
      {
        VALUE el = rb_ary_entry (rarr, l);
        ACE_CDR_LONG_DOUBLE_ASSIGNMENT (tmp[l], CLD2RLD (el));
      }
      _any <<= tmp;
      return;
    }
    case CORBA::tk_boolean:
    {
      CORBA::BooleanSeq_var tmp = new CORBA::BooleanSeq();
      tmp->length (alen);
      for (CORBA::ULong l=0; l<alen ;++l)
      {
        VALUE el = rb_ary_entry (rarr, l);
        tmp[l] = (NIL_P (el) || el == Qfalse) ? 0 : 1;
      }
      _any <<= tmp;
      return;
    }
    case CORBA::tk_char:
    {
      char* s = NIL_P (rarr) ? 0 : RSTRING_PTR (rarr);
      CORBA::CharSeq_var tmp = new CORBA::CharSeq();
      tmp->length (alen);
      for (unsigned long l=0; l<alen ;++l)
      {
        tmp[l] = s[l];
      }
      _any <<= tmp;
      return;
    }
    case CORBA::tk_octet:
    {
      unsigned char* s = NIL_P (rarr) ? 0 : (unsigned char*)RSTRING_PTR (rarr);
      CORBA::OctetSeq_var tmp = new CORBA::OctetSeq();
      tmp->length (alen);
      for (unsigned long l=0; l<alen ;++l)
      {
        tmp[l] = s[l];
      }
      _any <<= tmp;
      return;
    }
    case CORBA::tk_wchar:
    {
      CORBA::WCharSeq_var tmp = new CORBA::WCharSeq();
      tmp->length (alen);
      for (CORBA::ULong l=0; l<alen ;++l)
      {
        VALUE el = rb_ary_entry (rarr, l);
        tmp[l] = (CORBA::WChar)NUM2INT (el);
      }
      _any <<= tmp;
      return;
    }
    default:
    {
      DynamicAny::DynAny_var da = r2tao_CreateDynAny4tc (_tc);
      DynamicAny::DynSequence_var das = DynamicAny::DynSequence::_narrow (da.in ());

      if (!NIL_P (rarr) && alen > 0)
      {
        CORBA::ULong seqmax = _tc->length ();

        DynamicAny::AnySeq_var elems =
          seqmax == 0 ? new DynamicAny::AnySeq () : new DynamicAny::AnySeq (seqmax);
        elems->length (alen);

        for (CORBA::ULong e=0; e<alen ;++e)
        {
          VALUE elval = rb_ary_entry (rarr, e);
          r2tao_Ruby2Any (elems[e], _ctc.in (), elval);
        }

        das->set_elements (elems);
      }

      CORBA::Any_var av = das->to_any ();
      _any = av.in ();

      das->destroy ();
      return;
    }
  }

  ACE_ERROR ((LM_ERROR, "R2TAO::Unable to convert Ruby sequence to TAO\n"));
  throw ::CORBA::NO_IMPLEMENT (0, CORBA::COMPLETED_NO);
}

R2TAO_EXPORT void r2tao_Ruby2Any(CORBA::Any& _any, CORBA::TypeCode_ptr _tc, VALUE rval)
{
  if (TAO_debug_level > 9)
    ACE_DEBUG ((LM_INFO, "R2TAO (%P|%t) - Ruby2Any:: kind=%d, rval=%@\n", _tc->kind (), rval));

  switch (_tc->kind ())
  {
    case CORBA::tk_null:
    case CORBA::tk_void:
    {
      _any._tao_set_typecode (_tc);
      return;
    }
    case CORBA::tk_alias:
    {
      CORBA::TypeCode_var _ctc = _tc->content_type ();
      r2tao_Ruby2Any(_any, _ctc.in (), rval);
      return;
    }
    case CORBA::tk_short:
    {
      CORBA::Short val = NIL_P(rval) ? 0 : NUM2INT (rval);
      _any <<= val;
      return;
    }
    case CORBA::tk_long:
    {
      CORBA::Long val = NIL_P (rval) ? 0 : NUM2LONG (rval);
      _any <<= val;
      return;
    }
    case CORBA::tk_ushort:
    {
      CORBA::UShort val = NIL_P (rval) ? 0 : NUM2UINT (rval);
      _any <<= val;
      return;
    }
    case CORBA::tk_ulong:
    {
      CORBA::ULong val = NIL_P (rval) ? 0 : NUM2ULONG (rval);
      _any <<= val;
      return;
    }
    case CORBA::tk_longlong:
    {
      CORBA::LongLong val = NIL_P (rval) ? 0 : NUM2LL (rval);
      _any <<= val;
      return;
    }
    case CORBA::tk_ulonglong:
    {
      CORBA::ULongLong val = NIL_P (rval) ? 0 : NUM2ULL (rval);
      _any <<= val;
      return;
    }
    case CORBA::tk_float:
    {
      CORBA::Float val = NIL_P (rval) ? 0.0f : (CORBA::Float)NUM2DBL (rval);
      _any <<= val;
      return;
    }
    case CORBA::tk_double:
    {
      CORBA::Double val = NIL_P (rval) ? 0.0 : NUM2DBL (rval);
      _any <<= val;
      return;
    }
    case CORBA::tk_longdouble:
    {
      CORBA::LongDouble val;
      ACE_CDR_LONG_DOUBLE_ASSIGNMENT (val, NIL_P (rval) ? 0.0 : RLD2CLD (rval));
      _any <<= val;
      return;
    }
    case CORBA::tk_boolean:
    {
      CORBA::Boolean val = (NIL_P (rval) || rval == Qfalse) ? 0 : 1;
      _any <<= CORBA::Any::from_boolean (val);
      return;
    }
    case CORBA::tk_char:
    {
      CORBA::Char val = 0;
      if (!NIL_P (rval))
      {
        CHECK_RTYPE(rval, T_STRING);
        val = *RSTRING_PTR (rval);
      }
      _any <<= CORBA::Any::from_char (val);
      return;
    }
    case CORBA::tk_octet:
    {
      CORBA::Octet  val = NIL_P (rval) ? 0 : NUM2UINT (rval);
      _any <<= CORBA::Any::from_octet (val);
      return;
    }
    case CORBA::tk_wchar:
    {
      CORBA::WChar val = NIL_P (rval) ? 0 : NUM2UINT (rval);
      _any <<= CORBA::Any::from_wchar (val);
      return;
    }
    case CORBA::tk_string:
    {
      if (NIL_P (rval))
      {
        _any <<= (char*)0;
      }
      else
      {
        CHECK_RTYPE(rval, T_STRING);
        _any <<= RSTRING_PTR (rval);
      }
      return;
    }
    case CORBA::tk_wstring:
    {
      if (NIL_P (rval))
      {
        _any <<= (CORBA::WChar*)0;
      }
      else
      {
        CHECK_RTYPE(rval, T_ARRAY);
        CORBA::ULong alen = static_cast<unsigned long> (RARRAY_LEN (rval));
        CORBA::WString_var ws = CORBA::wstring_alloc (alen+1);
        for (CORBA::ULong l=0; l<alen ;++l)
        {
          ws[l] = static_cast<CORBA::WChar> (NUM2INT (rb_ary_entry (rval, l)));
        }
        ws[alen] = static_cast<CORBA::WChar> (0);
        _any <<= ws;
      }
      return;
    }
    case CORBA::tk_enum:
    {
      DynamicAny::DynAny_var da = r2tao_CreateDynAny4tc (_tc);
      DynamicAny::DynEnum_var das = DynamicAny::DynEnum::_narrow (da.in ());

      if (!NIL_P (rval))
      {
        das->set_as_ulong (NUM2ULONG (rval));
      }

      CORBA::Any_var av = das->to_any ();
      _any = av.in ();

      das->destroy ();
      return;
    }
    case CORBA::tk_array:
    {
      DynamicAny::DynAny_var da = r2tao_CreateDynAny4tc (_tc);
      DynamicAny::DynArray_var das = DynamicAny::DynArray::_narrow (da.in ());

      if (!NIL_P (rval))
      {
        CORBA::ULong arrlen = _tc->length ();

        DynamicAny::AnySeq_var elems = new DynamicAny::AnySeq (arrlen);
        elems->length (arrlen);

        CORBA::TypeCode_var etc = _tc->content_type ();

        for (CORBA::ULong e=0; e<arrlen ;++e)
        {
          VALUE eval = rb_ary_entry (rval, e);
          r2tao_Ruby2Any (elems[e], etc.in (), eval);
        }

        das->set_elements (elems);
      }

      CORBA::Any_var av = das->to_any ();
      _any = av.in ();

      das->destroy ();
      return;
    }
    case CORBA::tk_sequence:
    {
      r2tao_Ruby2Sequence(_any, _tc, rval);
      return;
    }
    case CORBA::tk_except:
    case CORBA::tk_struct:
    {
      r2tao_Ruby2Struct (_any, _tc, rval);
      return;
    }
    case CORBA::tk_union:
    {
      r2tao_Ruby2Union (_any, _tc, rval);
      return;
    }
    case CORBA::tk_objref:
    {
//       if (!NIL_P (rval))
//       {
//         _any <<= r2corba_Object_r2t (rval);
//       }
//       else
//       {
//         _any <<= CORBA::Object::_nil ();
//       }
      CORBA::Object_ptr objptr = CORBA::Object::_nil ();
      if (!NIL_P (rval))
      {
        objptr = r2corba_Object_r2t (rval);
      }
      TAO::Any_Impl_T<CORBA::Object>::insert (_any,
                                              CORBA::Object::_tao_any_destructor,
                                              _tc,
                                              CORBA::Object::_duplicate (objptr));
      return;
    }
    case CORBA::tk_abstract_interface:
    {
      if (!NIL_P (rval))
      {
        if (rb_obj_is_kind_of (rval, r2corba_cObject) == Qtrue)
        {
          R2TAO_AbstractObject_ptr abs_obj = nullptr;
          ACE_NEW_NORETURN (abs_obj,
                            R2TAO_AbstractObject (r2corba_Object_r2t (rval), _tc));
          _any <<= &abs_obj;
        }
        else
        {
          // abstract wrapper for Values
          R2TAO_AbstractValue_ptr abs_obj = nullptr;
          ACE_NEW_NORETURN (abs_obj,
                            R2TAO_AbstractValue (rval, _tc));
          _any <<= &abs_obj;
        }
      }
      else
      {
        TAO::Any_Impl_T<CORBA::AbstractBase>::insert (
            _any,
            CORBA::AbstractBase::_tao_any_destructor,
            _tc,
            0);
      }
      return;
    }
    case CORBA::tk_any:
    {
      CORBA::Any  anyval;
      r2tao_Ruby_to_Any(anyval, rval);
      _any <<= anyval;
      return;
    }
    case CORBA::tk_TypeCode:
    {
      if (!NIL_P (rval))
      {
        CORBA::TypeCode_ptr tctc = r2corba_TypeCode_r2t (rval);
        _any <<= tctc;
      }
      else
      {
        _any <<= CORBA::TypeCode::_nil ();
      }
      return;
    }
    case CORBA::tk_Principal:
    {
      break;
    }
    case CORBA::tk_value_box:
    {
      if (!NIL_P (rval) &&
          rb_obj_is_kind_of (rval, r2tao_cBoxedValueBase) != Qtrue)
      {
        // autowrap valuebox values
        rval = r2tao_wrap_Valuebox (rval, _tc);
      }
    }
    // fall through
    case CORBA::tk_value:
    case CORBA::tk_event:
    {
      if (!NIL_P (rval))
      {
        R2TAO_Value_ptr r2tval = nullptr;
        ACE_NEW_NORETURN (r2tval,
                          R2TAO_Value (rval));
        _any <<= &r2tval;
      }
      else
      {
        TAO::Any_Impl_T<R2TAO_Value>::insert (
            _any,
            R2TAO_Value::_tao_any_destructor,
            _tc,
            0);
      }
      return;
    }
    default:
      break;
  }

  ACE_ERROR ((LM_ERROR, "R2TAO::Unable to convert Ruby data (kind = %d) to TAO\n", _tc->kind ()));
  throw ::CORBA::NO_IMPLEMENT (0, CORBA::COMPLETED_NO);
}

R2TAO_EXPORT void r2tao_Ruby_to_Any(CORBA::Any& _any, VALUE val)
{
  if (!NIL_P (val))
  {
    VALUE rvaltc = rb_funcall (r2tao_cAny, typecode_for_value_ID, 1, val);
    if (NIL_P (rvaltc))
    {
      ACE_ERROR ((LM_ERROR, "R2TAO::invalid datatype for CORBA::Any\n"));

      throw ::CORBA::MARSHAL (0, ::CORBA::COMPLETED_NO);
    }

    CORBA::TypeCode_ptr atc = r2corba_TypeCode_r2t (rvaltc);
    r2tao_Ruby2Any (_any,
                    atc,
                    rb_funcall (r2tao_cAny, value_for_any_ID, 1, val));
  }
}

// need this here since TAO does not export this specialization
TAO_BEGIN_VERSIONED_NAMESPACE_DECL

namespace TAO
{
  template<>
  CORBA::Boolean
  Any_Impl_T<CORBA::Object>::to_object (CORBA::Object_ptr &_tao_elem) const
  {
    _tao_elem = CORBA::Object::_duplicate (this->value_);
    return true;
  }
}

TAO_END_VERSIONED_NAMESPACE_DECL

/*===================================================================
 *  Data Conversion CORBA Any --> Ruby VALUE
 *
 */
#define R2TAO_TCTYPE(rtc) \
  rb_funcall ((rtc), get_type_ID, 0)

#define R2TAO_NEW_TCOBJECT(rtc) \
  rb_class_new_instance (0, 0, rb_funcall ((rtc), get_type_ID, 0))

VALUE r2tao_Struct2Ruby (const CORBA::Any& _any, CORBA::TypeCode_ptr _tc, VALUE rtc, VALUE roottc)
{
  if (TAO_debug_level > 9)
    ACE_DEBUG ((LM_INFO, "R2TAO (%P|%t) - Struct2Ruby:: tc=%@, id=%C\n", _tc, _tc->id ()));

  DynamicAny::DynAny_var da = r2tao_CreateDynAny (_any);
  DynamicAny::DynStruct_var das = DynamicAny::DynStruct::_narrow (da.in ());

  VALUE new_rs = R2TAO_NEW_TCOBJECT (roottc);

  CORBA::ULong mcount = _tc->member_count ();

  DynamicAny::NameValuePairSeq_var nvps = das->get_members ();

  for (CORBA::ULong m=0; m<mcount ;++m)
  {
    CORBA::TypeCode_var mtc = _tc->member_type (m);
    VALUE mrtc = rb_funcall (rtc, member_type_ID, 1, ULONG2NUM(m));
    VALUE rmval = r2tao_Any2Ruby (nvps[m].value, mtc.in (), mrtc, mrtc);
    const char* name = _tc->member_name (m);
    CORBA::String_var mname = CORBA::string_alloc (2 + ACE_OS::strlen (name));
    ACE_OS::sprintf ((char*)mname.in (), "@%s", name);
    rb_iv_set (new_rs, mname.in (), rmval);
  }

  das->destroy ();

  return new_rs;
}

VALUE r2tao_Union2Ruby (const CORBA::Any& _any, CORBA::TypeCode_ptr _tc, VALUE rtc, VALUE roottc)
{
  if (TAO_debug_level > 9)
    ACE_DEBUG ((LM_INFO, "R2TAO (%P|%t) - Union2Ruby:: tc=%@, id=%C\n", _tc, _tc->id ()));

  VALUE new_ru = R2TAO_NEW_TCOBJECT (roottc);

  DynamicAny::DynAny_var da = r2tao_CreateDynAny (_any);
  DynamicAny::DynUnion_var dau = DynamicAny::DynUnion::_narrow (da.in ());

  static ID _value_tc_ID = rb_intern("_value_tc");
  static ID discriminator_type_ID = rb_intern ("discriminator_type");
  static VALUE r2tao_sym_default = rb_eval_string(":default");

  DynamicAny::DynAny_var dyndisc = dau->get_discriminator ();
  CORBA::Any_var anydisc = dyndisc->to_any ();
  CORBA::Octet defval;
  VALUE rdisc;
  if ((anydisc >>= CORBA::Any::to_octet (defval)) == 1 && defval == 0)
  {
    rdisc = r2tao_sym_default;
  }
  else
  {
    CORBA::TypeCode_var dtc = _tc->discriminator_type ();
    VALUE rdisctype = rb_funcall (rtc, discriminator_type_ID, 0);
    rdisc = r2tao_Any2Ruby (*anydisc, dtc.in (), rdisctype, rdisctype);
  }
  rb_iv_set (new_ru, "@discriminator", rdisc);

  if (!dau->has_no_active_member ())
  {
    DynamicAny::DynAny_var dynval = dau->member ();
    CORBA::Any_var anyval = dynval->to_any ();
    VALUE rvaltc = rb_funcall (new_ru, _value_tc_ID, 0);
    CORBA::TypeCode_ptr valtc = r2corba_TypeCode_r2t (rvaltc);
    VALUE rvalue = r2tao_Any2Ruby (*anyval, valtc, rvaltc, rvaltc);
    rb_iv_set (new_ru, "@value", rvalue);
  }

  dau->destroy ();

  return new_ru;
}

VALUE r2tao_Sequence2Ruby(const CORBA::Any& _any, CORBA::TypeCode_ptr _tc, VALUE rtc, VALUE roottc)
{
  CORBA::TypeCode_var ctc = _tc->content_type();

  if (TAO_debug_level > 9)
    ACE_DEBUG ((LM_INFO, "R2TAO (%P|%t) - Sequence2Ruby:: tc=%@, content_type.kind=%d\n", _tc, ctc->kind ()));

  VALUE rtcklass = R2TAO_TCTYPE(roottc);

  switch (ctc->kind ())
  {
    case CORBA::tk_short:
    {
      const CORBA::ShortSeq* tmp;
      if (TAO::Any_Dual_Impl_T<CORBA::ShortSeq>::extract (
            _any,
            CORBA::ShortSeq::_tao_any_destructor,
            _tc,
            tmp))
      {
        VALUE ret = (rtcklass == rb_cArray) ?
              rb_ary_new2 ((long)tmp->length ()) :
              rb_class_new_instance (0, 0, rtcklass);
        for (CORBA::ULong l=0; l<tmp->length () ;++l)
        {
          rb_ary_push (ret, INT2FIX ((int)(*tmp)[l]));
        }
        return ret;
      }
      break;
    }
    case CORBA::tk_long:
    {
      const CORBA::LongSeq* tmp;
      if (TAO::Any_Dual_Impl_T<CORBA::LongSeq>::extract (
            _any,
            CORBA::LongSeq::_tao_any_destructor,
            _tc,
            tmp))
      {
        VALUE ret = (rtcklass == rb_cArray) ?
              rb_ary_new2 ((long)tmp->length ()) :
              rb_class_new_instance (0, 0, rtcklass);
        for (CORBA::ULong l=0; l<tmp->length () ;++l)
        {
          rb_ary_push (ret, INT2FIX ((long)(*tmp)[l]));
        }
        return ret;
      }
      break;
    }
    case CORBA::tk_ushort:
    {
      const CORBA::UShortSeq* tmp;
      if (TAO::Any_Dual_Impl_T<CORBA::UShortSeq>::extract (
            _any,
            CORBA::UShortSeq::_tao_any_destructor,
            _tc,
            tmp))
      {
        VALUE ret = (rtcklass == rb_cArray) ?
              rb_ary_new2 ((long)tmp->length ()) :
              rb_class_new_instance (0, 0, rtcklass);
        for (CORBA::ULong l=0; l<tmp->length () ;++l)
        {
          rb_ary_push (ret, INT2FIX ((int)(*tmp)[l]));
        }
        return ret;
      }
      break;
    }
    case CORBA::tk_ulong:
    {
      const CORBA::ULongSeq* tmp;
      if (TAO::Any_Dual_Impl_T<CORBA::ULongSeq>::extract (
            _any,
            CORBA::ULongSeq::_tao_any_destructor,
            _tc,
            tmp))
      {
        VALUE ret = (rtcklass == rb_cArray) ?
              rb_ary_new2 ((long)tmp->length ()) :
              rb_class_new_instance (0, 0, rtcklass);
        for (CORBA::ULong l=0; l<tmp->length () ;++l)
        {
          rb_ary_push (ret, ULONG2NUM ((unsigned long)(*tmp)[l]));
        }
        return ret;
      }
      break;
    }
    case CORBA::tk_longlong:
    {
      const CORBA::LongLongSeq* tmp;
      if (TAO::Any_Dual_Impl_T<CORBA::LongLongSeq>::extract (
            _any,
            CORBA::LongLongSeq::_tao_any_destructor,
            _tc,
            tmp))
      {
        VALUE ret = (rtcklass == rb_cArray) ?
              rb_ary_new2 ((long)tmp->length ()) :
              rb_class_new_instance (0, 0, rtcklass);
        for (CORBA::ULong l=0; l<tmp->length () ;++l)
        {
          rb_ary_push (ret, LL2NUM ((*tmp)[l]));
        }
        return ret;
      }
      break;
    }
    case CORBA::tk_ulonglong:
    {
      const CORBA::ULongLongSeq* tmp;
      if (TAO::Any_Dual_Impl_T<CORBA::ULongLongSeq>::extract (
            _any,
            CORBA::ULongLongSeq::_tao_any_destructor,
            _tc,
            tmp))
      {
        VALUE ret = (rtcklass == rb_cArray) ?
              rb_ary_new2 ((long)tmp->length ()) :
              rb_class_new_instance (0, 0, rtcklass);
        for (CORBA::ULong l=0; l<tmp->length () ;++l)
        {
          rb_ary_push (ret, ULL2NUM ((*tmp)[l]));
        }
        return ret;
      }
      break;
    }
    case CORBA::tk_float:
    {
      const CORBA::FloatSeq* tmp;
      if (TAO::Any_Dual_Impl_T<CORBA::FloatSeq>::extract (
            _any,
            CORBA::FloatSeq::_tao_any_destructor,
            _tc,
            tmp))
      {
        VALUE ret = (rtcklass == rb_cArray) ?
              rb_ary_new2 ((long)tmp->length ()) :
              rb_class_new_instance (0, 0, rtcklass);
        for (CORBA::ULong l=0; l<tmp->length () ;++l)
        {
          rb_ary_push (ret, rb_float_new ((CORBA::Double)(*tmp)[l]));
        }
        return ret;
      }
      break;
    }
    case CORBA::tk_double:
    {
      const CORBA::DoubleSeq* tmp;
      if (TAO::Any_Dual_Impl_T<CORBA::DoubleSeq>::extract (
            _any,
            CORBA::DoubleSeq::_tao_any_destructor,
            _tc,
            tmp))
      {
        VALUE ret = (rtcklass == rb_cArray) ?
              rb_ary_new2 ((long)tmp->length ()) :
              rb_class_new_instance (0, 0, rtcklass);
        for (CORBA::ULong l=0; l<tmp->length () ;++l)
        {
          rb_ary_push (ret, rb_float_new ((*tmp)[l]));
        }
        return ret;
      }
      break;
    }
    case CORBA::tk_longdouble:
    {
      const CORBA::LongDoubleSeq* tmp;
      if (TAO::Any_Dual_Impl_T<CORBA::LongDoubleSeq>::extract (
            _any,
            CORBA::DoubleSeq::_tao_any_destructor,
            _tc,
            tmp))
      {
        VALUE ret = (rtcklass == rb_cArray) ?
              rb_ary_new2 ((long)tmp->length ()) :
              rb_class_new_instance (0, 0, rtcklass);
        for (CORBA::ULong l=0; l<tmp->length () ;++l)
        {
          rb_ary_push (ret, CLD2RLD ((*tmp)[l]));
        }
        return ret;
      }
      break;
    }
    case CORBA::tk_boolean:
    {
      const CORBA::BooleanSeq* tmp;
      if (TAO::Any_Dual_Impl_T<CORBA::BooleanSeq>::extract (
            _any,
            CORBA::BooleanSeq::_tao_any_destructor,
            _tc,
            tmp))
      {
        VALUE ret = (rtcklass == rb_cArray) ?
              rb_ary_new2 ((long)tmp->length ()) :
              rb_class_new_instance (0, 0, rtcklass);
        for (CORBA::ULong l=0; l<tmp->length () ;++l)
        {
          rb_ary_push (ret, ((*tmp)[l] ? Qtrue : Qfalse));
        }
        return ret;
      }
      break;
    }
    case CORBA::tk_char:
    {
      const CORBA::CharSeq* tmp;
      if (TAO::Any_Dual_Impl_T<CORBA::CharSeq>::extract (
            _any,
            CORBA::CharSeq::_tao_any_destructor,
            _tc,
            tmp))
      {
        return rb_str_new ((char*)tmp->get_buffer (), (long)tmp->length ());
      }
      break;
    }
    case CORBA::tk_octet:
    {
      const CORBA::OctetSeq* tmp;
      if (TAO::Any_Dual_Impl_T<CORBA::OctetSeq>::extract (
            _any,
            CORBA::OctetSeq::_tao_any_destructor,
            _tc,
            tmp))
      {
        return rb_str_new ((char*)tmp->get_buffer (), (long)tmp->length ());
      }
      break;
    }
    case CORBA::tk_wchar:
    {
      const CORBA::WCharSeq* tmp;
      if (TAO::Any_Dual_Impl_T<CORBA::WCharSeq>::extract (
            _any,
            CORBA::WCharSeq::_tao_any_destructor,
            _tc,
            tmp))
      {
        VALUE ret = (rtcklass == rb_cArray) ?
              rb_ary_new2 ((long)tmp->length ()) :
              rb_class_new_instance (0, 0, rtcklass);
        for (CORBA::ULong l=0; l<tmp->length () ;++l)
        {
          rb_ary_push (ret, INT2FIX ((int)(*tmp)[l]));
        }
        return ret;
      }
      break;
    }
    default:
    {
      static ID is_recursive_tc_ID = rb_intern ("is_recursive_tc?");
      static ID recursed_tc_ID = rb_intern ("recursed_tc");

      DynamicAny::DynAny_var da = r2tao_CreateDynAny (_any);
      DynamicAny::DynSequence_var das = DynamicAny::DynSequence::_narrow (da.in ());

      DynamicAny::AnySeq_var elems = das->get_elements ();
      CORBA::ULong seqlen = elems->length ();

      VALUE ret = (rtcklass == rb_cArray) ?
            rb_ary_new2 ((long)seqlen) :
            rb_class_new_instance (0, 0, rtcklass);

      VALUE ertc = rb_funcall (rtc, content_type_ID, 0);
      VALUE is_recursive_tc = rb_funcall (ertc, is_recursive_tc_ID, 0);
      if (is_recursive_tc == Qtrue)
      {
        ertc = rb_funcall (ertc, recursed_tc_ID, 0);
      }

      for (CORBA::ULong l=0; l<seqlen ;++l)
      {
        VALUE rval = r2tao_Any2Ruby (elems[l], ctc.in (), ertc, ertc);
        rb_ary_push (ret, rval);
      }

      das->destroy ();
      return ret;
    }
  }

  ACE_ERROR ((LM_ERROR, "R2TAO::Cannot convert TAO sequence to Ruby\n"));
  throw ::CORBA::NO_IMPLEMENT (0, CORBA::COMPLETED_NO);

  return Qnil;
}

/*
 * Data conversion CORBA Any --> Ruby VALUE
 * Arguments:
 *  const CORBA::Any& _any    : Any value to convert
 *  CORBA::TypeCode_ptr _tc   : CORBA::TypeCode of Any value
 *  VALUE rtc                 : nil or Ruby R2CORBA::CORBA::TypeCode corresponding to _tc
 *                                if nil -> will be derived from _tc
 *  VALUE roottc              : nil or original Ruby R2CORBA::CORBA::TypeCode corresponding to Any value
 *                                if nil -> roottc = rtc
 * Returns:
 *  VALUE                     : Ruby VALUE
 */
R2TAO_EXPORT VALUE r2tao_Any2Ruby(const CORBA::Any& _any, CORBA::TypeCode_ptr _tc, VALUE rtc, VALUE roottc)
{
  if (TAO_debug_level > 9)
    ACE_DEBUG ((LM_INFO, "R2TAO (%P|%t) - r2tao_Any2Ruby: entry - tc=%@\n", _tc));

  switch (_tc->kind ())
  {
    case CORBA::tk_null:
    case CORBA::tk_void:
      return Qnil;
    case CORBA::tk_alias:
    {
      if (NIL_P (rtc))
        rtc = r2corba_TypeCode_t2r (_tc);
      VALUE rctc = rb_funcall (rtc, content_type_ID, 0);
      CORBA::TypeCode_var ctc = _tc->content_type ();
      return r2tao_Any2Ruby(_any, ctc.in (), rctc, NIL_P (roottc) ? rtc : roottc);
    }
    case CORBA::tk_short:
    {
      CORBA::Short val;
      _any >>= val;
      return INT2FIX ((int)val);
    }
    case CORBA::tk_long:
    {
      CORBA::Long val;
      _any >>= val;
      return LONG2NUM (val);
    }
    case CORBA::tk_ushort:
    {
      CORBA::UShort val;
      _any >>= val;
      return UINT2NUM ((unsigned int)val);
    }
    case CORBA::tk_ulong:
    {
      CORBA::ULong val;
      _any >>= val;
      return ULONG2NUM (val);
    }
    case CORBA::tk_longlong:
    {
      CORBA::LongLong val;
      _any >>= val;
      return LL2NUM (val);
    }
    case CORBA::tk_ulonglong:
    {
      CORBA::ULongLong val;
      _any >>= val;
      return ULL2NUM (val);
    }
    case CORBA::tk_float:
    {
      CORBA::Float val;
      _any >>= val;
      return rb_float_new ((double)val);
    }
    case CORBA::tk_double:
    {
      CORBA::Double val;
      _any >>= val;
      return rb_float_new ((double)val);
    }
    case CORBA::tk_longdouble:
    {
      CORBA::LongDouble val;
      _any >>= val;
      return CLD2RLD (val);
    }
    case CORBA::tk_boolean:
    {
      CORBA::Boolean val;
      _any >>= CORBA::Any::to_boolean (val);
      return (val ? Qtrue : Qfalse);
    }
    case CORBA::tk_char:
    {
      CORBA::Char val;
      _any >>= CORBA::Any::to_char (val);
      return rb_str_new (&val, 1);
    }
    case CORBA::tk_octet:
    {
      CORBA::Octet val;
      _any >>= CORBA::Any::to_octet (val);
      return INT2FIX ((int)val);
    }
    case CORBA::tk_wchar:
    {
      CORBA::WChar val;
      _any >>= CORBA::Any::to_wchar (val);
      return INT2FIX ((int)val);
    }
    case CORBA::tk_string:
    {
      if (_tc->length ()>0)
      {
        char *tmp;
        _any >>= CORBA::Any::to_string (tmp, _tc->length ());
        return rb_str_new (tmp, (long)_tc->length ());
      }
      else
      {
        const char *tmp;
        _any >>= tmp;
        return tmp ? rb_str_new2 (tmp) : Qnil;
      }
    }
    case CORBA::tk_wstring:
    {
      if (NIL_P (roottc))
      {
        if (NIL_P (rtc))
          rtc = r2corba_TypeCode_t2r (_tc);
        roottc = rtc;
      }
      VALUE rtcklass = R2TAO_TCTYPE(roottc);
      if (_tc->length ()>0)
      {
        CORBA::WChar *tmp;
        _any >>= CORBA::Any::to_wstring (tmp, _tc->length ());
        VALUE ret = (rtcklass == rb_cArray) ?
              rb_ary_new2 ((long)_tc->length ()) :
              rb_class_new_instance (0, 0, rtcklass);
        for (CORBA::ULong l=0; l<_tc->length () ;++l)
          rb_ary_push (ret, INT2FIX (tmp[l]));
        return ret;
      }
      else
      {
        const CORBA::WChar *tmp;
        _any >>= tmp;
        if (tmp == 0)
          return Qnil;

        VALUE ret = rb_class_new_instance (0, 0, rtcklass);
        for (CORBA::ULong l=0; tmp[l] != CORBA::WChar(0) ;++l)
          rb_ary_push (ret, INT2FIX (tmp[l]));
        return ret;
      }
    }
    case CORBA::tk_enum:
    {
      DynamicAny::DynAny_var da = r2tao_CreateDynAny (_any);
      DynamicAny::DynEnum_var das = DynamicAny::DynEnum::_narrow (da.in ());

      VALUE ret = ULL2NUM (das->get_as_ulong ());

      das->destroy ();
      return ret;
    }
    case CORBA::tk_array:
    {
      DynamicAny::DynAny_var da = r2tao_CreateDynAny (_any);
      DynamicAny::DynArray_var das = DynamicAny::DynArray::_narrow (da.in ());

      DynamicAny::AnySeq_var elems = das->get_elements ();
      CORBA::ULong arrlen = elems->length ();

      if (NIL_P (roottc))
      {
        if (NIL_P (rtc))
          rtc = r2corba_TypeCode_t2r (_tc);
        roottc = rtc;
      }
      VALUE rtcklass = R2TAO_TCTYPE(roottc);
      VALUE ret = (rtcklass == rb_cArray) ?
            rb_ary_new2 ((long)arrlen) :
            rb_class_new_instance (0, 0, rtcklass);

      CORBA::TypeCode_var etc = _tc->content_type ();
      VALUE ertc = rb_funcall (rtc, content_type_ID, 0);

      for (CORBA::ULong l=0; l<arrlen ;++l)
      {
        VALUE rval = r2tao_Any2Ruby (elems[l], etc.in (), ertc, ertc);
        rb_ary_push (ret, rval);
      }

      das->destroy ();
      return ret;
    }
    case CORBA::tk_sequence:
    {
      if (NIL_P (roottc))
      {
        if (NIL_P (rtc))
          rtc = r2corba_TypeCode_t2r (_tc);
        roottc = rtc;
      }
      return r2tao_Sequence2Ruby (_any, _tc, rtc, roottc);
    }
    case CORBA::tk_except:
    case CORBA::tk_struct:
    {
      if (NIL_P (roottc))
      {
        if (NIL_P (rtc))
          rtc = r2corba_TypeCode_t2r (_tc);
        roottc = rtc;
      }
      return r2tao_Struct2Ruby (_any, _tc, rtc, roottc);
    }
    case CORBA::tk_union:
    {
      if (NIL_P (roottc))
      {
        if (NIL_P (rtc))
          rtc = r2corba_TypeCode_t2r (_tc);
        roottc = rtc;
      }
      return r2tao_Union2Ruby (_any, _tc, rtc, roottc);
    }
    case CORBA::tk_objref:
    {
      CORBA::Object_var val;
      _any >>= CORBA::Any::to_object (val.out ());
      if (CORBA::is_nil (val))
        return Qnil;

      if (NIL_P (roottc))
      {
        if (NIL_P (rtc))
          rtc = r2corba_TypeCode_t2r (_tc);
        roottc = rtc;
      }
      VALUE robj = r2corba_Object_t2r(val.in ());
      VALUE obj_type = R2TAO_TCTYPE(roottc);
      VALUE ret = rb_funcall (obj_type, _narrow_ID, 1, robj);
      return ret;
    }
    case CORBA::tk_abstract_interface:
    {
      CORBA::AbstractBase_ptr abs = nullptr;
      TAO::Any_Impl_T<CORBA::AbstractBase>::extract (
          _any,
          CORBA::AbstractBase::_tao_any_destructor,
          _tc,
          abs);
      if (CORBA::is_nil (abs))
        return Qnil;

      if (abs->_is_objref ())
      {
        if (NIL_P (roottc))
        {
          if (NIL_P (rtc))
            rtc = r2corba_TypeCode_t2r (_tc);
          roottc = rtc;
        }

        CORBA::Object_var val = abs->_to_object ();
        if (CORBA::is_nil (val))
          return Qnil;
        VALUE robj = r2corba_Object_t2r(val.in ());
        VALUE obj_type = R2TAO_TCTYPE(roottc);
        VALUE ret = rb_funcall (obj_type, _narrow_ID, 1, robj);
        return ret;
      }
      else
      {
        CORBA::ValueBase_var val = abs->_to_value ();
        return R2TAO_Value::_downcast (val.in ())->get_ruby_value ();
      }
    }
    case CORBA::tk_any:
    {
      const CORBA::Any *_anyval;
      _any >>= _anyval;
      CORBA::TypeCode_var atc = _anyval->type ();
      return r2tao_Any2Ruby (*_anyval, atc.in (), Qnil, Qnil);
    }
    case CORBA::tk_TypeCode:
    {
      CORBA::TypeCode_var _tcval;
      _any >>= _tcval.out ();

      return r2corba_TypeCode_t2r (_tcval.in ());
    }
    case CORBA::tk_Principal:
    {
      break;
    }
    case CORBA::tk_value_box:
    case CORBA::tk_value:
    case CORBA::tk_event:
    {
      R2TAO_Value_ptr r2tval = nullptr;
      TAO::Any_Impl_T<R2TAO_Value>::extract (
          _any,
          R2TAO_Value::_tao_any_destructor,
          _tc,
          r2tval);
      if (r2tval == 0)
        return Qnil;
      else
      {
        VALUE rval = r2tval->get_ruby_value ();
        if (_tc->kind () == CORBA::tk_value_box)
        {
          // auto-unwrap valuebox
          rval = rb_funcall (rval, value_ID, 0);
        }
        return rval;
      }
    }
    default:
      break;
  }

  ACE_ERROR ((LM_ERROR, "R2TAO::Cannot convert TAO data to Ruby\n"));
  throw ::CORBA::NO_IMPLEMENT (0, CORBA::COMPLETED_NO);

  return Qnil;
}

R2TAO_EXPORT VALUE r2tao_Any_to_Ruby(const CORBA::Any& _any)
{
  static R2TAO_RBFuncall FN_to_any ("to_any", false);

  VALUE rval = r2tao_Any2Ruby (_any, _any._tao_get_typecode (), Qnil, Qnil);
  if (!NIL_P (rval))
  {
    rval = FN_to_any.invoke (r2tao_cAny, 1, &rval);
    if (FN_to_any.has_caught_exception ())
    {
      rb_eval_string ("STDERR.puts $!.to_s+\"\\n\"+$!.backtrace.join(\"\\n\")");
      throw ::CORBA::MARSHAL (0, ::CORBA::COMPLETED_NO);
    }
  }
  return rval;
}


R2TAO_EXPORT void r2tao_Any4Value(CORBA::Any& _any, CORBA::TypeCode_ptr _tc)
{
  if (TAO_debug_level > 9)
    ACE_DEBUG ((LM_INFO, "R2TAO (%P|%t) - r2tao_Any4Value:: "
                         "initialising any for value %C\n",
                         _tc->id ()));

  CORBA::ValueFactory factory =
      TAO_ORB_Core_instance ()->orb ()->lookup_value_factory (
          _tc->id ());
  if (factory)
  {
    CORBA::ValueBase * vb = factory->create_for_unmarshal ();
    R2TAO_Value_ptr r2tval = R2TAO_Value::_downcast (vb);

    TAO::Any_Impl * vimpl = nullptr;
    ACE_NEW_THROW_EX (vimpl,
                   TAO::Any_Impl_T<R2TAO_Value> (R2TAO_Value::_tao_any_destructor,
                                                 _tc,
                                                 r2tval),
                   CORBA::NO_MEMORY());
    _any.replace (vimpl);

    factory->_remove_ref (); // we're done with this
  }
  else
  {
    throw CORBA::BAD_PARAM();
  }
}

