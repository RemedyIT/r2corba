/*--------------------------------------------------------------------
# values.h - R2TAO CORBA Valuetype support
#
# Author: Martin Corino
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the R2CORBA LICENSE which is
# included with this program.
#
# Copyright (c) Remedy IT Expertise BV
#------------------------------------------------------------------*/

#include "tao/Valuetype/AbstractBase.h"
#include "tao/Valuetype/ValueBase.h"
#include "tao/Valuetype/ValueFactory.h"
#include "tao/Stub.h"
#include "tao/AnyTypeCode/Any.h"
#include "tao/AnyTypeCode/Any_Impl_T.h"
#include "tao/AnyTypeCode/Any_Dual_Impl_T.h"
#include "tao/Valuetype/Value_VarOut_T.h"
#include "tao/Objref_VarOut_T.h"
#include "tao/VarOut_T.h"
//#include "ace/Auto_Ptr.h"
//#include "ace/Array_Base.h"

extern VALUE r2tao_cBoxedValueBase;

//-------------------------------------------------------------------
//  R2TAO_ArrayAny_Impl_T
//
//  Template for Any implementation containing C array typs
//  to marshal to TAO CDR streams (not used for demarshaling).
//===================================================================

template<typename T>
class R2TAO_ArrayAny_Impl_T : public TAO::Any_Impl
{
public:
  R2TAO_ArrayAny_Impl_T (CORBA::TypeCode_ptr,
                         T * const,
                         CORBA::ULong);
  virtual ~R2TAO_ArrayAny_Impl_T (void);

  static void insert (CORBA::Any &,
                      CORBA::TypeCode_ptr,
                      T * const,
                      CORBA::ULong);

  virtual CORBA::Boolean marshal_value (TAO_OutputCDR &);
  virtual const void *value (void) const;
  virtual void free_value (void);

private:
  void* value_;
  CORBA::ULong length_;
};


//-------------------------------------------------------------------
//  R2TAO Value class
//
//  Wrapper class for reference to R2CORBA Value instance to enable
//  to marshal/demarshal to/from TAO CDR streams.
//===================================================================

class R2TAO_Value;
typedef R2TAO_Value * R2TAO_Value_ptr;
typedef
  TAO_Value_Var_T<
    R2TAO_Value
    >
  R2TAO_Value_var;

typedef
  TAO_Value_Out_T<
    R2TAO_Value
    >
  R2TAO_Value_out;

class R2TAO_Value : public ::CORBA::DefaultValueRefCountBase
{
  public:
    R2TAO_Value (VALUE rbValue, bool for_unmarshal=false);
    virtual ~R2TAO_Value ();

    virtual CORBA::ValueBase* _copy_value (void);

    static void _tao_any_destructor (void *);

    virtual void truncation_hook ();

    static R2TAO_Value* _downcast (::CORBA::ValueBase *v);

    virtual CORBA::TypeCode_ptr _tao_type (void) const;

    /// Return the repository id of this valuetype.
    virtual const char * _tao_obv_repository_id (void) const;

    /// Give the list of the RepositoryIds in the valuetype "truncatable"
    /// inheritance hierarchy. List the id of this valuetype as first
    /// RepositoryID and go up the "truncatable" derivation hierarchy.
    /// Note the truncatable repo ids only list the truncatable base types
    /// to which this type is safe to truncate, not all its parents.
    virtual void _tao_obv_truncatable_repo_ids (Repository_Id_List &) const;

    virtual ::CORBA::Boolean _tao_marshal_v (TAO_OutputCDR &) const;
    virtual ::CORBA::Boolean _tao_unmarshal_v (TAO_InputCDR &);

    // always return false -> i.e. always marshal type Id
    virtual ::CORBA::Boolean _tao_match_formal_type (ptrdiff_t ) const;

    VALUE get_ruby_value () const { return this->rbValue_; }

    bool add_chunk ();

    bool add_chunk_element (CORBA::Any_var& elem);

    bool requires_truncation () const { return this->requires_truncation_; }

    bool has_started_chunk_unmarshalling () const { return this->started_chunk_unmarshal_; }

    void started_chunk_unmarshalling () { this->started_chunk_unmarshal_ = true; }

    void ended_chunk_unmarshalling () { this->started_chunk_unmarshal_ = false; }

  private:
    typedef ACE_Array_Base<CORBA::Any*> ChunkElements;
    struct Chunk {
      Chunk () : next_(0) {}
      ~Chunk() {
        for (ChunkElements::size_type i=0; i<this->elems_.size () ;++i)
        { delete this->elems_[i]; }
        delete this->next_;
        this->next_ = 0;
      }
      ChunkElements elems_;
      Chunk* next_;
    };

