/*--------------------------------------------------------------------
# values.cpp - R2TAO CORBA Valuetype support
#
# Author: Martin Corino
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the R2CORBA LICENSE which is
# included with this program.
#
# Copyright (c) Remedy IT Expertise BV
# Chamber of commerce Rotterdam nr.276339, The Netherlands
#------------------------------------------------------------------*/

#include "required.h"
#include "exception.h"
#include "object.h"
#include "typecode.h"
#include "longdouble.h"
#include "values.h"
#include "tao/CDR.h"
#include "tao/ORB_Core.h"
#include "tao/DynamicAny/DynamicAny.h"

#define RUBY_INVOKE_FUNC RUBY_ALLOC_FUNC

static ID ci_ivar_ID;
static ID val_ivar_ID;

static VALUE r2tao_nsValueBase;
static VALUE r2tao_nsInputStream;
static VALUE r2tao_nsOutputStream;
static VALUE r2tao_cInputStream;
static VALUE r2tao_cOutputStream;

VALUE r2tao_cValueFactoryBase = 0;
VALUE r2tao_cBoxedValueBase = 0;

// Ruby ValueBase methods
VALUE r2tao_Value_pre_marshal(VALUE self, VALUE strm);
VALUE r2tao_Value_post_marshal(VALUE self, VALUE strm);
VALUE r2tao_Value_pre_unmarshal(VALUE self, VALUE strm);
VALUE r2tao_Value_post_unmarshal(VALUE self, VALUE strm);

// Ruby Stream methods
static VALUE r2tao_InputStream_t2r(TAO_InputCDR* strm);
static VALUE r2tao_OutputStream_t2r(R2TAO_Value* val);
static TAO_InputCDR* r2tao_InputStream_r2t(VALUE strm);
static R2TAO_Value* r2tao_OutputStream_r2t(VALUE strm);

VALUE r2tao_OStream_write_any (VALUE self, VALUE rval);
VALUE r2tao_OStream_write_boolean (VALUE self, VALUE rval);
VALUE r2tao_OStream_write_char (VALUE self, VALUE rval);
VALUE r2tao_OStream_write_wchar (VALUE self, VALUE rval);
VALUE r2tao_OStream_write_octet (VALUE self, VALUE rval);
VALUE r2tao_OStream_write_short (VALUE self, VALUE rval);
VALUE r2tao_OStream_write_ushort (VALUE self, VALUE rval);
VALUE r2tao_OStream_write_long (VALUE self, VALUE rval);
VALUE r2tao_OStream_write_ulong (VALUE self, VALUE rval);
VALUE r2tao_OStream_write_longlong (VALUE self, VALUE rval);
VALUE r2tao_OStream_write_ulonglong (VALUE self, VALUE rval);
VALUE r2tao_OStream_write_float (VALUE self, VALUE rval);
VALUE r2tao_OStream_write_double (VALUE self, VALUE rval);
VALUE r2tao_OStream_write_longdouble (VALUE self, VALUE rval);
VALUE r2tao_OStream_write_Object (VALUE self, VALUE rval);
VALUE r2tao_OStream_write_Abstract (VALUE self, VALUE rval);
VALUE r2tao_OStream_write_Value (VALUE self, VALUE rval);
VALUE r2tao_OStream_write_TypeCode (VALUE self, VALUE rval);
VALUE r2tao_OStream_write_fixed (VALUE self, VALUE rval);

VALUE r2tao_OStream_write_string (VALUE self, VALUE rval);
VALUE r2tao_OStream_write_wstring (VALUE self, VALUE rval);

VALUE r2tao_OStream_write_any_array (VALUE self, VALUE rval, VALUE offset, VALUE length);
VALUE r2tao_OStream_write_boolean_array (VALUE self, VALUE rval, VALUE offset, VALUE length);
VALUE r2tao_OStream_write_char_array (VALUE self, VALUE rval, VALUE offset, VALUE length);
VALUE r2tao_OStream_write_wchar_array (VALUE self, VALUE rval, VALUE offset, VALUE length);
VALUE r2tao_OStream_write_octet_array (VALUE self, VALUE rval, VALUE offset, VALUE length);
VALUE r2tao_OStream_write_short_array (VALUE self, VALUE rval, VALUE offset, VALUE length);
VALUE r2tao_OStream_write_ushort_array (VALUE self, VALUE rval, VALUE offset, VALUE length);
VALUE r2tao_OStream_write_long_array (VALUE self, VALUE rval, VALUE offset, VALUE length);
VALUE r2tao_OStream_write_ulong_array (VALUE self, VALUE rval, VALUE offset, VALUE length);
VALUE r2tao_OStream_write_longlong_array (VALUE self, VALUE rval, VALUE offset, VALUE length);
VALUE r2tao_OStream_write_ulonglong_array (VALUE self, VALUE rval, VALUE offset, VALUE length);
VALUE r2tao_OStream_write_float_array (VALUE self, VALUE rval, VALUE offset, VALUE length);
VALUE r2tao_OStream_write_double_array (VALUE self, VALUE rval, VALUE offset, VALUE length);
VALUE r2tao_OStream_write_longdouble_array (VALUE self, VALUE rval, VALUE offset, VALUE length);
VALUE r2tao_OStream_write_fixed_array (VALUE self, VALUE rval, VALUE offset, VALUE length);

VALUE r2tao_OStream_write_construct (VALUE self, VALUE rval, VALUE rtc);

VALUE r2tao_IStream_read_any (VALUE self);
VALUE r2tao_IStream_read_boolean (VALUE self);
VALUE r2tao_IStream_read_char (VALUE self);
VALUE r2tao_IStream_read_wchar (VALUE self);
VALUE r2tao_IStream_read_octet (VALUE self);
VALUE r2tao_IStream_read_short (VALUE self);
VALUE r2tao_IStream_read_ushort (VALUE self);
VALUE r2tao_IStream_read_long (VALUE self);
VALUE r2tao_IStream_read_ulong (VALUE self);
VALUE r2tao_IStream_read_longlong (VALUE self);
VALUE r2tao_IStream_read_ulonglong (VALUE self);
VALUE r2tao_IStream_read_float (VALUE self);
VALUE r2tao_IStream_read_double (VALUE self);
VALUE r2tao_IStream_read_longdouble (VALUE self);
VALUE r2tao_IStream_read_Object (VALUE self);
VALUE r2tao_IStream_read_Abstract (VALUE self);
VALUE r2tao_IStream_read_Value (VALUE self);
VALUE r2tao_IStream_read_TypeCode (VALUE self);
VALUE r2tao_IStream_read_fixed (VALUE self);

VALUE r2tao_IStream_read_string (VALUE self);
VALUE r2tao_IStream_read_wstring (VALUE self);

VALUE r2tao_IStream_read_any_array (VALUE self, VALUE rval, VALUE offset, VALUE length);
VALUE r2tao_IStream_read_boolean_array (VALUE self, VALUE rval, VALUE offset, VALUE length);
VALUE r2tao_IStream_read_char_array (VALUE self, VALUE rval, VALUE offset, VALUE length);
VALUE r2tao_IStream_read_wchar_array (VALUE self, VALUE rval, VALUE offset, VALUE length);
VALUE r2tao_IStream_read_octet_array (VALUE self, VALUE rval, VALUE offset, VALUE length);
VALUE r2tao_IStream_read_short_array (VALUE self, VALUE rval, VALUE offset, VALUE length);
VALUE r2tao_IStream_read_ushort_array (VALUE self, VALUE rval, VALUE offset, VALUE length);
VALUE r2tao_IStream_read_long_array (VALUE self, VALUE rval, VALUE offset, VALUE length);
VALUE r2tao_IStream_read_ulong_array (VALUE self, VALUE rval, VALUE offset, VALUE length);
VALUE r2tao_IStream_read_longlong_array (VALUE self, VALUE rval, VALUE offset, VALUE length);
VALUE r2tao_IStream_read_ulonglong_array (VALUE self, VALUE rval, VALUE offset, VALUE length);
VALUE r2tao_IStream_read_float_array (VALUE self, VALUE rval, VALUE offset, VALUE length);
VALUE r2tao_IStream_read_double_array (VALUE self, VALUE rval, VALUE offset, VALUE length);
VALUE r2tao_IStream_read_longdouble_array (VALUE self, VALUE rval, VALUE offset, VALUE length);
VALUE r2tao_IStream_read_fixed_array (VALUE self, VALUE rval, VALUE offset, VALUE length);

VALUE r2tao_IStream_read_construct (VALUE self, VALUE rtc);

VALUE r2tao_VFB_register_value_factory(VALUE self, VALUE id, VALUE rfact);
VALUE r2tao_VFB_unregister_value_factory(VALUE self, VALUE id);
VALUE r2tao_VFB_lookup_value_factory(VALUE self, VALUE id);