    void init ();

    bool for_unmarshal_;
    bool started_chunk_unmarshal_;

    bool requires_truncation_;

    VALUE rbValue_;    // the Ruby valuetype instance

    VALUE rbValueClass_; // the Ruby valuetype class

    VALUE rbCIHolder_; // Ruby wrapper object to hold TAO_ChunkInfo

    CORBA::TypeCode_var val_tc_; // the typecode for the valuetype

    ACE_Auto_Ptr<Chunk> chunk_list_;
    Chunk* last_chunk_;
};

void operator<<= (::CORBA::Any &, R2TAO_Value_ptr); // copying
void operator<<= (::CORBA::Any &, R2TAO_Value_ptr *); // non-copying

::CORBA::Boolean operator<< (TAO_OutputCDR &/*strm*/, const R2TAO_Value * /*_tao_valref*/);
::CORBA::Boolean operator>> (TAO_InputCDR &/*strm*/, R2TAO_Value *&/*_tao_valref*/);

VALUE r2tao_wrap_Valuebox(VALUE rval, CORBA::TypeCode_ptr tc);

//-------------------------------------------------------------------
//  R2TAO Valuefactory class
//
//  Wrapper class for reference to R2CORBA valuefactory instance
//===================================================================

class R2TAO_ValueFactory
  : public CORBA::ValueFactoryBase
{
  public:
    R2TAO_ValueFactory (VALUE rbValueFactory);

    static R2TAO_ValueFactory* _downcast ( ::CORBA::ValueFactoryBase *);

    virtual ::CORBA::ValueBase *
    create_for_unmarshal (void);

    virtual ::CORBA::AbstractBase_ptr
    create_for_unmarshal_abstract (void);

    // TAO-specific extensions
    virtual const char* tao_repository_id (void);

    VALUE get_ruby_factory () { return this->rbValueFactory_; }

  protected:
    virtual ~R2TAO_ValueFactory (void);

  private:
    VALUE rbValueFactory_;

    static R2TAO_RBFuncall fn_create_default_;
};

VALUE r2tao_VFB_register_value_factory(VALUE self, VALUE id, VALUE rfact);
VALUE r2tao_VFB_unregister_value_factory(VALUE self, VALUE id);
VALUE r2tao_VFB_lookup_value_factory(VALUE self, VALUE id);

//-------------------------------------------------------------------
//  R2TAO AbstractValue class
//
//  Wrapper class for value type to present CORBA::AbstractBase
//  interface to TAO Any
//===================================================================

class R2TAO_AbstractValue;
typedef R2TAO_AbstractValue* R2TAO_AbstractValue_ptr;

typedef
  TAO_Objref_Var_T<
    R2TAO_AbstractValue
    >
  R2TAO_AbstractValue_var;

typedef
  TAO_Objref_Out_T<
    R2TAO_AbstractValue
    >
  R2TAO_AbstractValue_out;

class R2TAO_AbstractValue :
  public ::CORBA::AbstractBase,
  public R2TAO_Value
{
  public:
    R2TAO_AbstractValue (VALUE rbValue,
                         CORBA::TypeCode_ptr abs_tc);
    R2TAO_AbstractValue (VALUE rbValue); // for unmarshaling only
    virtual ~R2TAO_AbstractValue ();

    static void _tao_any_destructor (void *);

    static R2TAO_AbstractValue_ptr _duplicate (R2TAO_AbstractValue_ptr obj);

    static R2TAO_AbstractValue* _downcast ( ::CORBA::ValueBase *v);

    virtual const char* _tao_obv_repository_id (void) const;
    virtual CORBA::Boolean _tao_marshal_v (TAO_OutputCDR &strm) const;
    virtual CORBA::Boolean _tao_unmarshal_v (TAO_InputCDR &strm);
    virtual CORBA::Boolean _tao_match_formal_type (ptrdiff_t) const;

    virtual void _add_ref (void);
    virtual void _remove_ref (void);
    virtual ::CORBA::ValueBase *_tao_to_value (void);

    CORBA::TypeCode_ptr abstract_type () const;

  private:
    CORBA::TypeCode_var abs_tc_;
};

void operator<<= (::CORBA::Any &, R2TAO_AbstractValue_ptr); // copying
void operator<<= (::CORBA::Any &, R2TAO_AbstractValue_ptr *); // non-copying

/*  Extract through:
 *
    TAO::Any_Impl_T<R2TAO_AbstractValue>::extract (
        const CORBA::Any & _tao_any,
        R2TAO_AbstractValue::_tao_any_destructor,
        CORBA::TypeCode_ptr _tc,
        R2TAO_AbstractValue_ptr & _tao_elem);
 */