void r2tao_init_Values()
{
  VALUE k;

  ci_ivar_ID = rb_intern ("@__ci_holder_");
  val_ivar_ID = rb_intern ("@__native_value_");

  /*
   * Define Portable stream modules
   */
  k = rb_eval_string ("R2CORBA::CORBA::Portable");
  r2tao_nsInputStream = rb_define_module_under(k, "InputStream");
  r2tao_nsOutputStream = rb_define_module_under(k, "OutputStream");

  /*
   * Define single instance writers
   */
#define R2TAO_DEFMETHOD(type) \
  rb_define_method (r2tao_nsOutputStream, "write_" #type, RUBY_METHOD_FUNC (r2tao_OStream_write_ ## type), 1)

  R2TAO_DEFMETHOD (any);
  R2TAO_DEFMETHOD (boolean);
  R2TAO_DEFMETHOD (char);
  R2TAO_DEFMETHOD (wchar);
  R2TAO_DEFMETHOD (octet);
  R2TAO_DEFMETHOD (short);
  R2TAO_DEFMETHOD (ushort);
  R2TAO_DEFMETHOD (long);
  R2TAO_DEFMETHOD (ulong);
  R2TAO_DEFMETHOD (longlong);
  R2TAO_DEFMETHOD (ulonglong);
  R2TAO_DEFMETHOD (float);
  R2TAO_DEFMETHOD (double);
  R2TAO_DEFMETHOD (longdouble);
  R2TAO_DEFMETHOD (Object);
  R2TAO_DEFMETHOD (Abstract);
  R2TAO_DEFMETHOD (Value);
  R2TAO_DEFMETHOD (TypeCode);
  R2TAO_DEFMETHOD (fixed);
  R2TAO_DEFMETHOD (string);
  R2TAO_DEFMETHOD (wstring);

  /*
   * Define array writers
   */
#undef R2TAO_DEFMETHOD
#define R2TAO_DEFMETHOD(type) \
  rb_define_method (r2tao_nsOutputStream, "write_" #type "_array", RUBY_METHOD_FUNC (r2tao_OStream_write_ ## type ## _array), 3)

  R2TAO_DEFMETHOD (any);
  R2TAO_DEFMETHOD (boolean);
  R2TAO_DEFMETHOD (char);
  R2TAO_DEFMETHOD (wchar);
  R2TAO_DEFMETHOD (octet);
  R2TAO_DEFMETHOD (short);
  R2TAO_DEFMETHOD (ushort);
  R2TAO_DEFMETHOD (long);
  R2TAO_DEFMETHOD (ulong);
  R2TAO_DEFMETHOD (longlong);
  R2TAO_DEFMETHOD (ulonglong);
  R2TAO_DEFMETHOD (float);
  R2TAO_DEFMETHOD (double);
  R2TAO_DEFMETHOD (longdouble);
  R2TAO_DEFMETHOD (fixed);

  /*
   * Define construct writer
   */
  rb_define_method (r2tao_nsOutputStream, "write_construct", RUBY_METHOD_FUNC (r2tao_OStream_write_construct), 2);

  /*
   * Define single instance readers
   */
#undef R2TAO_DEFMETHOD
#define R2TAO_DEFMETHOD(type) \
  rb_define_method (r2tao_nsInputStream, "read_" #type, RUBY_METHOD_FUNC (r2tao_IStream_read_ ## type), 0)

  R2TAO_DEFMETHOD (any);
  R2TAO_DEFMETHOD (boolean);
  R2TAO_DEFMETHOD (char);
  R2TAO_DEFMETHOD (wchar);
  R2TAO_DEFMETHOD (octet);
  R2TAO_DEFMETHOD (short);
  R2TAO_DEFMETHOD (ushort);
  R2TAO_DEFMETHOD (long);
  R2TAO_DEFMETHOD (ulong);
  R2TAO_DEFMETHOD (longlong);
  R2TAO_DEFMETHOD (ulonglong);
  R2TAO_DEFMETHOD (float);
  R2TAO_DEFMETHOD (double);
  R2TAO_DEFMETHOD (longdouble);
  R2TAO_DEFMETHOD (Object);
  R2TAO_DEFMETHOD (Abstract);
  R2TAO_DEFMETHOD (Value);
  R2TAO_DEFMETHOD (TypeCode);
  R2TAO_DEFMETHOD (fixed);
  R2TAO_DEFMETHOD (string);
  R2TAO_DEFMETHOD (wstring);

  /*
   * Define array readers
   */
#undef R2TAO_DEFMETHOD
#define R2TAO_DEFMETHOD(type) \
  rb_define_method (r2tao_nsInputStream, "read_" #type "_array", RUBY_METHOD_FUNC (r2tao_IStream_read_ ## type ## _array), 3)

  R2TAO_DEFMETHOD (any);
  R2TAO_DEFMETHOD (boolean);
  R2TAO_DEFMETHOD (char);
  R2TAO_DEFMETHOD (wchar);
  R2TAO_DEFMETHOD (octet);
  R2TAO_DEFMETHOD (short);
  R2TAO_DEFMETHOD (ushort);
  R2TAO_DEFMETHOD (long);
  R2TAO_DEFMETHOD (ulong);
  R2TAO_DEFMETHOD (longlong);
  R2TAO_DEFMETHOD (ulonglong);
  R2TAO_DEFMETHOD (float);
  R2TAO_DEFMETHOD (double);
  R2TAO_DEFMETHOD (longdouble);
  R2TAO_DEFMETHOD (fixed);

  /*
   * Define construct reader
   */
  rb_define_method (r2tao_nsInputStream, "read_construct", RUBY_METHOD_FUNC (r2tao_IStream_read_construct), 1);

  /*
   * Create anonymous classes to wrap native streams;
   * include Portable stream modules to provide wrapper methods
   */
  r2tao_cInputStream = rb_class_new (rb_cObject);
  rb_global_variable (&r2tao_cInputStream); // pin it down so GC doesn't get it
  rb_include_module (r2tao_cInputStream, r2tao_nsInputStream);
  r2tao_cOutputStream = rb_class_new (rb_cObject);
  rb_global_variable (&r2tao_cOutputStream); // pin it down so GC doesn't get it
  rb_include_module (r2tao_cOutputStream, r2tao_nsOutputStream);

  /*
   * Define marshaling hooks for ValueBase
   */
  r2tao_nsValueBase = k = rb_eval_string ("R2CORBA::CORBA::ValueBase");
  rb_define_protected_method(k, "pre_marshal", RUBY_METHOD_FUNC(r2tao_Value_pre_marshal), 1);
  rb_define_protected_method(k, "post_marshal", RUBY_METHOD_FUNC(r2tao_Value_post_marshal), 1);
  rb_define_protected_method(k, "pre_unmarshal", RUBY_METHOD_FUNC(r2tao_Value_pre_unmarshal), 1);
  rb_define_protected_method(k, "post_unmarshal", RUBY_METHOD_FUNC(r2tao_Value_post_unmarshal), 1);

  r2tao_cValueFactoryBase = k = rb_eval_string ("R2CORBA::CORBA::Portable::ValueFactoryBase");

  rb_define_singleton_method(k, "_register_value_factory", RUBY_METHOD_FUNC(r2tao_VFB_register_value_factory), 2);
  rb_define_singleton_method(k, "_unregister_value_factory", RUBY_METHOD_FUNC(r2tao_VFB_unregister_value_factory), 1);
  rb_define_singleton_method(k, "_lookup_value_factory", RUBY_METHOD_FUNC(r2tao_VFB_lookup_value_factory), 1);

  r2tao_cBoxedValueBase = rb_eval_string ("R2CORBA::CORBA::Portable::BoxedValueBase");
}

//-------------------------------------------------------------------
//  R2TAO_ArrayAny_Impl_T template class
//
//===================================================================

template<typename T>
R2TAO_ArrayAny_Impl_T<T>::R2TAO_ArrayAny_Impl_T (CORBA::TypeCode_ptr tc,
                                                 T * const val,
                                                 CORBA::ULong len)
  : TAO::Any_Impl (0, CORBA::TypeCode::_duplicate (tc)),
    value_ (val),
    length_ (len)
{
}

template<typename T>
R2TAO_ArrayAny_Impl_T<T>::~R2TAO_ArrayAny_Impl_T (void)
{
  this->free_value ();
}

template<typename T>
void R2TAO_ArrayAny_Impl_T<T>::insert (CORBA::Any &any,
                                       CORBA::TypeCode_ptr tc,
                                       T * const val,
                                       CORBA::ULong len)
{
  R2TAO_ArrayAny_Impl_T<T> *new_impl = 0;
  ACE_NEW (new_impl,
           R2TAO_ArrayAny_Impl_T<T> (tc,
                                     val,
                                     len));
  any.replace (new_impl);
}

template<typename T>
CORBA::Boolean R2TAO_ArrayAny_Impl_T<T>::marshal_value (TAO_OutputCDR &cdr)
{
  switch (this->type_->kind ())
  {
    case CORBA::tk_short:
    case CORBA::tk_ushort:
    case CORBA::tk_long:
    case CORBA::tk_ulong:
    case CORBA::tk_float:
    case CORBA::tk_double:
    case CORBA::tk_longlong:
    case CORBA::tk_ulonglong:
    case CORBA::tk_longdouble:
    case CORBA::tk_any:
    {
      for (CORBA::ULong i=0; i<this->length_ ;++i)
      {
        cdr << (reinterpret_cast<T*> (this->value_))[i];
      }
      return true;
    }
    default:
      return false;
  }
}

template<>
CORBA::Boolean R2TAO_ArrayAny_Impl_T<CORBA::Boolean>::marshal_value (TAO_OutputCDR &cdr)
{
  for (CORBA::ULong i=0; i<this->length_ ;++i)
  {
    cdr << ACE_OutputCDR::from_boolean ((reinterpret_cast<CORBA::Boolean*> (this->value_))[i]);
  }
  return true;
}

template<>
CORBA::Boolean R2TAO_ArrayAny_Impl_T<CORBA::Char>::marshal_value (TAO_OutputCDR &cdr)
{
  for (CORBA::ULong i=0; i<this->length_ ;++i)
  {
    cdr << ACE_OutputCDR::from_char ((reinterpret_cast<CORBA::Char*> (this->value_))[i]);
  }
  return true;
}

template<>
CORBA::Boolean R2TAO_ArrayAny_Impl_T<CORBA::WChar>::marshal_value (TAO_OutputCDR &cdr)
{
  for (CORBA::ULong i=0; i<this->length_ ;++i)
  {
    cdr << ACE_OutputCDR::from_wchar ((reinterpret_cast<CORBA::WChar*> (this->value_))[i]);
  }
  return true;
}

template<>
CORBA::Boolean R2TAO_ArrayAny_Impl_T<CORBA::Octet>::marshal_value (TAO_OutputCDR &cdr)
{
  for (CORBA::ULong i=0; i<this->length_ ;++i)
  {
    cdr << ACE_OutputCDR::from_octet ((reinterpret_cast<CORBA::Octet*> (this->value_))[i]);
  }
  return true;
}

template<typename T>
const void *R2TAO_ArrayAny_Impl_T<T>::value (void) const
{
  return this->value_;
}

template<typename T>
void R2TAO_ArrayAny_Impl_T<T>::free_value (void)
{
  if (this->value_ != 0)
  {
    delete [] reinterpret_cast<T*> (this->value_);
  }

  ::CORBA::release (this->type_);
  this->value_ = 0;
}

//-------------------------------------------------------------------
//  R2TAO Value class
//
//===================================================================

R2TAO_Value::R2TAO_Value (VALUE rbValue, bool for_unmarshal)
  : for_unmarshal_ (for_unmarshal),
    started_chunk_unmarshal_ (false),
    requires_truncation_ (false),
    rbValue_ (rbValue),
    rbValueClass_ (Qnil),
    rbCIHolder_ (Qnil),
    last_chunk_ (0)
{
  init ();
}

R2TAO_Value::~R2TAO_Value ()
{
  if (TAO_debug_level > 9)
    ACE_DEBUG ((LM_INFO, "R2TAO (%P|%t) - R2TAO_Value::dtor "
                         "destroying Value wrapper %@ for %C\n",
                         this, this->val_tc_->id ()));
  // reset value reference
  rb_ivar_set (this->rbValue_, val_ivar_ID, Qnil);
  // free Ruby value for gc collection
  r2tao_unregister_object (this->rbValue_);
  this->rbValue_ = Qnil;
  this->rbCIHolder_ = Qnil;
}

CORBA::ValueBase* R2TAO_Value::_copy_value (void)
{
  return 0; // noop
}

void R2TAO_Value::init ()
{
  static ID tc_ID = rb_intern ("_tc");
  static R2TAO_RBFuncall FN_marshal ("do_marshal", false);

  // mark Ruby value to prevent gc collection
  r2tao_register_object (this->rbValue_);

  this->rbValueClass_ = rb_class_of(this->rbValue_);
  VALUE rtc = rb_funcall (this->rbValueClass_, tc_ID, 0);
  this->val_tc_ = CORBA::TypeCode::_duplicate (r2corba_TypeCode_r2t (rtc));

  // determin if this is a truncatable value type
  if (this->val_tc_->kind () == CORBA::tk_value)
    this->is_truncatable_ = (CORBA::VM_TRUNCATABLE == this->val_tc_->type_modifier ());
  else
    this->is_truncatable_ = false; // value box

  // create special wrapper object to hold this value reference
  VALUE valref = Data_Wrap_Struct (rb_cObject, 0, 0, this);

  // create an instance variable to value reference
  rb_ivar_set (this->rbValue_, val_ivar_ID, valref);

  if (this->for_unmarshal_)
  {
    // create special wrapper object to hold chunk info
    this->rbCIHolder_ = Data_Wrap_Struct (rb_cObject, 0, 0, 0);

    // create an instance variable to hold chunk info while (de)marshaling
    rb_ivar_set (this->rbValue_, ci_ivar_ID, this->rbCIHolder_);
  }
  else
  {
    // invoke Ruby Value marshaling to collect element data
    VALUE rargs = rb_ary_new2 (1);
    rb_ary_push (rargs, r2tao_OutputStream_t2r (this));

    if (TAO_debug_level > 10)
      ACE_DEBUG ((LM_INFO, "R2TAO (%P|%t) - R2TAO_Value::init: "
                           "invoking Ruby marshaling for value %@ for %C\n",
                           this->rbValue_,
                           this->val_tc_->id ()));

    FN_marshal.invoke (this->rbValue_, rargs);
    if (FN_marshal.has_caught_exception ())
    {
      rb_eval_string ("STDERR.puts $!.to_s+\"\\n\"+$!.backtrace.join(\"\\n\")");
      throw ::CORBA::MARSHAL (0, CORBA::COMPLETED_NO);
    }

    if (TAO_debug_level > 10)
      ACE_DEBUG ((LM_INFO, "R2TAO (%P|%t) - R2TAO_Value::init: "
                           "Ruby marshaling succeeded for value %@ for %C\n",
                           this->rbValue_,
                           this->val_tc_->id ()));

  }

  if (TAO_debug_level > 9)
    ACE_DEBUG ((LM_INFO, "R2TAO (%P|%t) - R2TAO_Value::ctor "
                         "created Value wrapper %@ for %s %s\n",
                         this, this->val_tc_->id (),
                         this->is_truncatable_ ? "(truncatable)" : ""));
}

void R2TAO_Value::_tao_any_destructor (void *_tao_void_pointer)
{
  R2TAO_Value *_tao_tmp_pointer =
    static_cast<R2TAO_Value *> (_tao_void_pointer);
  ::CORBA::remove_ref (_tao_tmp_pointer);
}

void R2TAO_Value::truncation_hook ()
{
  this->requires_truncation_ = true;
}

R2TAO_Value* R2TAO_Value::_downcast (::CORBA::ValueBase *v)
{
  return dynamic_cast<R2TAO_Value*> (v);
}

CORBA::TypeCode_ptr R2TAO_Value::_tao_type (void) const
{
  return this->val_tc_.in ();
}

const char * R2TAO_Value::_tao_obv_repository_id (void) const
{
  return this->val_tc_->id ();
}

void R2TAO_Value::_tao_obv_truncatable_repo_ids (Repository_Id_List & ids) const
{
  static ID TRUNC_IDS_ID = rb_intern ("TRUNCATABLE_IDS");

  VALUE rb_ids = rb_const_get(this->rbValueClass_, TRUNC_IDS_ID);
  CHECK_RTYPE (rb_ids, T_ARRAY);
  CORBA::ULong alen = static_cast<unsigned long> (RARRAY_LEN (rb_ids));
  for (CORBA::ULong l=0; l<alen ;++l)
  {
    VALUE id = rb_ary_entry (rb_ids, l);
    CHECK_RTYPE (id, T_STRING);
    ids.push_back (RSTRING_PTR (id));
  }
}

class CI_Guard
{
  public:
    CI_Guard (VALUE rbval, TAO_ChunkInfo *pci)
      : rbval_ (rbval)
    { DATA_PTR (this->rbval_) = static_cast<void*> (pci); }
    ~CI_Guard () { DATA_PTR (this->rbval_) = 0; }
  private:
    VALUE rbval_;
};

::CORBA::Boolean R2TAO_Value::_tao_marshal_v (TAO_OutputCDR &strm) const
{
  if (this->for_unmarshal_)   return false;

  // setup chunking info
  TAO_ChunkInfo ci (this->is_truncatable_ || this->chunking_);

  if (TAO_debug_level > 9)
    ACE_DEBUG ((LM_INFO, "R2TAO (%P|%t) - R2TAO_Value::_tao_marshal_v: "
                         "marshaling value %@ for %s %s\n",
                         this,
                         this->val_tc_->id (),
                         ci.chunking_ ? "(chunked)" : ""));

  if (! ci.start_chunk (strm))
    return false;

  // marshal all elements in all chunks (== all concrete values from inheritance chain)
  Chunk* p = this->chunk_list_.get ();
  while (p)
  {
    if (! ci.start_chunk (strm))
      return false;

    if (TAO_debug_level > 10)
      ACE_DEBUG ((LM_INFO, "R2TAO (%P|%t) - R2TAO_Value::_tao_marshal_v: "
                           "marshaling chunk %@ for value %@ for %s\n",
                           p,
                           this,
                           this->val_tc_->id ()));

    ChunkElements::size_type n = p->elems_.size ();
    for (ChunkElements::size_type e = 0; e < n ;++e)
    {
      if (TAO_debug_level > 10)
        ACE_DEBUG ((LM_INFO, "R2TAO (%P|%t) - R2TAO_Value::_tao_marshal_v: "
                             "marshaling chunk element %u for value %@ for %s\n",
                             e,
                             this,
                             this->val_tc_->id ()));

      if (p->elems_[e] == 0 || p->elems_[e]->impl () == 0)
      {
        // should not ever happen
        ACE_DEBUG ((LM_ERROR, "R2TAO (%P|%t) - R2TAO_Value::_tao_marshal_v: "
                              "chunk element %u for value %@ for %s is INVALID (%C is null)\n",
                              e,
                              this,
                              this->val_tc_->id (),
                              p->elems_[e] == 0 ? "_var ptr" : "Any impl"));
        return false;
      }

      p->elems_[e]->impl ()->marshal_value (strm);
    }

    if (! ci.end_chunk (strm))
      return false;

    p = p->next_;
  }

  if (TAO_debug_level > 9)
    ACE_DEBUG ((LM_INFO, "R2TAO (%P|%t) - R2TAO_Value::_tao_marshal_v: "
                         "succeeded marshaling value %@ for %s\n",
                         this,
                         this->val_tc_->id ()));

  return ci.end_chunk (strm);
}

bool R2TAO_Value::add_chunk ()
{
  Chunk* new_chunk = 0;
  ACE_NEW_NORETURN (new_chunk, Chunk());
  if (new_chunk != 0)
  {
    if (this->last_chunk_)
    {
      this->last_chunk_->next_ = new_chunk;
    }
    else
    {
      this->chunk_list_.reset (new_chunk);
    }
    this->last_chunk_ = new_chunk;

    if (TAO_debug_level > 10)
      ACE_DEBUG ((LM_INFO, "R2TAO (%P|%t) - R2TAO_Value::add_chunk: "
                           "added chunk %@ for value %@ for %s\n",
                           new_chunk,
                           this,
                           this->val_tc_->id ()));

    return true;
  }
  return false;
}

bool R2TAO_Value::add_chunk_element (CORBA::Any_var& elem)
{
  if (this->last_chunk_ || this->add_chunk())
  {
    ChunkElements::size_type last_ix = this->last_chunk_->elems_.size ();
    this->last_chunk_->elems_.size (last_ix+1);
    this->last_chunk_->elems_[last_ix] = elem._retn ();

    if (TAO_debug_level > 10)
      ACE_DEBUG ((LM_INFO, "R2TAO (%P|%t) - R2TAO_Value::add_chunk: "
                           "added chunk %@ element %u for value %@ for %s\n",
                           this->last_chunk_,
                           last_ix,
                           this,
                           this->val_tc_->id ()));

    return true;
  }
  return false;
}


::CORBA::Boolean R2TAO_Value::_tao_unmarshal_v (TAO_InputCDR &strm)
{
  static R2TAO_RBFuncall FN_unmarshal ("do_unmarshal", false);

  if (!this->for_unmarshal_)   return false;

  // setup chunking info
  TAO_ChunkInfo ci (this->is_truncatable_ || this->chunking_, 1);
  // store info with Ruby value
  CI_Guard __ci_guard(this->rbCIHolder_, &ci);

  if (TAO_debug_level > 9)
    ACE_DEBUG ((LM_INFO, "R2TAO (%P|%t) - R2TAO_Value::_tao_unmarshal_v: "
                         "unmarshaling value %@ for %s\n",
                         this->rbValue_,
                         this->val_tc_->id ()));

  if (!ci.handle_chunking (strm))
    return false;

  // invoke Ruby Value unmarshaling
  VALUE rargs = rb_ary_new2 (1);
  rb_ary_push (rargs, r2tao_InputStream_t2r (&strm));

  if (TAO_debug_level > 10)
    ACE_DEBUG ((LM_INFO, "R2TAO (%P|%t) - R2TAO_Value::_tao_unmarshal_v: "
                         "invoking Ruby unmarshaling for value %@ for %s\n",
                         this->rbValue_,
                         this->val_tc_->id ()));

  FN_unmarshal.invoke (this->rbValue_, rargs);
  if (FN_unmarshal.has_caught_exception ())
  {
    rb_eval_string ("STDERR.puts $!.to_s+\"\\n\"+$!.backtrace.join(\"\\n\")");
    return false;
  }

  if (TAO_debug_level > 10)
    ACE_DEBUG ((LM_INFO, "R2TAO (%P|%t) - R2TAO_Value::_tao_unmarshal_v: "
                         "succeeded unmarshaling value %@ for %s %s\n",
                         this->rbValue_,
                         this->val_tc_->id (),
                         this->requires_truncation_ ? "(with truncation)" : ""));

  if (this->requires_truncation_)
    return ci.skip_chunks (strm);
  else
    return ci.handle_chunking (strm);
}

// always return false -> i.e. always marshal type Id
::CORBA::Boolean R2TAO_Value::_tao_match_formal_type (ptrdiff_t ) const
{
  return 0;
}

void operator<<= (::CORBA::Any & _tao_any, R2TAO_Value_ptr _tao_elem)
{
  ::CORBA::add_ref (_tao_elem);
  _tao_any <<= &_tao_elem;
}
void operator<<= (::CORBA::Any & _tao_any, R2TAO_Value_ptr * _tao_elem)
{
  TAO::Any_Impl_T<R2TAO_Value>::insert (
      _tao_any,
      R2TAO_Value::_tao_any_destructor,
      (*_tao_elem)->_tao_type (),
      *_tao_elem);
}

::CORBA::Boolean operator<< (TAO_OutputCDR &strm, const R2TAO_Value * _tao_valref)
{
  // check for existence of TAO valuetype indirection map
  if (!strm.get_value_map ().is_nil ())
  {
    // keep map clear effectively disabling indirection
    // because this does not work with R2TAO Value objects
    strm.get_value_map ()->get ()->unbind_all ();
  }

  return
    ::CORBA::ValueBase::_tao_marshal (
        strm,
        _tao_valref,
        reinterpret_cast<ptrdiff_t> (&R2TAO_Value::_downcast)
      );
}

::CORBA::Boolean operator>> (TAO_InputCDR &strm, R2TAO_Value *&_tao_valref)
{
  CORBA::ValueBase * _tao_valbase = _tao_valref;
  ::CORBA::Boolean ret = R2TAO_Value::_tao_unmarshal (strm, _tao_valbase);
  _tao_valref = dynamic_cast <R2TAO_Value*> (_tao_valbase);
  return ret;
}

void TAO::Value_Traits<R2TAO_Value>::add_ref (R2TAO_Value * p)
{
  ::CORBA::add_ref (p);
}

void TAO::Value_Traits<R2TAO_Value>::remove_ref (R2TAO_Value * p)
{
  ::CORBA::remove_ref (p);
}

void TAO::Value_Traits<R2TAO_Value>::release (R2TAO_Value * p)
{
  ::CORBA::remove_ref (p);
}

VALUE r2tao_wrap_Valuebox(VALUE rval, CORBA::TypeCode_ptr tc)
{
  static ID set_value_ID = rb_intern ("value=");

  CORBA::ValueFactory factory =
      TAO_ORB_Core_instance ()->orb ()->lookup_value_factory (
          tc->id ());
  if (factory)
  {
    CORBA::ValueBase * vb = factory->create_for_unmarshal ();
    R2TAO_Value_var r2tval = R2TAO_Value::_downcast (vb);
    factory->_remove_ref (); // we're done with this
    rb_funcall (r2tval->get_ruby_value(), set_value_ID, 1, rval);
    return r2tval->get_ruby_value();
  }
  else
  {
    throw CORBA::BAD_PARAM();
  }
}

//-------------------------------------------------------------------
//  R2TAO Value methods
//
//===================================================================

VALUE r2tao_Value_pre_marshal(VALUE /*self*/, VALUE rstrm)
{
  R2TAO_Value* val = r2tao_OutputStream_r2t(rstrm);

  if (!val->add_chunk ())
    X_CORBA (MARSHAL);

  return Qtrue;
}

VALUE r2tao_Value_post_marshal(VALUE /*self*/, VALUE /*rstrm*/)
{
  return Qtrue;
}

VALUE r2tao_Value_pre_unmarshal(VALUE self, VALUE rstrm)
{
  // get reference holder for native value
  VALUE rb_val = rb_ivar_get (self, val_ivar_ID);
  // get native Value
  R2TAO_Value* val = static_cast<R2TAO_Value*> (DATA_PTR (rb_val));

  if (TAO_debug_level > 10)
    ACE_DEBUG ((LM_INFO, "R2TAO (%P|%t) - R2CORBA::CORBA::ValueBase::pre_unmarshal: "
                         "unmarshaling value state for %@ %s\n",
                         self,
                         val->requires_truncation () ? "with truncation" : ""));

  // get ChunkInfo holder
  VALUE rb_ci = rb_ivar_get (self, ci_ivar_ID);
  // get ChunkInfo
  TAO_ChunkInfo &ci = *static_cast<TAO_ChunkInfo*> (DATA_PTR (rb_ci));

  TAO_InputCDR& strm = *r2tao_InputStream_r2t(rstrm);

  if (val->has_started_chunk_unmarshalling ())
  {
    if (TAO_debug_level > 10)
      ACE_DEBUG ((LM_INFO, "R2TAO (%P|%t) - R2CORBA::CORBA::ValueBase::pre_unmarshal: "
                           "finish unmarshalling previous value state chunk for %@\n",
                           self));
    // need to finish the previous chunk unmarshalling
    if (!ci.handle_chunking (strm))
      X_CORBA (MARSHAL);

    val->ended_chunk_unmarshalling ();
  }

  // start next chunk
  if (!ci.handle_chunking (strm))
    X_CORBA (MARSHAL);

  val->started_chunk_unmarshalling ();

  return Qtrue;
}

VALUE r2tao_Value_post_unmarshal(VALUE /*self*/, VALUE /*rstrm*/)
{
  return Qtrue;
}

//-------------------------------------------------------------------
//  R2TAO Valuefactory class
//
//  Wrapper class for reference to R2CORBA valuefactory instance
//===================================================================

R2TAO_RBFuncall R2TAO_ValueFactory::fn_create_default_ ("_create_default", false);

R2TAO_ValueFactory::R2TAO_ValueFactory (VALUE rbValueFactory)
  : rbValueFactory_ (rbValueFactory)
{
  r2tao_register_object (this->rbValueFactory_);
}

R2TAO_ValueFactory::~R2TAO_ValueFactory (void)
{
  r2tao_unregister_object (this->rbValueFactory_);
}

R2TAO_ValueFactory* R2TAO_ValueFactory::_downcast ( ::CORBA::ValueFactoryBase * vfb)
{
  return dynamic_cast <R2TAO_ValueFactory*> (vfb);
}

::CORBA::ValueBase * R2TAO_ValueFactory::create_for_unmarshal (void)
{
  // create new Ruby Value
  VALUE rval = fn_create_default_.invoke (this->rbValueFactory_);
  if (fn_create_default_.has_caught_exception ())
  {
    rb_eval_string ("STDERR.puts $!.to_s+\"\\n\"+$!.backtrace.join(\"\\n\")");
    return 0;
  }

  R2TAO_Value *ret_val = 0;
  ACE_NEW_THROW_EX (
      ret_val,
      R2TAO_Value (rval, true),
      ::CORBA::NO_MEMORY ()
    );

  if (TAO_debug_level > 9)
    ACE_DEBUG ((LM_INFO, "R2TAO (%P|%t) - R2TAO_ValueFactory::create_for_unmarshal: "
                         "created value wrapper %@ for %s\n",
                         ret_val,
                         this->tao_repository_id ()));

  return ret_val;
}

::CORBA::AbstractBase_ptr R2TAO_ValueFactory::create_for_unmarshal_abstract (void)
{
  // create new Ruby Value
  VALUE rval = fn_create_default_.invoke (this->rbValueFactory_);
  if (fn_create_default_.has_caught_exception ())
  {
    rb_eval_string ("STDERR.puts $!.to_s+\"\\n\"+$!.backtrace.join(\"\\n\")");
    return 0;
  }

  // create without 'abs_tc' below since this object will not be
  // used for marshaling but only for unmarshaling
  // through a call to _tao_unmarshal_v()
  R2TAO_AbstractValue *ret_val = 0;
  ACE_NEW_THROW_EX (
      ret_val,
      R2TAO_AbstractValue (rval),
      ::CORBA::NO_MEMORY ()
    );
  return ret_val;
}

// TAO-specific extensions
const char* R2TAO_ValueFactory::tao_repository_id (void)
{
  static ID value_id_ID = rb_intern ("value_id");

  VALUE id = rb_funcall (this->rbValueFactory_, value_id_ID, 0);
  CHECK_RTYPE (id, T_STRING);
  return RSTRING_PTR (id);
}

VALUE r2tao_VFB_register_value_factory(VALUE /*self*/, VALUE id, VALUE rfact)
{
#if !defined(CORBA_E_MICRO)
  R2TAO_TRY {
    CHECK_RTYPE (id, T_STRING);
    if (rb_obj_is_kind_of (rfact, r2tao_cValueFactoryBase) != Qtrue)
    {
      throw CORBA::BAD_PARAM (0, CORBA::COMPLETED_NO);
    }

    if (TAO_debug_level > 5)
      ACE_DEBUG ((LM_INFO, "R2TAO (%P|%t) - ValueFactoryBase::register_value_factory:: "
                           "registering factory for %s\n",
                           RSTRING_PTR (id)));

    CORBA::ValueFactory factory = new R2TAO_ValueFactory (rfact);
    CORBA::ValueFactory prev_factory =
        TAO_ORB_Core_instance ()->orb ()->register_value_factory (
              RSTRING_PTR (id),
              factory);
    if (prev_factory) prev_factory->_remove_ref ();
    factory->_remove_ref ();
  } R2TAO_CATCH;
#else
  X_CORBA(NO_IMPLEMENT);
#endif
  return Qnil;
}

VALUE r2tao_VFB_unregister_value_factory(VALUE /*self*/, VALUE id)
{
#if !defined(CORBA_E_MICRO)
  R2TAO_TRY {
    CHECK_RTYPE (id, T_STRING);

    if (TAO_debug_level > 5)
      ACE_DEBUG ((LM_INFO, "R2TAO (%P|%t) - ORB::unregister_value_factory:: "
                           "unregistering factory for %s\n",
                           RSTRING_PTR (id)));

    TAO_ORB_Core_instance ()->orb ()->unregister_value_factory (
          RSTRING_PTR (id));
  } R2TAO_CATCH;
#else
  X_CORBA(NO_IMPLEMENT);
#endif
  return Qnil;
}

VALUE r2tao_VFB_lookup_value_factory(VALUE /*self*/, VALUE id)
{
  VALUE ret = Qnil;
#if !defined(CORBA_E_MICRO)
  R2TAO_TRY {
    CHECK_RTYPE (id, T_STRING);

    if (TAO_debug_level > 5)
      ACE_DEBUG ((LM_INFO, "R2TAO (%P|%t) - ORB::lookup_value_factory:: "
                           "looking up factory for %s\n",
                           RSTRING_PTR (id)));

    CORBA::ValueFactory factory =
        TAO_ORB_Core_instance ()->orb ()->lookup_value_factory (
              RSTRING_PTR (id));
    if (factory)
    {
      R2TAO_ValueFactory* r2tfact = dynamic_cast <R2TAO_ValueFactory*> (factory);
      ret = r2tfact->get_ruby_factory();
      factory->_remove_ref ();
    }
  } R2TAO_CATCH;
#else
  X_CORBA(NO_IMPLEMENT);
#endif
  return ret;
}

//-------------------------------------------------------------------
//  R2TAO AbstractValue class
//
//  Wrapper class for value type to present CORBA::AbstractBase
//  interface to TAO Any
//===================================================================

R2TAO_AbstractValue::R2TAO_AbstractValue (VALUE rbValue,
                                          CORBA::TypeCode_ptr abs_tc)
 : ::CORBA::AbstractBase (),
   R2TAO_Value (rbValue),
   abs_tc_ (CORBA::TypeCode::_duplicate (abs_tc))
{
}

R2TAO_AbstractValue::R2TAO_AbstractValue (VALUE rbValue)
 : ::CORBA::AbstractBase (),
   R2TAO_Value (rbValue, true)
{
}

R2TAO_AbstractValue::~R2TAO_AbstractValue ()
{
}

void R2TAO_AbstractValue::_tao_any_destructor (void *_tao_void_pointer)
{
  R2TAO_AbstractValue *_tao_tmp_pointer =
      static_cast<R2TAO_AbstractValue *> (_tao_void_pointer);
  ::CORBA::remove_ref (_tao_tmp_pointer);
}

R2TAO_AbstractValue_ptr R2TAO_AbstractValue::_duplicate (R2TAO_AbstractValue_ptr obj)
{
  if (! ::CORBA::is_nil (obj))
  {
    obj->_add_ref ();
  }

  return obj;
}

R2TAO_AbstractValue* R2TAO_AbstractValue::_downcast ( ::CORBA::ValueBase *v)
{
  return dynamic_cast< ::R2TAO_AbstractValue * > (v);
}

const char* R2TAO_AbstractValue::_tao_obv_repository_id (void) const
{
  return this->R2TAO_Value::_tao_obv_repository_id ();
}
CORBA::Boolean R2TAO_AbstractValue::_tao_marshal_v (TAO_OutputCDR &strm) const
{
  return this->R2TAO_Value::_tao_marshal_v (strm);
}
CORBA::Boolean R2TAO_AbstractValue::_tao_unmarshal_v (TAO_InputCDR &strm)
{
  return this->R2TAO_Value::_tao_unmarshal_v (strm);
}
CORBA::Boolean R2TAO_AbstractValue::_tao_match_formal_type (ptrdiff_t p) const
{
  return this->R2TAO_Value::_tao_match_formal_type (p);
}

void R2TAO_AbstractValue::_add_ref (void)
{
  this->::CORBA::DefaultValueRefCountBase::_add_ref ();
}

void R2TAO_AbstractValue::_remove_ref (void)
{
  this->::CORBA::DefaultValueRefCountBase::_remove_ref ();
}

::CORBA::ValueBase *R2TAO_AbstractValue::_tao_to_value (void)
{
  return this;
}

CORBA::TypeCode_ptr R2TAO_AbstractValue::abstract_type () const
{
  return this->abs_tc_.in ();
}

void operator<<= (::CORBA::Any & _tao_any, R2TAO_AbstractValue_ptr _tao_elem)
{
  R2TAO_AbstractValue_ptr _tao_valptr =
      R2TAO_AbstractValue::_duplicate (_tao_elem);
  _tao_any <<= &_tao_valptr;
}
void operator<<= (::CORBA::Any & _tao_any, R2TAO_AbstractValue_ptr * _tao_elem)
{
  TAO::Any_Impl_T<R2TAO_AbstractValue>::insert (
      _tao_any,
      R2TAO_AbstractValue::_tao_any_destructor,
      (*_tao_elem)->abstract_type (),
      *_tao_elem);
}

::CORBA::Boolean operator<< (TAO_OutputCDR &strm, const R2TAO_AbstractValue_ptr _tao_valref)
{
  ::CORBA::AbstractBase_ptr _tao_corba_abs = _tao_valref;
  return (strm << _tao_corba_abs);
}

// Dummy to allow compilation of Any_Impl_T<R2TAO_AbstractValue> template instantiation.
// We never use the extraction code of that template though.
::CORBA::Boolean operator>> (TAO_InputCDR &/*strm*/, R2TAO_AbstractValue_ptr &/*_tao_objref*/)
{
  return false;
}

R2TAO_AbstractValue_ptr
TAO::Objref_Traits<R2TAO_AbstractValue>::duplicate (
    R2TAO_AbstractValue_ptr p)
{
  return R2TAO_AbstractValue::_duplicate (p);
}

void
TAO::Objref_Traits<R2TAO_AbstractValue>::release (
    R2TAO_AbstractValue_ptr p)
{
  ::CORBA::release (p);
}

R2TAO_AbstractValue_ptr
TAO::Objref_Traits<R2TAO_AbstractValue>::nil (void)
{
  return 0;
}

::CORBA::Boolean
TAO::Objref_Traits<R2TAO_AbstractValue>::marshal (
    const R2TAO_AbstractValue_ptr p,
    TAO_OutputCDR & cdr)
{
  return cdr << p;
}

//-------------------------------------------------------------------
//  R2TAO AbstractObject class
//
//  Wrapper class for object reference to present CORBA::AbstractBase
//  interface to TAO Any
//===================================================================

R2TAO_AbstractObject::R2TAO_AbstractObject (CORBA::Object_ptr objref,
                                            CORBA::TypeCode_ptr abs_tc)
  : CORBA::AbstractBase (objref->_stubobj(),
                         objref->_is_collocated(),
                         objref->_is_collocated() ? objref->_stubobj()->collocated_servant () : 0),
    CORBA::Object (),
    abs_tc_ (CORBA::TypeCode::_duplicate (abs_tc))
{
}

R2TAO_AbstractObject::~R2TAO_AbstractObject ()
{
}

void CORBA::release (R2TAO_AbstractObject_ptr p)
{
  ::CORBA::AbstractBase_ptr abs = p;
  ::CORBA::release (abs);
}

::CORBA::Boolean CORBA::is_nil (R2TAO_AbstractObject_ptr p)
{
  ::CORBA::Object_ptr obj = p;
  return ::CORBA::is_nil (obj);
}

void R2TAO_AbstractObject::_tao_any_destructor (void *_tao_void_pointer)
{
  R2TAO_AbstractObject *_tao_tmp_pointer =
      static_cast<R2TAO_AbstractObject *> (_tao_void_pointer);
  ::CORBA::release (_tao_tmp_pointer);
}

R2TAO_AbstractObject_ptr R2TAO_AbstractObject::_duplicate (R2TAO_AbstractObject_ptr obj)
{
  if (! ::CORBA::is_nil (obj))
  {
    obj->_add_ref ();
  }

  return obj;
}

void R2TAO_AbstractObject::_tao_release (R2TAO_AbstractObject_ptr obj)
{
  ::CORBA::release (obj);
}

void R2TAO_AbstractObject::_add_ref (void)
{
  this->::CORBA::Object::_add_ref();
}
void R2TAO_AbstractObject::_remove_ref (void)
{
  this->::CORBA::Object::_remove_ref();
}

::CORBA::Boolean R2TAO_AbstractObject::_is_a (const char *type_id)
{
  return this->::CORBA::AbstractBase::_is_a (type_id) ||
         ACE_OS::strcmp (type_id,
             "IDL:omg.org/CORBA/Object:1.0") == 0 ||
         this->::CORBA::Object::_is_a (type_id);
}

const char* R2TAO_AbstractObject::_interface_repository_id (void) const
{
  return this->abs_tc_->id ();
}

::CORBA::Boolean R2TAO_AbstractObject::marshal (TAO_OutputCDR &cdr)
{
  return (cdr << (::CORBA::AbstractBase_ptr)this);
}

CORBA::TypeCode_ptr R2TAO_AbstractObject::abstract_type () const
{
  return this->abs_tc_.in ();
}

void operator<<= (::CORBA::Any & _tao_any, R2TAO_AbstractObject_ptr _tao_elem)
{
  R2TAO_AbstractObject_ptr _tao_objptr =
      R2TAO_AbstractObject::_duplicate (_tao_elem);
  _tao_any <<= &_tao_objptr;
}
void operator<<= (::CORBA::Any & _tao_any, R2TAO_AbstractObject_ptr * _tao_elem)
{
  TAO::Any_Impl_T<R2TAO_AbstractObject>::insert (
      _tao_any,
      R2TAO_AbstractObject::_tao_any_destructor,
      (*_tao_elem)->abstract_type (),
      *_tao_elem);
}

::CORBA::Boolean operator<< (TAO_OutputCDR &strm, const R2TAO_AbstractObject_ptr _tao_objref)
{
  ::CORBA::AbstractBase_ptr _tao_corba_obj = _tao_objref;
  return (strm << _tao_corba_obj);
}

// Dummy to allow compilation of Any_Impl_T<R2TAO_AbstractObject> template instantiation.
// We never use the extraction code of that template though.
::CORBA::Boolean operator>> (TAO_InputCDR &/*strm*/, R2TAO_AbstractObject_ptr &/*_tao_objref*/)
{
  return false;
}

R2TAO_AbstractObject_ptr
TAO::Objref_Traits<R2TAO_AbstractObject>::duplicate (
    R2TAO_AbstractObject_ptr p)
{
  return R2TAO_AbstractObject::_duplicate (p);
}

void
TAO::Objref_Traits<R2TAO_AbstractObject>::release (
    R2TAO_AbstractObject_ptr p)
{
  ::CORBA::release (p);
}

R2TAO_AbstractObject_ptr
TAO::Objref_Traits<R2TAO_AbstractObject>::nil (void)
{
  return 0;
}

::CORBA::Boolean
TAO::Objref_Traits<R2TAO_AbstractObject>::marshal (
    const R2TAO_AbstractObject_ptr p,
    TAO_OutputCDR & cdr)
{
  return cdr << p;
}

//-------------------------------------------------------------------
//  R2TAO Stream methods
//
//===================================================================

// wrapping & unwrapping

static VALUE
r2tao_InputStream_t2r(TAO_InputCDR* strm)
{
  VALUE ret;

  ret = Data_Wrap_Struct(r2tao_cInputStream, 0, 0, strm);

  return ret;
}

static VALUE
r2tao_OutputStream_t2r(R2TAO_Value* val)
{
  VALUE ret;

  ret = Data_Wrap_Struct(r2tao_cOutputStream, 0, 0, val);

  return ret;
}

static TAO_InputCDR*
r2tao_InputStream_r2t(VALUE strm)
{
  TAO_InputCDR *ret;

  Data_Get_Struct(strm, TAO_InputCDR, ret);

  return ret;
}

static R2TAO_Value*
r2tao_OutputStream_r2t(VALUE strm)
{
  R2TAO_Value *ret;

  Data_Get_Struct(strm, R2TAO_Value, ret);

  return ret;
}

// ------------------------------------------------------------------
// OutputStream

VALUE r2tao_OStream_write_any (VALUE self, VALUE rval)
{
  R2TAO_Value* vt = r2tao_OutputStream_r2t(self);
  R2TAO_TRY {
    if (NIL_P (rval))
    {
      if (TAO_debug_level > 0)
        ACE_DEBUG ((LM_ERROR, "R2TAO (%P|%t) - OutputStream#write_any:: "
                              "NIL value not allowed\n"));
      throw CORBA::MARSHAL ();
    }
    CORBA::Any* any = 0;
    ACE_NEW_THROW_EX (any,
                      CORBA::Any (),
                      CORBA::NO_MEMORY());
    CORBA::Any_var any_safe = any;
    r2tao_Ruby_to_Any(*any, rval);
    if (!vt->add_chunk_element (any_safe))
      throw CORBA::MARSHAL ();
  } R2TAO_CATCH;
  return Qnil;
}

VALUE r2tao_OStream_write_boolean (VALUE self, VALUE rval)
{
  R2TAO_Value* vt = r2tao_OutputStream_r2t(self);
  R2TAO_TRY {
    CORBA::Any* any = 0;
    ACE_NEW_THROW_EX (any,
                      CORBA::Any (),
                      CORBA::NO_MEMORY());
    CORBA::Any_var any_safe = any;
    CORBA::Boolean f = (NIL_P (rval) || rval == Qfalse) ? 0 : 1;
    *any <<= CORBA::Any::from_boolean (f);
    if (!vt->add_chunk_element (any_safe))
      throw CORBA::MARSHAL ();
  } R2TAO_CATCH;
  return Qnil;
}

VALUE r2tao_OStream_write_char (VALUE self, VALUE rval)
{
  R2TAO_Value* vt = r2tao_OutputStream_r2t(self);
  R2TAO_TRY {
    CORBA::Any* any = 0;
    ACE_NEW_THROW_EX (any,
                      CORBA::Any (),
                      CORBA::NO_MEMORY());
    CORBA::Any_var any_safe = any;
    CORBA::Char ch = 0;
    if (!NIL_P (rval))
    {
      CHECK_RTYPE(rval, T_STRING);
      ch = *RSTRING_PTR (rval);
    }
    *any <<= CORBA::Any::from_char (ch);
    if (!vt->add_chunk_element (any_safe))
      throw CORBA::MARSHAL ();
  } R2TAO_CATCH;
  return Qnil;
}

VALUE r2tao_OStream_write_wchar (VALUE self, VALUE rval)
{
  R2TAO_Value* vt = r2tao_OutputStream_r2t(self);
  R2TAO_TRY {
    CORBA::Any* any = 0;
    ACE_NEW_THROW_EX (any,
                      CORBA::Any (),
                      CORBA::NO_MEMORY());
    CORBA::Any_var any_safe = any;
    CORBA::WChar wc = NIL_P (rval) ? 0 : NUM2UINT (rval);
    *any <<= CORBA::Any::from_wchar (wc);
    if (!vt->add_chunk_element (any_safe))
      throw CORBA::MARSHAL ();
  } R2TAO_CATCH;
  return Qnil;
}

VALUE r2tao_OStream_write_octet (VALUE self, VALUE rval)
{
  R2TAO_Value* vt = r2tao_OutputStream_r2t(self);
  R2TAO_TRY {
    CORBA::Any* any = 0;
    ACE_NEW_THROW_EX (any,
                      CORBA::Any (),
                      CORBA::NO_MEMORY());
    CORBA::Any_var any_safe = any;
    CORBA::Octet byte = NIL_P (rval) ? 0 : NUM2UINT (rval);
    *any <<= CORBA::Any::from_octet (byte);
    if (!vt->add_chunk_element (any_safe))
      throw CORBA::MARSHAL ();
  } R2TAO_CATCH;
  return Qnil;
}

VALUE r2tao_OStream_write_short (VALUE self, VALUE rval)
{
  R2TAO_Value* vt = r2tao_OutputStream_r2t(self);
  R2TAO_TRY {
    CORBA::Any* any = 0;
    ACE_NEW_THROW_EX (any,
                      CORBA::Any (),
                      CORBA::NO_MEMORY());
    CORBA::Any_var any_safe = any;
    CORBA::Short sh = NIL_P (rval) ? 0 : NUM2INT (rval);
    *any <<= sh;
    if (!vt->add_chunk_element (any_safe))
      throw CORBA::MARSHAL ();
  } R2TAO_CATCH;
  return Qnil;
}

VALUE r2tao_OStream_write_ushort (VALUE self, VALUE rval)
{
  R2TAO_Value* vt = r2tao_OutputStream_r2t(self);
  R2TAO_TRY {
    CORBA::Any* any = 0;
    ACE_NEW_THROW_EX (any,
                      CORBA::Any (),
                      CORBA::NO_MEMORY());
    CORBA::Any_var any_safe = any;
    CORBA::UShort ush = NIL_P (rval) ? 0 : NUM2UINT (rval);
    *any <<= ush;
    if (!vt->add_chunk_element (any_safe))
      throw CORBA::MARSHAL ();
  } R2TAO_CATCH;
  return Qnil;
}

VALUE r2tao_OStream_write_long (VALUE self, VALUE rval)
{
  R2TAO_Value* vt = r2tao_OutputStream_r2t(self);
  R2TAO_TRY {
    CORBA::Any* any = 0;
    ACE_NEW_THROW_EX (any,
                      CORBA::Any (),
                      CORBA::NO_MEMORY());
    CORBA::Any_var any_safe = any;
    CORBA::Long l = NIL_P (rval) ? 0 : NUM2LONG (rval);
    *any <<= l;
    if (!vt->add_chunk_element (any_safe))
      throw CORBA::MARSHAL ();
  } R2TAO_CATCH;
  return Qnil;
}

VALUE r2tao_OStream_write_ulong (VALUE self, VALUE rval)
{
  R2TAO_Value* vt = r2tao_OutputStream_r2t(self);
  R2TAO_TRY {
    CORBA::Any* any = 0;
    ACE_NEW_THROW_EX (any,
                      CORBA::Any (),
                      CORBA::NO_MEMORY());
    CORBA::Any_var any_safe = any;
    CORBA::ULong ul = NIL_P (rval) ? 0 : NUM2ULONG (rval);
    *any <<= ul;
    if (!vt->add_chunk_element (any_safe))
      throw CORBA::MARSHAL ();
  } R2TAO_CATCH;
  return Qnil;
}

VALUE r2tao_OStream_write_longlong (VALUE self, VALUE rval)
{
  R2TAO_Value* vt = r2tao_OutputStream_r2t(self);
  R2TAO_TRY {
    CORBA::Any* any = 0;
    ACE_NEW_THROW_EX (any,
                      CORBA::Any (),
                      CORBA::NO_MEMORY());
    CORBA::Any_var any_safe = any;
    CORBA::LongLong ll = NIL_P (rval) ? 0 : NUM2LL (rval);
    *any <<= ll;
    if (!vt->add_chunk_element (any_safe))
      throw CORBA::MARSHAL ();
  } R2TAO_CATCH;
  return Qnil;
}

VALUE r2tao_OStream_write_ulonglong (VALUE self, VALUE rval)
{
  R2TAO_Value* vt = r2tao_OutputStream_r2t(self);
  R2TAO_TRY {
    CORBA::Any* any = 0;
    ACE_NEW_THROW_EX (any,
                      CORBA::Any (),
                      CORBA::NO_MEMORY());
    CORBA::Any_var any_safe = any;
    CORBA::ULongLong ull = NIL_P (rval) ? 0 : NUM2ULL (rval);
    *any <<= ull;
    if (!vt->add_chunk_element (any_safe))
      throw CORBA::MARSHAL ();
  } R2TAO_CATCH;
  return Qnil;
}

VALUE r2tao_OStream_write_float (VALUE self, VALUE rval)
{
  R2TAO_Value* vt = r2tao_OutputStream_r2t(self);
  R2TAO_TRY {
    CORBA::Any* any = 0;
    ACE_NEW_THROW_EX (any,
                      CORBA::Any (),
                      CORBA::NO_MEMORY());
    CORBA::Any_var any_safe = any;
    CORBA::Float f = NIL_P (rval) ? 0.0f : (CORBA::Float)NUM2DBL (rval);
    *any <<= f;
    if (!vt->add_chunk_element (any_safe))
      throw CORBA::MARSHAL ();
  } R2TAO_CATCH;
  return Qnil;
}

VALUE r2tao_OStream_write_double (VALUE self, VALUE rval)
{
  R2TAO_Value* vt = r2tao_OutputStream_r2t(self);
  R2TAO_TRY {
    CORBA::Any* any = 0;
    ACE_NEW_THROW_EX (any,
                      CORBA::Any (),
                      CORBA::NO_MEMORY());
    CORBA::Any_var any_safe = any;
    CORBA::Double d = NIL_P (rval) ? 0.0 : NUM2DBL (rval);
    *any <<= d;
    if (!vt->add_chunk_element (any_safe))
      throw CORBA::MARSHAL ();
  } R2TAO_CATCH;
  return Qnil;
}

VALUE r2tao_OStream_write_longdouble (VALUE self, VALUE rval)
{
  R2TAO_Value* vt = r2tao_OutputStream_r2t(self);
  R2TAO_TRY {
    CORBA::Any* any = 0;
    ACE_NEW_THROW_EX (any,
                      CORBA::Any (),
                      CORBA::NO_MEMORY());
    CORBA::Any_var any_safe = any;
    CORBA::LongDouble ld;
    ACE_CDR_LONG_DOUBLE_ASSIGNMENT (ld, NIL_P (rval) ? 0.0 : RLD2CLD (rval));
    *any <<= ld;
    if (!vt->add_chunk_element (any_safe))
      throw CORBA::MARSHAL ();
  } R2TAO_CATCH;
  return Qnil;
}

VALUE r2tao_OStream_write_Object (VALUE self, VALUE rval)
{
  R2TAO_Value* vt = r2tao_OutputStream_r2t(self);
  R2TAO_TRY {
    CORBA::Any* any = 0;
    ACE_NEW_THROW_EX (any,
                      CORBA::Any (),
                      CORBA::NO_MEMORY());
    CORBA::Any_var any_safe = any;
    if (!NIL_P (rval))
    {
      *any <<= r2corba_Object_r2t (rval);
    }
    else
    {
      *any <<= CORBA::Object::_nil ();
    }
    if (!vt->add_chunk_element (any_safe))
      throw CORBA::MARSHAL ();
  } R2TAO_CATCH;
  return Qnil;
}

VALUE r2tao_OStream_write_Abstract (VALUE self, VALUE rval)
{
  R2TAO_Value* vt = r2tao_OutputStream_r2t(self);
  R2TAO_TRY {
    CORBA::Any* any = 0;
    ACE_NEW_THROW_EX (any,
                      CORBA::Any (),
                      CORBA::NO_MEMORY());
    CORBA::Any_var any_safe = any;
    if (rval == Qnil)
    {
      TAO::Any_Impl_T<CORBA::AbstractBase>::insert (
          *any,
          CORBA::AbstractBase::_tao_any_destructor,
          CORBA::TypeCode::_nil (), // irrelevant in this case
          0);
    }
    else
    {
      r2tao_Ruby_to_Any(*any, rval);
    }
    if (!vt->add_chunk_element (any_safe))
      throw CORBA::MARSHAL ();
  } R2TAO_CATCH;
  return Qnil;
}

VALUE r2tao_OStream_write_Value (VALUE self, VALUE rval)
{
  R2TAO_Value* vt = r2tao_OutputStream_r2t(self);
  R2TAO_TRY {
    CORBA::Any* any = 0;
    ACE_NEW_THROW_EX (any,
                      CORBA::Any (),
                      CORBA::NO_MEMORY());
    CORBA::Any_var any_safe = any;
    if (rval == Qnil)
    {
      TAO::Any_Impl_T<R2TAO_Value>::insert (
          *any,
          R2TAO_Value::_tao_any_destructor,
          CORBA::TypeCode::_nil (), // irrelevant in this case
          0);
    }
    else
    {
      r2tao_Ruby_to_Any(*any, rval);
    }
    if (!vt->add_chunk_element (any_safe))
      throw CORBA::MARSHAL ();
  } R2TAO_CATCH;
  return Qnil;
}

VALUE r2tao_OStream_write_TypeCode (VALUE self, VALUE rval)
{
  R2TAO_Value* vt = r2tao_OutputStream_r2t(self);
  R2TAO_TRY {
    CORBA::Any* any = 0;
    ACE_NEW_THROW_EX (any,
                      CORBA::Any (),
                      CORBA::NO_MEMORY());
    CORBA::Any_var any_safe = any;
    if (!NIL_P (rval))
    {
      CORBA::TypeCode_ptr tctc = r2corba_TypeCode_r2t (rval);
      *any <<= tctc;
    }
    else
    {
      *any <<= CORBA::TypeCode::_nil ();
    }
    if (!vt->add_chunk_element (any_safe))
      throw CORBA::MARSHAL ();
  } R2TAO_CATCH;
  return Qnil;
}

VALUE r2tao_OStream_write_fixed (VALUE , VALUE )
{
  X_CORBA (NO_IMPLEMENT);
}

VALUE r2tao_OStream_write_string (VALUE self, VALUE rval)
{
  R2TAO_Value* vt = r2tao_OutputStream_r2t(self);
  R2TAO_TRY {
    CORBA::Any* any = 0;
    ACE_NEW_THROW_EX (any,
                      CORBA::Any (),
                      CORBA::NO_MEMORY());
    CORBA::Any_var any_safe = any;
    if (NIL_P (rval))
    {
      *any <<= (char*)0;
    }
    else
    {
      CHECK_RTYPE(rval, T_STRING);
      *any <<= RSTRING_PTR (rval);
    }
    if (!vt->add_chunk_element (any_safe))
      throw CORBA::MARSHAL ();
  } R2TAO_CATCH;
  return Qnil;
}

VALUE r2tao_OStream_write_wstring (VALUE self, VALUE rval)
{
  R2TAO_Value* vt = r2tao_OutputStream_r2t(self);
  R2TAO_TRY {
    CORBA::Any* any = 0;
    ACE_NEW_THROW_EX (any,
                      CORBA::Any (),
                      CORBA::NO_MEMORY());
    CORBA::Any_var any_safe = any;
    if (NIL_P (rval))
    {
      *any <<= (CORBA::WChar*)0;
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
      *any <<= ws;
    }
    if (!vt->add_chunk_element (any_safe))
      throw CORBA::MARSHAL ();
  } R2TAO_CATCH;
  return Qnil;
}

VALUE r2tao_OStream_write_any_array (VALUE self, VALUE rval, VALUE offset, VALUE length)
{
  R2TAO_Value* vt = r2tao_OutputStream_r2t(self);
  R2TAO_TRY {
    CORBA::Any* any = 0;
    ACE_NEW_THROW_EX (any,
                      CORBA::Any (),
                      CORBA::NO_MEMORY());
    CORBA::Any_var any_safe = any;

    CHECK_RTYPE(rval, T_ARRAY);
    CORBA::ULong asz = static_cast<unsigned long> (RARRAY_LEN (rval));
    CORBA::ULong offs = NUM2ULONG (offset);
    CORBA::ULong alen = NUM2ULONG (length);
    CORBA::ULong len = ((offs + alen) <= asz) ? alen : (offs < asz ? (asz - offs) : 0);
    if (len > 0)
    {
      CORBA::Any* any_array = 0;
      ACE_NEW_THROW_EX (any_array,
                        CORBA::Any[len],
                        CORBA::NO_MEMORY());
      ACE_Auto_Ptr<CORBA::Any> any_array_safe (any_array);
      for (CORBA::ULong l=0; l<len ;++l)
      {
        VALUE rel = rb_ary_entry (rval, offs+l);
        r2tao_Ruby_to_Any(any_array[l], rel);
      }
      R2TAO_ArrayAny_Impl_T<CORBA::Any>::insert (*any,
                                                 CORBA::_tc_any,
                                                 any_array_safe.release (),
                                                 len);

      if (!vt->add_chunk_element (any_safe))
        throw CORBA::MARSHAL ();
    }
  } R2TAO_CATCH;
  return Qnil;
}

VALUE r2tao_OStream_write_boolean_array (VALUE self, VALUE rval, VALUE offset, VALUE length)
{
  R2TAO_Value* vt = r2tao_OutputStream_r2t(self);
  R2TAO_TRY {
    CORBA::Any* any = 0;
    ACE_NEW_THROW_EX (any,
                      CORBA::Any (),
                      CORBA::NO_MEMORY());
    CORBA::Any_var any_safe = any;

    CHECK_RTYPE(rval, T_ARRAY);
    CORBA::ULong asz = static_cast<unsigned long> (RARRAY_LEN (rval));
    CORBA::ULong offs = NUM2ULONG (offset);
    CORBA::ULong alen = NUM2ULONG (length);
    CORBA::ULong len = ((offs + alen) <= asz) ? alen : (offs < asz ? (asz - offs) : 0);
    if (len > 0)
    {
      CORBA::Boolean* native_array = 0;
      ACE_NEW_THROW_EX (native_array,
                        CORBA::Boolean[len],
                        CORBA::NO_MEMORY());
      ACE_Auto_Ptr<CORBA::Boolean> native_array_safe (native_array);
      for (CORBA::ULong l=0; l<len ;++l)
      {
        VALUE rel = rb_ary_entry (rval, offs+l);
        native_array[l] = (NIL_P (rel) || rel == Qfalse) ? 0 : 1;
      }
      R2TAO_ArrayAny_Impl_T<CORBA::Boolean>::insert (*any,
                                                     CORBA::_tc_boolean,
                                                     native_array_safe.release (),
                                                     len);

      if (!vt->add_chunk_element (any_safe))
        throw CORBA::MARSHAL ();
    }
  } R2TAO_CATCH;
  return Qnil;
}

VALUE r2tao_OStream_write_char_array (VALUE self, VALUE rval, VALUE offset, VALUE length)
{
  R2TAO_Value* vt = r2tao_OutputStream_r2t(self);
  R2TAO_TRY {
    CORBA::Any* any = 0;
    ACE_NEW_THROW_EX (any,
                      CORBA::Any (),
                      CORBA::NO_MEMORY());
    CORBA::Any_var any_safe = any;

    CHECK_RTYPE(rval, T_STRING);
    CORBA::ULong asz = static_cast<unsigned long> (RSTRING_LEN (rval));
    CORBA::ULong offs = NUM2ULONG (offset);
    CORBA::ULong alen = NUM2ULONG (length);
    CORBA::ULong len = ((offs + alen) <= asz) ? alen : (offs < asz ? (asz - offs) : 0);
    if (len > 0)
    {
      CORBA::Char* native_array = 0;
      ACE_NEW_THROW_EX (native_array,
                        CORBA::Char[len],
                        CORBA::NO_MEMORY());
      ACE_Auto_Ptr<CORBA::Char> native_array_safe (native_array);
      char* s = RSTRING_PTR (rval);
      for (CORBA::ULong l=0; l<len ;++l)
      {
        native_array[l] = s[offs+l];
      }
      R2TAO_ArrayAny_Impl_T<CORBA::Char>::insert (*any,
                                                     CORBA::_tc_char,
                                                     native_array_safe.release (),
                                                     len);

      if (!vt->add_chunk_element (any_safe))
        throw CORBA::MARSHAL ();
    }
  } R2TAO_CATCH;
  return Qnil;
}

VALUE r2tao_OStream_write_wchar_array (VALUE self, VALUE rval, VALUE offset, VALUE length)
{
  R2TAO_Value* vt = r2tao_OutputStream_r2t(self);
  R2TAO_TRY {
    CORBA::Any* any = 0;
    ACE_NEW_THROW_EX (any,
                      CORBA::Any (),
                      CORBA::NO_MEMORY());
    CORBA::Any_var any_safe = any;

    CHECK_RTYPE(rval, T_ARRAY);
    CORBA::ULong asz = static_cast<unsigned long> (RARRAY_LEN (rval));
    CORBA::ULong offs = NUM2ULONG (offset);
    CORBA::ULong alen = NUM2ULONG (length);
    CORBA::ULong len = ((offs + alen) <= asz) ? alen : (offs < asz ? (asz - offs) : 0);
    if (len > 0)
    {
      CORBA::WChar* native_array = 0;
      ACE_NEW_THROW_EX (native_array,
                        CORBA::WChar[len],
                        CORBA::NO_MEMORY());
      ACE_Auto_Ptr<CORBA::WChar> native_array_safe (native_array);
      for (CORBA::ULong l=0; l<len ;++l)
      {
        VALUE rel = rb_ary_entry (rval, offs+l);
        native_array[l] = (CORBA::WChar)NUM2INT (rel);
      }
      R2TAO_ArrayAny_Impl_T<CORBA::WChar>::insert (*any,
                                                   CORBA::_tc_wchar,
                                                   native_array_safe.release (),
                                                   len);

      if (!vt->add_chunk_element (any_safe))
        throw CORBA::MARSHAL ();
    }
  } R2TAO_CATCH;
  return Qnil;
}

VALUE r2tao_OStream_write_octet_array (VALUE self, VALUE rval, VALUE offset, VALUE length)
{
  R2TAO_Value* vt = r2tao_OutputStream_r2t(self);
  R2TAO_TRY {
    CORBA::Any* any = 0;
    ACE_NEW_THROW_EX (any,
                      CORBA::Any (),
                      CORBA::NO_MEMORY());
    CORBA::Any_var any_safe = any;

    CHECK_RTYPE(rval, T_STRING);
    CORBA::ULong asz = static_cast<unsigned long> (RSTRING_LEN (rval));
    CORBA::ULong offs = NUM2ULONG (offset);
    CORBA::ULong alen = NUM2ULONG (length);
    CORBA::ULong len = ((offs + alen) <= asz) ? alen : (offs < asz ? (asz - offs) : 0);
    if (len > 0)
    {
      CORBA::Octet* native_array = 0;
      ACE_NEW_THROW_EX (native_array,
                        CORBA::Octet[len],
                        CORBA::NO_MEMORY());
      ACE_Auto_Ptr<CORBA::Octet> native_array_safe (native_array);
      unsigned char* s = (unsigned char*)RSTRING_PTR (rval);
      for (CORBA::ULong l=0; l<len ;++l)
      {
        native_array[l] = s[offs+l];
      }
      R2TAO_ArrayAny_Impl_T<CORBA::Octet>::insert (*any,
                                                   CORBA::_tc_octet,
                                                   native_array_safe.release (),
                                                   len);

      if (!vt->add_chunk_element (any_safe))
        throw CORBA::MARSHAL ();
    }
  } R2TAO_CATCH;
  return Qnil;
}

VALUE r2tao_OStream_write_short_array (VALUE self, VALUE rval, VALUE offset, VALUE length)
{
  R2TAO_Value* vt = r2tao_OutputStream_r2t(self);
  R2TAO_TRY {
    CORBA::Any* any = 0;
    ACE_NEW_THROW_EX (any,
                      CORBA::Any (),
                      CORBA::NO_MEMORY());
    CORBA::Any_var any_safe = any;

    CHECK_RTYPE(rval, T_ARRAY);
    CORBA::ULong asz = static_cast<unsigned long> (RARRAY_LEN (rval));
    CORBA::ULong offs = NUM2ULONG (offset);
    CORBA::ULong alen = NUM2ULONG (length);
    CORBA::ULong len = ((offs + alen) <= asz) ? alen : (offs < asz ? (asz - offs) : 0);
    if (len > 0)
    {
      CORBA::Short* native_array = 0;
      ACE_NEW_THROW_EX (native_array,
                        CORBA::Short[len],
                        CORBA::NO_MEMORY());
      ACE_Auto_Ptr<CORBA::Short> native_array_safe (native_array);
      for (CORBA::ULong l=0; l<len ;++l)
      {
        VALUE rel = rb_ary_entry (rval, offs+l);
        native_array[l] = (CORBA::Short)NUM2INT (rel);
      }
      R2TAO_ArrayAny_Impl_T<CORBA::Short>::insert (*any,
                                                   CORBA::_tc_short,
                                                   native_array_safe.release (),
                                                   len);

      if (!vt->add_chunk_element (any_safe))
        throw CORBA::MARSHAL ();
    }
  } R2TAO_CATCH;
  return Qnil;
}

VALUE r2tao_OStream_write_ushort_array (VALUE self, VALUE rval, VALUE offset, VALUE length)
{
  R2TAO_Value* vt = r2tao_OutputStream_r2t(self);
  R2TAO_TRY {
    CORBA::Any* any = 0;
    ACE_NEW_THROW_EX (any,
                      CORBA::Any (),
                      CORBA::NO_MEMORY());
    CORBA::Any_var any_safe = any;

    CHECK_RTYPE(rval, T_ARRAY);
    CORBA::ULong asz = static_cast<unsigned long> (RARRAY_LEN (rval));
    CORBA::ULong offs = NUM2ULONG (offset);
    CORBA::ULong alen = NUM2ULONG (length);
    CORBA::ULong len = ((offs + alen) <= asz) ? alen : (offs < asz ? (asz - offs) : 0);
    if (len > 0)
    {
      CORBA::UShort* native_array = 0;
      ACE_NEW_THROW_EX (native_array,
                        CORBA::UShort[len],
                        CORBA::NO_MEMORY());
      ACE_Auto_Ptr<CORBA::UShort> native_array_safe (native_array);
      for (CORBA::ULong l=0; l<len ;++l)
      {
        VALUE rel = rb_ary_entry (rval, offs+l);
        native_array[l] = (CORBA::UShort)NUM2UINT (rel);
      }
      R2TAO_ArrayAny_Impl_T<CORBA::UShort>::insert (*any,
                                                   CORBA::_tc_ushort,
                                                   native_array_safe.release (),
                                                   len);

      if (!vt->add_chunk_element (any_safe))
        throw CORBA::MARSHAL ();
    }
  } R2TAO_CATCH;
  return Qnil;
}

VALUE r2tao_OStream_write_long_array (VALUE self, VALUE rval, VALUE offset, VALUE length)
{
  R2TAO_Value* vt = r2tao_OutputStream_r2t(self);
  R2TAO_TRY {
    CORBA::Any* any = 0;
    ACE_NEW_THROW_EX (any,
                      CORBA::Any (),
                      CORBA::NO_MEMORY());
    CORBA::Any_var any_safe = any;

    CHECK_RTYPE(rval, T_ARRAY);
    CORBA::ULong asz = static_cast<unsigned long> (RARRAY_LEN (rval));
    CORBA::ULong offs = NUM2ULONG (offset);
    CORBA::ULong alen = NUM2ULONG (length);
    CORBA::ULong len = ((offs + alen) <= asz) ? alen : (offs < asz ? (asz - offs) : 0);
    if (len > 0)
    {
      CORBA::Long* native_array = 0;
      ACE_NEW_THROW_EX (native_array,
                        CORBA::Long[len],
                        CORBA::NO_MEMORY());
      ACE_Auto_Ptr<CORBA::Long> native_array_safe (native_array);
      for (CORBA::ULong l=0; l<len ;++l)
      {
        VALUE rel = rb_ary_entry (rval, offs+l);
        native_array[l] = (CORBA::Long)NUM2LONG (rel);
      }
      R2TAO_ArrayAny_Impl_T<CORBA::Long>::insert (*any,
                                                   CORBA::_tc_long,
                                                   native_array_safe.release (),
                                                   len);

      if (!vt->add_chunk_element (any_safe))
        throw CORBA::MARSHAL ();
    }
  } R2TAO_CATCH;
  return Qnil;
}

VALUE r2tao_OStream_write_ulong_array (VALUE self, VALUE rval, VALUE offset, VALUE length)
{
  R2TAO_Value* vt = r2tao_OutputStream_r2t(self);
  R2TAO_TRY {
    CORBA::Any* any = 0;
    ACE_NEW_THROW_EX (any,
                      CORBA::Any (),
                      CORBA::NO_MEMORY());
    CORBA::Any_var any_safe = any;

    CHECK_RTYPE(rval, T_ARRAY);
    CORBA::ULong asz = static_cast<unsigned long> (RARRAY_LEN (rval));
    CORBA::ULong offs = NUM2ULONG (offset);
    CORBA::ULong alen = NUM2ULONG (length);
    CORBA::ULong len = ((offs + alen) <= asz) ? alen : (offs < asz ? (asz - offs) : 0);
    if (len > 0)
    {
      CORBA::ULong* native_array = 0;
      ACE_NEW_THROW_EX (native_array,
                        CORBA::ULong[len],
                        CORBA::NO_MEMORY());
      ACE_Auto_Ptr<CORBA::ULong> native_array_safe (native_array);
      for (CORBA::ULong l=0; l<len ;++l)
      {
        VALUE rel = rb_ary_entry (rval, offs+l);
        native_array[l] = (CORBA::ULong)NUM2ULONG (rel);
      }
      R2TAO_ArrayAny_Impl_T<CORBA::ULong>::insert (*any,
                                                   CORBA::_tc_ulong,
                                                   native_array_safe.release (),
                                                   len);

      if (!vt->add_chunk_element (any_safe))
        throw CORBA::MARSHAL ();
    }
  } R2TAO_CATCH;
  return Qnil;
}

VALUE r2tao_OStream_write_longlong_array (VALUE self, VALUE rval, VALUE offset, VALUE length)
{
  R2TAO_Value* vt = r2tao_OutputStream_r2t(self);
  R2TAO_TRY {
    CORBA::Any* any = 0;
    ACE_NEW_THROW_EX (any,
                      CORBA::Any (),
                      CORBA::NO_MEMORY());
    CORBA::Any_var any_safe = any;

    CHECK_RTYPE(rval, T_ARRAY);
    CORBA::ULong asz = static_cast<unsigned long> (RARRAY_LEN (rval));
    CORBA::ULong offs = NUM2ULONG (offset);
    CORBA::ULong alen = NUM2ULONG (length);
    CORBA::ULong len = ((offs + alen) <= asz) ? alen : (offs < asz ? (asz - offs) : 0);
    if (len > 0)
    {
      CORBA::LongLong* native_array = 0;
      ACE_NEW_THROW_EX (native_array,
                        CORBA::LongLong[len],
                        CORBA::NO_MEMORY());
      ACE_Auto_Ptr<CORBA::LongLong> native_array_safe (native_array);
      for (CORBA::ULong l=0; l<len ;++l)
      {
        VALUE rel = rb_ary_entry (rval, offs+l);
        native_array[l] = (CORBA::LongLong)NUM2LL (rel);
      }
      R2TAO_ArrayAny_Impl_T<CORBA::LongLong>::insert (*any,
                                                      CORBA::_tc_longlong,
                                                      native_array_safe.release (),
                                                      len);

      if (!vt->add_chunk_element (any_safe))
        throw CORBA::MARSHAL ();
    }
  } R2TAO_CATCH;
  return Qnil;
}

VALUE r2tao_OStream_write_ulonglong_array (VALUE self, VALUE rval, VALUE offset, VALUE length)
{
  R2TAO_Value* vt = r2tao_OutputStream_r2t(self);
  R2TAO_TRY {
    CORBA::Any* any = 0;
    ACE_NEW_THROW_EX (any,
                      CORBA::Any (),
                      CORBA::NO_MEMORY());
    CORBA::Any_var any_safe = any;

    CHECK_RTYPE(rval, T_ARRAY);
    CORBA::ULong asz = static_cast<unsigned long> (RARRAY_LEN (rval));
    CORBA::ULong offs = NUM2ULONG (offset);
    CORBA::ULong alen = NUM2ULONG (length);
    CORBA::ULong len = ((offs + alen) <= asz) ? alen : (offs < asz ? (asz - offs) : 0);
    if (len > 0)
    {
      CORBA::ULongLong* native_array = 0;
      ACE_NEW_THROW_EX (native_array,
                        CORBA::ULongLong[len],
                        CORBA::NO_MEMORY());
      ACE_Auto_Ptr<CORBA::ULongLong> native_array_safe (native_array);
      for (CORBA::ULong l=0; l<len ;++l)
      {
        VALUE rel = rb_ary_entry (rval, offs+l);
        native_array[l] = (CORBA::ULongLong)NUM2ULL (rel);
      }
      R2TAO_ArrayAny_Impl_T<CORBA::ULongLong>::insert (*any,
                                                       CORBA::_tc_ulonglong,
                                                       native_array_safe.release (),
                                                       len);

      if (!vt->add_chunk_element (any_safe))
        throw CORBA::MARSHAL ();
    }
  } R2TAO_CATCH;
  return Qnil;
}

VALUE r2tao_OStream_write_float_array (VALUE self, VALUE rval, VALUE offset, VALUE length)
{
  R2TAO_Value* vt = r2tao_OutputStream_r2t(self);
  R2TAO_TRY {
    CORBA::Any* any = 0;
    ACE_NEW_THROW_EX (any,
                      CORBA::Any (),
                      CORBA::NO_MEMORY());
    CORBA::Any_var any_safe = any;

    CHECK_RTYPE(rval, T_ARRAY);
    CORBA::ULong asz = static_cast<unsigned long> (RARRAY_LEN (rval));
    CORBA::ULong offs = NUM2ULONG (offset);
    CORBA::ULong alen = NUM2ULONG (length);
    CORBA::ULong len = ((offs + alen) <= asz) ? alen : (offs < asz ? (asz - offs) : 0);
    if (len > 0)
    {
      CORBA::Float* native_array = 0;
      ACE_NEW_THROW_EX (native_array,
                        CORBA::Float[len],
                        CORBA::NO_MEMORY());
      ACE_Auto_Ptr<CORBA::Float> native_array_safe (native_array);
      for (CORBA::ULong l=0; l<len ;++l)
      {
        VALUE rel = rb_ary_entry (rval, offs+l);
        native_array[l] = (CORBA::Float)NUM2DBL (rel);
      }
      R2TAO_ArrayAny_Impl_T<CORBA::Float>::insert (*any,
                                                   CORBA::_tc_float,
                                                   native_array_safe.release (),
                                                   len);

      if (!vt->add_chunk_element (any_safe))
        throw CORBA::MARSHAL ();
    }
  } R2TAO_CATCH;
  return Qnil;
}

VALUE r2tao_OStream_write_double_array (VALUE self, VALUE rval, VALUE offset, VALUE length)
{
  R2TAO_Value* vt = r2tao_OutputStream_r2t(self);
  R2TAO_TRY {
    CORBA::Any* any = 0;
    ACE_NEW_THROW_EX (any,
                      CORBA::Any (),
                      CORBA::NO_MEMORY());
    CORBA::Any_var any_safe = any;

    CHECK_RTYPE(rval, T_ARRAY);
    CORBA::ULong asz = static_cast<unsigned long> (RARRAY_LEN (rval));
    CORBA::ULong offs = NUM2ULONG (offset);
    CORBA::ULong alen = NUM2ULONG (length);
    CORBA::ULong len = ((offs + alen) <= asz) ? alen : (offs < asz ? (asz - offs) : 0);
    if (len > 0)
    {
      CORBA::Double* native_array = 0;
      ACE_NEW_THROW_EX (native_array,
                        CORBA::Double[len],
                        CORBA::NO_MEMORY());
      ACE_Auto_Ptr<CORBA::Double> native_array_safe (native_array);
      for (CORBA::ULong l=0; l<len ;++l)
      {
        VALUE rel = rb_ary_entry (rval, offs+l);
        native_array[l] = (CORBA::Double)NUM2DBL (rel);
      }
      R2TAO_ArrayAny_Impl_T<CORBA::Double>::insert (*any,
                                                    CORBA::_tc_double,
                                                    native_array_safe.release (),
                                                    len);

      if (!vt->add_chunk_element (any_safe))
        throw CORBA::MARSHAL ();
    }
  } R2TAO_CATCH;
  return Qnil;
}

VALUE r2tao_OStream_write_longdouble_array (VALUE self, VALUE rval, VALUE offset, VALUE length)
{
  R2TAO_Value* vt = r2tao_OutputStream_r2t(self);
  R2TAO_TRY {
    CORBA::Any* any = 0;
    ACE_NEW_THROW_EX (any,
                      CORBA::Any (),
                      CORBA::NO_MEMORY());
    CORBA::Any_var any_safe = any;

    CHECK_RTYPE(rval, T_ARRAY);
    CORBA::ULong asz = static_cast<unsigned long> (RARRAY_LEN (rval));
    CORBA::ULong offs = NUM2ULONG (offset);
    CORBA::ULong alen = NUM2ULONG (length);
    CORBA::ULong len = ((offs + alen) <= asz) ? alen : (offs < asz ? (asz - offs) : 0);
    if (len > 0)
    {
      CORBA::LongDouble* native_array = 0;
      ACE_NEW_THROW_EX (native_array,
                        CORBA::LongDouble[len],
                        CORBA::NO_MEMORY());
      ACE_Auto_Ptr<CORBA::LongDouble> native_array_safe (native_array);
      for (CORBA::ULong l=0; l<len ;++l)
      {
        VALUE rel = rb_ary_entry (rval, offs+l);
        ACE_CDR_LONG_DOUBLE_ASSIGNMENT (native_array[l], CLD2RLD (rel));
      }
      R2TAO_ArrayAny_Impl_T<CORBA::LongDouble>::insert (*any,
                                                        CORBA::_tc_longdouble,
                                                        native_array_safe.release (),
                                                        len);

      if (!vt->add_chunk_element (any_safe))
        throw CORBA::MARSHAL ();
    }
  } R2TAO_CATCH;
  return Qnil;
}

VALUE r2tao_OStream_write_fixed_array (VALUE , VALUE , VALUE , VALUE )
{
  X_CORBA (NO_IMPLEMENT);
}

VALUE r2tao_OStream_write_construct (VALUE self, VALUE rval, VALUE rtc)
{
  R2TAO_Value* val = r2tao_OutputStream_r2t(self);
  R2TAO_TRY {
    CORBA::TypeCode_ptr tc_ = r2corba_TypeCode_r2t (rtc);

    CORBA::Any* any = 0;
    ACE_NEW_THROW_EX (any,
                      CORBA::Any (),
                      CORBA::NO_MEMORY());
    CORBA::Any_var any_safe = any;
    r2tao_Ruby2Any (*any, tc_, rval);
    if (!val->add_chunk_element (any_safe))
      throw CORBA::MARSHAL ();
  } R2TAO_CATCH;
  return Qnil;
}

// ------------------------------------------------------------------
// InputStream

VALUE r2tao_IStream_read_any (VALUE self)
{
  VALUE ret = Qnil;
  TAO_InputCDR &strm = *r2tao_InputStream_r2t(self);
  R2TAO_TRY {
    CORBA::Any  any;
    strm >> any;
    ret = r2tao_Any_to_Ruby (any);
  } R2TAO_CATCH;
  return ret;
}

VALUE r2tao_IStream_read_boolean (VALUE self)
{
  VALUE ret = Qnil;
  TAO_InputCDR &strm = *r2tao_InputStream_r2t(self);
  R2TAO_TRY {
    CORBA::Boolean val = false;
    TAO_InputCDR::to_boolean  bool_ (val);
    strm >> bool_;
    ret = val ? Qtrue : Qfalse;
  } R2TAO_CATCH;
  return ret;
}

VALUE r2tao_IStream_read_char (VALUE self)
{
  VALUE ret = Qnil;
  TAO_InputCDR &strm = *r2tao_InputStream_r2t(self);
  R2TAO_TRY {
    CORBA::Char val = 0;
    TAO_InputCDR::to_char  ch_ (val);
    strm >> ch_;
    ret = rb_str_new (&val, 1);
  } R2TAO_CATCH;
  return ret;
}

VALUE r2tao_IStream_read_wchar (VALUE self)
{
  VALUE ret = Qnil;
  TAO_InputCDR &strm = *r2tao_InputStream_r2t(self);
  R2TAO_TRY {
    CORBA::WChar val = 0;
    TAO_InputCDR::to_wchar  wch_ (val);
    strm >> wch_;
    ret = INT2FIX ((int)val);
  } R2TAO_CATCH;
  return ret;
}

VALUE r2tao_IStream_read_octet (VALUE self)
{
  VALUE ret = Qnil;
  TAO_InputCDR &strm = *r2tao_InputStream_r2t(self);
  R2TAO_TRY {
    CORBA::Octet val = 0;
    TAO_InputCDR::to_octet  byte_ (val);
    strm >> byte_;
    ret = INT2FIX ((int)val);
  } R2TAO_CATCH;
  return ret;
}

VALUE r2tao_IStream_read_short (VALUE self)
{
  VALUE ret = Qnil;
  TAO_InputCDR &strm = *r2tao_InputStream_r2t(self);
  R2TAO_TRY {
    CORBA::Short val = 0;
    strm >> val;
    ret = INT2FIX ((int)val);
  } R2TAO_CATCH;
  return ret;
}

VALUE r2tao_IStream_read_ushort (VALUE self)
{
  VALUE ret = Qnil;
  TAO_InputCDR &strm = *r2tao_InputStream_r2t(self);
  R2TAO_TRY {
    CORBA::UShort val = 0;
    strm >> val;
    ret = UINT2NUM ((unsigned int)val);
  } R2TAO_CATCH;
  return ret;
}

VALUE r2tao_IStream_read_long (VALUE self)
{
  VALUE ret = Qnil;
  TAO_InputCDR &strm = *r2tao_InputStream_r2t(self);
  R2TAO_TRY {
    CORBA::Long val = 0;
    strm >> val;
    ret = LONG2FIX (val);
  } R2TAO_CATCH;
  return ret;
}

VALUE r2tao_IStream_read_ulong (VALUE self)
{
  VALUE ret = Qnil;
  TAO_InputCDR &strm = *r2tao_InputStream_r2t(self);
  R2TAO_TRY {
    CORBA::ULong val = 0;
    strm >> val;
    ret = ULONG2NUM (val);
  } R2TAO_CATCH;
  return ret;
}

VALUE r2tao_IStream_read_longlong (VALUE self)
{
  VALUE ret = Qnil;
  TAO_InputCDR &strm = *r2tao_InputStream_r2t(self);
  R2TAO_TRY {
    CORBA::LongLong val = 0;
    strm >> val;
    ret = LL2NUM (val);
  } R2TAO_CATCH;
  return ret;
}

VALUE r2tao_IStream_read_ulonglong (VALUE self)
{
  VALUE ret = Qnil;
  TAO_InputCDR &strm = *r2tao_InputStream_r2t(self);
  R2TAO_TRY {
    CORBA::ULongLong val = 0;
    strm >> val;
    ret = ULL2NUM (val);
  } R2TAO_CATCH;
  return ret;
}

VALUE r2tao_IStream_read_float (VALUE self)
{
  VALUE ret = Qnil;
  TAO_InputCDR &strm = *r2tao_InputStream_r2t(self);
  R2TAO_TRY {
    CORBA::Float val = 0;
    strm >> val;
    ret = rb_float_new ((double)val);
  } R2TAO_CATCH;
  return ret;
}

VALUE r2tao_IStream_read_double (VALUE self)
{
  VALUE ret = Qnil;
  TAO_InputCDR &strm = *r2tao_InputStream_r2t(self);
  R2TAO_TRY {
    CORBA::Double val = 0;
    strm >> val;
    ret = rb_float_new ((double)val);
  } R2TAO_CATCH;
  return ret;
}

VALUE r2tao_IStream_read_longdouble (VALUE self)
{
  VALUE ret = Qnil;
  TAO_InputCDR &strm = *r2tao_InputStream_r2t(self);
  R2TAO_TRY {
    CORBA::LongDouble val;
    strm >> val;
    ret = CLD2RLD (val);
  } R2TAO_CATCH;
  return ret;
}

VALUE r2tao_IStream_read_Object (VALUE self)
{
  VALUE ret = Qnil;
  TAO_InputCDR &strm = *r2tao_InputStream_r2t(self);
  R2TAO_TRY {
    CORBA::Object_var val;
    strm >> val;
    if (CORBA::is_nil (val.in ()))
      ret = Qnil;
    else
      ret = r2corba_Object_t2r(val.in ());
  } R2TAO_CATCH;
  return ret;
}

VALUE r2tao_IStream_read_Abstract (VALUE self)
{
  VALUE ret = Qnil;
  TAO_InputCDR &strm = *r2tao_InputStream_r2t(self);
  CORBA::Boolean val = false;
  R2TAO_TRY {
    TAO_InputCDR::to_boolean  bool_ (val);
    strm >> bool_;
  } R2TAO_CATCH;
  if (val)
  {
    // Object
    ret = r2tao_IStream_read_Object (self);
  }
  else
  {
    // Value
    ret = r2tao_IStream_read_Value (self);
  }
  return ret;
}

VALUE r2tao_IStream_read_Value (VALUE self)
{
  VALUE ret = Qnil;
  TAO_InputCDR &strm = *r2tao_InputStream_r2t(self);
  R2TAO_TRY {
    R2TAO_Value_var val;
    strm >> val.out ();
    if (!CORBA::is_nil (val.in ()))
      ret = val.in ()->get_ruby_value ();

    //CORBA::ValueBase_var val;
    //strm >> val.out ();
    //if (!CORBA::is_nil (val.in ()))
    //  ret = R2TAO_Value::_downcast (val.in ())->get_ruby_value ();
  } R2TAO_CATCH;
  return ret;
}

VALUE r2tao_IStream_read_TypeCode (VALUE self)
{
  VALUE ret = Qnil;
  TAO_InputCDR &strm = *r2tao_InputStream_r2t(self);
  R2TAO_TRY {
    CORBA::TypeCode_var val;
    strm >> val.out ();
    if (CORBA::is_nil (val.in ()))
      ret = Qnil;
    else
      ret = r2corba_TypeCode_t2r(val.in ());
  } R2TAO_CATCH;
  return ret;
}

VALUE r2tao_IStream_read_fixed (VALUE)
{
  X_CORBA (NO_IMPLEMENT);
}

VALUE r2tao_IStream_read_string (VALUE self)
{
  VALUE ret = Qnil;
  TAO_InputCDR &strm = *r2tao_InputStream_r2t(self);
  CORBA::Char* val = 0;
  R2TAO_TRY {
    strm >> val;
  } R2TAO_CATCH;
  ret = val ? rb_str_new2 (val) : Qnil;
  return ret;
}

VALUE r2tao_IStream_read_wstring (VALUE self)
{
  VALUE ret = Qnil;
  TAO_InputCDR &strm = *r2tao_InputStream_r2t(self);
  CORBA::WChar* val = 0;
  R2TAO_TRY {
    strm >> val;
  } R2TAO_CATCH;
  if (val == 0)
    return Qnil;
  else
  {
    ret = rb_class_new_instance (0, 0, rb_cArray);
    for (CORBA::ULong l=0; val[l] != CORBA::WChar(0) ;++l)
      rb_ary_push (ret, INT2FIX (val[l]));
  }
  return ret;
}

VALUE r2tao_IStream_read_any_array (VALUE self, VALUE rval, VALUE offset, VALUE length)
{
  TAO_InputCDR &strm = *r2tao_InputStream_r2t(self);
  R2TAO_TRY {
    CHECK_RTYPE(rval, T_ARRAY);
    CORBA::ULong offs = NUM2ULONG (offset);
    CORBA::ULong alen = NUM2ULONG (length);
    for (CORBA::ULong l=0; l<alen ;++l)
    {
      CORBA::Any  any;
      strm >> any;
      VALUE rv = r2tao_Any_to_Ruby (any);
      rb_ary_store (rval, (long)offs+l, rv);
    }
  } R2TAO_CATCH;
  return rval;
}

VALUE r2tao_IStream_read_boolean_array (VALUE self, VALUE rval, VALUE offset, VALUE length)
{
  TAO_InputCDR &strm = *r2tao_InputStream_r2t(self);
  R2TAO_TRY {
    CHECK_RTYPE(rval, T_ARRAY);
    CORBA::ULong offs = NUM2ULONG (offset);
    CORBA::ULong alen = NUM2ULONG (length);
    for (CORBA::ULong l=0; l<alen ;++l)
    {
      CORBA::Boolean val = false;
      TAO_InputCDR::to_boolean  bool_ (val);
      strm >> bool_;
      VALUE rv = val ? Qtrue : Qfalse;
      rb_ary_store (rval, (long)offs+l, rv);
    }
  } R2TAO_CATCH;
  return rval;
}

VALUE r2tao_IStream_read_char_array (VALUE self, VALUE rval, VALUE offset, VALUE length)
{
  TAO_InputCDR &strm = *r2tao_InputStream_r2t(self);
  R2TAO_TRY {
    CHECK_RTYPE(rval, T_STRING);
    CORBA::ULong slen = static_cast<CORBA::ULong> (RSTRING_LEN (rval));
    CORBA::ULong offs = NUM2ULONG (offset);
    CORBA::ULong alen = NUM2ULONG (length);
    CORBA::ULong rlen = slen < (offs + alen) ? (offs + alen) : slen;
    CORBA::String_var str = CORBA::string_alloc (rlen + 1);
    ACE_OS::strncpy (str, RSTRING_PTR (rval), slen < offs ? slen : offs);
    for (CORBA::ULong l=0; l<alen ;++l)
    {
      CORBA::Char val = 0;
      TAO_InputCDR::to_char  ch_ (val);
      strm >> ch_;
      str[offs+l] = val;
    }
    if (slen > (offs + alen))
    {
      ACE_OS::strncpy (&(str[offs+alen]), RSTRING_PTR (rval) + (offs+alen), slen - (offs + alen));
    }
    rb_str_resize (rval, 0);
    rb_str_cat (rval, str.in (), (long)rlen);
  } R2TAO_CATCH;
  return rval;
}

VALUE r2tao_IStream_read_wchar_array (VALUE self, VALUE rval, VALUE offset, VALUE length)
{
  TAO_InputCDR &strm = *r2tao_InputStream_r2t(self);
  R2TAO_TRY {
    CHECK_RTYPE(rval, T_ARRAY);
    CORBA::ULong offs = NUM2ULONG (offset);
    CORBA::ULong alen = NUM2ULONG (length);
    for (CORBA::ULong l=0; l<alen ;++l)
    {
      CORBA::WChar val = 0;
      TAO_InputCDR::to_wchar  wch_ (val);
      strm >> wch_;
      VALUE rv = INT2FIX ((int)val);
      rb_ary_store (rval, (long)offs+l, rv);
    }
  } R2TAO_CATCH;
  return rval;
}

VALUE r2tao_IStream_read_octet_array (VALUE self, VALUE rval, VALUE offset, VALUE length)
{
  TAO_InputCDR &strm = *r2tao_InputStream_r2t(self);
  R2TAO_TRY {
    CHECK_RTYPE(rval, T_STRING);
    CORBA::ULong const slen = static_cast<CORBA::ULong> (RSTRING_LEN (rval));
    CORBA::ULong const offs = NUM2ULONG (offset);
    CORBA::ULong const alen = NUM2ULONG (length);
    CORBA::ULong const rlen = slen < (offs + alen) ? (offs + alen) : slen;
    CORBA::String_var str = CORBA::string_alloc (rlen + 1);
    ACE_OS::strncpy (str.out (), RSTRING_PTR (rval), slen < offs ? slen : offs);
    for (CORBA::ULong l=0; l<alen ;++l)
    {
      CORBA::Char val = 0;
      TAO_InputCDR::to_octet  byte_ ((CORBA::Octet&)val);
      strm >> byte_;
      str[offs+l] = val;
    }
    if (slen > (offs + alen))
    {
      ACE_OS::strncpy (&(str[offs+alen]), RSTRING_PTR (rval) + (offs+alen), slen - (offs + alen));
    }
    rb_str_resize (rval, 0);
    rb_str_cat (rval, str.in (), (long)rlen);
  } R2TAO_CATCH;
  return rval;
}

VALUE r2tao_IStream_read_short_array (VALUE self, VALUE rval, VALUE offset, VALUE length)
{
  TAO_InputCDR &strm = *r2tao_InputStream_r2t(self);
  R2TAO_TRY {
    CHECK_RTYPE(rval, T_ARRAY);
    CORBA::ULong const offs = NUM2ULONG (offset);
    CORBA::ULong const alen = NUM2ULONG (length);
    for (CORBA::ULong l=0; l<alen ;++l)
    {
      CORBA::Short val = 0;
      strm >> val;
      VALUE rv = INT2FIX (val);
      rb_ary_store (rval, (long)offs+l, rv);
    }
  } R2TAO_CATCH;
  return rval;
}

VALUE r2tao_IStream_read_ushort_array (VALUE self, VALUE rval, VALUE offset, VALUE length)
{
  TAO_InputCDR &strm = *r2tao_InputStream_r2t(self);
  R2TAO_TRY {
    CHECK_RTYPE(rval, T_ARRAY);
    CORBA::ULong const offs = NUM2ULONG (offset);
    CORBA::ULong const alen = NUM2ULONG (length);
    for (CORBA::ULong l=0; l<alen ;++l)
    {
      CORBA::UShort val = 0;
      strm >> val;
      VALUE rv = UINT2NUM (val);
      rb_ary_store (rval, (long)offs+l, rv);
    }
  } R2TAO_CATCH;
  return rval;
}

VALUE r2tao_IStream_read_long_array (VALUE self, VALUE rval, VALUE offset, VALUE length)
{
  TAO_InputCDR &strm = *r2tao_InputStream_r2t(self);
  R2TAO_TRY {
    CHECK_RTYPE(rval, T_ARRAY);
    CORBA::ULong offs = NUM2ULONG (offset);
    CORBA::ULong alen = NUM2ULONG (length);
    for (CORBA::ULong l=0; l<alen ;++l)
    {
      CORBA::Long val = 0;
      strm >> val;
      VALUE rv = LONG2FIX (val);
      rb_ary_store (rval, (long)offs+l, rv);
    }
  } R2TAO_CATCH;
  return rval;
}

VALUE r2tao_IStream_read_ulong_array (VALUE self, VALUE rval, VALUE offset, VALUE length)
{
  TAO_InputCDR &strm = *r2tao_InputStream_r2t(self);
  R2TAO_TRY {
    CHECK_RTYPE(rval, T_ARRAY);
    CORBA::ULong offs = NUM2ULONG (offset);
    CORBA::ULong alen = NUM2ULONG (length);
    for (CORBA::ULong l=0; l<alen ;++l)
    {
      CORBA::ULong val = 0;
      strm >> val;
      VALUE rv = ULONG2NUM (val);
      rb_ary_store (rval, (long)offs+l, rv);
    }
  } R2TAO_CATCH;
  return rval;
}

VALUE r2tao_IStream_read_longlong_array (VALUE self, VALUE rval, VALUE offset, VALUE length)
{
  TAO_InputCDR &strm = *r2tao_InputStream_r2t(self);
  R2TAO_TRY {
    CHECK_RTYPE(rval, T_ARRAY);
    CORBA::ULong offs = NUM2ULONG (offset);
    CORBA::ULong alen = NUM2ULONG (length);
    for (CORBA::ULong l=0; l<alen ;++l)
    {
      CORBA::LongLong val = 0;
      strm >> val;
      VALUE rv = LL2NUM (val);
      rb_ary_store (rval, (long)offs+l, rv);
    }
  } R2TAO_CATCH;
  return rval;
}

VALUE r2tao_IStream_read_ulonglong_array (VALUE self, VALUE rval, VALUE offset, VALUE length)
{
  TAO_InputCDR &strm = *r2tao_InputStream_r2t(self);
  R2TAO_TRY {
    CHECK_RTYPE(rval, T_ARRAY);
    CORBA::ULong offs = NUM2ULONG (offset);
    CORBA::ULong alen = NUM2ULONG (length);
    for (CORBA::ULong l=0; l<alen ;++l)
    {
      CORBA::ULongLong val = 0;
      strm >> val;
      VALUE rv = ULL2NUM (val);
      rb_ary_store (rval, (long)offs+l, rv);
    }
  } R2TAO_CATCH;
  return rval;
}

VALUE r2tao_IStream_read_float_array (VALUE self, VALUE rval, VALUE offset, VALUE length)
{
  TAO_InputCDR &strm = *r2tao_InputStream_r2t(self);
  R2TAO_TRY {
    CHECK_RTYPE(rval, T_ARRAY);
    CORBA::ULong offs = NUM2ULONG (offset);
    CORBA::ULong alen = NUM2ULONG (length);
    for (CORBA::ULong l=0; l<alen ;++l)
    {
      CORBA::Float val = 0;
      strm >> val;
      VALUE rv = rb_float_new ((double)val);
      rb_ary_store (rval, (long)offs+l, rv);
    }
  } R2TAO_CATCH;
  return rval;
}

VALUE r2tao_IStream_read_double_array (VALUE self, VALUE rval, VALUE offset, VALUE length)
{
  TAO_InputCDR &strm = *r2tao_InputStream_r2t(self);
  R2TAO_TRY {
    CHECK_RTYPE(rval, T_ARRAY);
    CORBA::ULong offs = NUM2ULONG (offset);
    CORBA::ULong alen = NUM2ULONG (length);
    for (CORBA::ULong l=0; l<alen ;++l)
    {
      CORBA::Double val = 0;
      strm >> val;
      VALUE rv = rb_float_new ((double)val);
      rb_ary_store (rval, (long)offs+l, rv);
    }
  } R2TAO_CATCH;
  return rval;
}

VALUE r2tao_IStream_read_longdouble_array (VALUE self, VALUE rval, VALUE offset, VALUE length)
{
  TAO_InputCDR &strm = *r2tao_InputStream_r2t(self);
  R2TAO_TRY {
    CHECK_RTYPE(rval, T_ARRAY);
    CORBA::ULong offs = NUM2ULONG (offset);
    CORBA::ULong alen = NUM2ULONG (length);
    for (CORBA::ULong l=0; l<alen ;++l)
    {
      CORBA::LongDouble val;
      strm >> val;
      VALUE rv = CLD2RLD (val);
      rb_ary_store (rval, (long)offs+l, rv);
    }
  } R2TAO_CATCH;
  return rval;
}

VALUE r2tao_IStream_read_fixed_array (VALUE, VALUE, VALUE, VALUE)
{
  X_CORBA (NO_IMPLEMENT);
}

VALUE r2tao_IStream_read_construct (VALUE self, VALUE rtc)
{
  VALUE ret = Qnil;
  TAO_InputCDR &strm = *r2tao_InputStream_r2t(self);
  R2TAO_TRY {
    CORBA::TypeCode_ptr tc_ = r2corba_TypeCode_r2t (rtc);

    CORBA::Any any_;
    TAO::Unknown_IDL_Type *impl = 0;
    ACE_NEW_RETURN (impl,
                    TAO::Unknown_IDL_Type (tc_),
                    false);

    any_.replace (impl);
    impl->_tao_decode (strm);

    ret = r2tao_Any2Ruby (any_, tc_, rtc, rtc);
  } R2TAO_CATCH;
  return ret;
}