::CORBA::Boolean operator<< (TAO_OutputCDR &, const R2TAO_AbstractValue_ptr);
/*  Extract through:
 *
  ::CORBA::Boolean operator>> (TAO_InputCDR &, CORBA::AbstractBase_ptr & abs_ptr);

 * then use abs_ptr->to_object () or abs_ptr->to_value ()
*/
// Dummy to allow compilation
::CORBA::Boolean operator>> (TAO_InputCDR &/*strm*/, R2TAO_AbstractValue_ptr &/*_tao_objref*/);

//-------------------------------------------------------------------
//  R2TAO AbstractObject class
//
//  Wrapper class for object reference to present CORBA::AbstractBase
//  interface to TAO Any
//===================================================================

class R2TAO_AbstractObject;
typedef R2TAO_AbstractObject* R2TAO_AbstractObject_ptr;

typedef
  TAO_Objref_Var_T<
    R2TAO_AbstractObject
    >
  R2TAO_AbstractObject_var;

typedef
  TAO_Objref_Out_T<
    R2TAO_AbstractObject
    >
  R2TAO_AbstractObject_out;

class R2TAO_AbstractObject :
  public ::CORBA::AbstractBase,
  public ::CORBA::Object
{
  public:
    R2TAO_AbstractObject (CORBA::Object_ptr objref,
                          CORBA::TypeCode_ptr abs_tc);
    virtual ~R2TAO_AbstractObject () ;

    static void _tao_any_destructor (void *);

    static R2TAO_AbstractObject_ptr _duplicate (R2TAO_AbstractObject_ptr obj);

    static void _tao_release (R2TAO_AbstractObject_ptr obj);

    virtual void _add_ref (void);
    virtual void _remove_ref (void);

    virtual ::CORBA::Boolean _is_a (const char *type_id);
    virtual const char* _interface_repository_id (void) const;
    virtual ::CORBA::Boolean marshal (TAO_OutputCDR &cdr);

    CORBA::TypeCode_ptr abstract_type () const;

  private:
    CORBA::TypeCode_var abs_tc_;
};

void operator<<= (::CORBA::Any &, R2TAO_AbstractObject_ptr); // copying
void operator<<= (::CORBA::Any &, R2TAO_AbstractObject_ptr *); // non-copying

/*  Extract through:
 *
    TAO::Any_Impl_T<R2TAO_AbstractObject>::extract (
        const CORBA::Any & _tao_any,
        R2TAO_AbstractObject::_tao_any_destructor,
        CORBA::TypeCode_ptr _tc,
        R2TAO_AbstractObject_ptr & _tao_elem);
 */

::CORBA::Boolean operator<< (TAO_OutputCDR &, const R2TAO_AbstractObject_ptr);
/*  Extract through:
 *
  ::CORBA::Boolean operator>> (TAO_InputCDR &, CORBA::AbstractBase_ptr & abs_ptr);

 * then use abs_ptr->to_object () or abs_ptr->to_value ()
*/
// Dummy to allow compilation
::CORBA::Boolean operator>> (TAO_InputCDR &/*strm*/, R2TAO_AbstractObject_ptr &/*_tao_objref*/);

namespace CORBA
{
  void release (R2TAO_AbstractObject_ptr);
  ::CORBA::Boolean is_nil (R2TAO_AbstractObject_ptr);
}

R2TAO_AbstractObject_ptr r2tao_AbstractObject_r2t (VALUE rval, VALUE rtc, CORBA::TypeCode_ptr tc);

namespace TAO
{
  template<>
  struct  Value_Traits<R2TAO_Value>
  {
    static void add_ref (R2TAO_Value *);
    static void remove_ref (R2TAO_Value *);
    static void release (R2TAO_Value *);
  };

  template<>
  struct  Objref_Traits< R2TAO_AbstractValue>
  {
    static R2TAO_AbstractValue_ptr duplicate (
        R2TAO_AbstractValue_ptr p);
    static void release (
        R2TAO_AbstractValue_ptr p);
    static R2TAO_AbstractValue_ptr nil (void);
    static ::CORBA::Boolean marshal (
        const R2TAO_AbstractValue_ptr p,
        TAO_OutputCDR & cdr);
  };

  template<>
  struct  Objref_Traits< R2TAO_AbstractObject>
  {
    static R2TAO_AbstractObject_ptr duplicate (
        R2TAO_AbstractObject_ptr p);
    static void release (
        R2TAO_AbstractObject_ptr p);
    static R2TAO_AbstractObject_ptr nil (void);
    static ::CORBA::Boolean marshal (
        const R2TAO_AbstractObject_ptr p,
        TAO_OutputCDR & cdr);
  };
}
