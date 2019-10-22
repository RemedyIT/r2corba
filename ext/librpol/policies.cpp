/*--------------------------------------------------------------------
# policies.cpp - R2TAO CORBA Policies support
#
# Author: Martin Corino
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the R2CORBA LICENSE which is
# included with this program.
#
# Copyright (c) Remedy IT Expertise BV
#------------------------------------------------------------------*/

#include "policies.h"
#include "rpol_export.h"
#include "orb.h"
#include "exception.h"
#include "object.h"
#include "typecode.h"
#include "poa.h"
#include "tao/corba.h"
#include "tao/ORB_Core.h"
#include "tao/AnyTypeCode/Any.h"
#include "tao/BiDir_GIOP/BiDirGIOP.h"
#include "tao/Messaging/Messaging.h"

static VALUE r2tao_nsPolicy = 0;
static VALUE r2tao_nsPolicyManager = 0;
static VALUE r2tao_nsPolicyCurrent = 0;
static VALUE r2tao_nsThreadPolicy;
static VALUE r2tao_nsLifespanPolicy;
static VALUE r2tao_nsIdAssignmentPolicy;
static VALUE r2tao_nsIdUniquenessPolicy;
static VALUE r2tao_nsImplicitActivationPolicy;
static VALUE r2tao_nsServantRetentionPolicy;
static VALUE r2tao_nsRequestProcessingPolicy;

static VALUE r2tao_x_PolicyError;
static VALUE r2tao_x_InvalidPolicies;

static ID validate_ID;

static R2TAO_RBFuncall FN_narrow ("_narrow");

/* orb */
static VALUE rCORBA_ORB_create_policy(VALUE self, VALUE identifier, VALUE any);

/* Policy */
static CORBA::Policy_ptr r2tao_Policy_r2t(VALUE obj);

static VALUE r2tao_Policy_destroy(VALUE self);
static VALUE r2tao_Policy_type(VALUE self);
static VALUE r2tao_Policy_copy(VALUE self);

static VALUE r2tao_Object_get_policy(VALUE self, VALUE ptype);
static VALUE r2tao_Object_get_policy_overrides(VALUE self, VALUE ptseq);
static VALUE r2tao_Object_set_policy_overrides(VALUE self, VALUE policies, VALUE set_or_add);
static VALUE r2tao_Object_validate_connection(VALUE self, VALUE inconsistent_pol_out);

static VALUE r2tao_PolicyManager_get_policy_overrides(VALUE self, VALUE ptseq);
static VALUE r2tao_PolicyManager_set_policy_overrides(VALUE self, VALUE policies, VALUE set_or_add);

static VALUE r2tao_POA_create_thread_policy(VALUE self, VALUE value);
static VALUE r2tao_POA_create_lifespan_policy(VALUE self, VALUE value);
static VALUE r2tao_POA_create_id_uniqueness_policy(VALUE self, VALUE value);
static VALUE r2tao_POA_create_id_assignment_policy(VALUE self, VALUE value);
static VALUE r2tao_POA_create_implicit_activation_policy(VALUE self, VALUE value);
static VALUE r2tao_POA_create_servant_retention_policy(VALUE self, VALUE value);
static VALUE r2tao_POA_create_request_processing_policy(VALUE self, VALUE value);

static VALUE r2tao_ThreadPolicy_value(VALUE self);
static VALUE r2tao_LifespanPolicy_value(VALUE self);
static VALUE r2tao_IdAssignmentPolicy_value(VALUE self);
static VALUE r2tao_IdUniquenessPolicy_value(VALUE self);
static VALUE r2tao_ImplicitActivationPolicy_value(VALUE self);
static VALUE r2tao_ServantRetentionPolicy_value(VALUE self);
static VALUE r2tao_RequestProcessingPolicy_value(VALUE self);
static VALUE r2tao_BiDirPolicy_value(VALUE self);
static VALUE r2tao_RelativeRoundtripTimeoutPolicy_relative_expiry(VALUE self);
static VALUE r2tao_ConnectionTimeoutPolicy_relative_expiry(VALUE self);

#if defined(WIN32) && defined(_DEBUG)
extern "C" R2TAO_POL_EXPORT void Init_librpold()
#else
extern "C" R2TAO_POL_EXPORT void Init_librpol()
#endif
{
  VALUE k;

  if (r2tao_nsCORBA == 0)
  {
    rb_raise(rb_eRuntimeError, "CORBA base not initialized.");
    return;
  }

  if (r2tao_nsPolicy) return;

  validate_ID = rb_intern ("validate");

  r2tao_x_InvalidPolicies = rb_const_get (r2tao_nsCORBA, rb_intern ("InvalidPolicies"));
  r2tao_x_PolicyError = rb_const_get (r2tao_nsCORBA, rb_intern ("PolicyError"));

  // overloaded method(s) with full Policy support
  rb_define_method(r2tao_cORB, "create_policy", RUBY_METHOD_FUNC(rCORBA_ORB_create_policy), 2);

  // basic Policy class
  r2tao_nsPolicy = k = rb_eval_string ("R2CORBA::CORBA::Policy");
  rb_define_method(k, "destroy", RUBY_METHOD_FUNC(r2tao_Policy_destroy), 0);
  rb_define_method(k, "policy_type", RUBY_METHOD_FUNC(r2tao_Policy_type), 0);
  rb_define_method(k, "copy", RUBY_METHOD_FUNC(r2tao_Policy_copy), 0);

  // CORBA::Object policy support
  k = r2tao_cObject;
  rb_define_method(k, "_get_policy", RUBY_METHOD_FUNC(r2tao_Object_get_policy), 1);
  rb_define_method(k, "_get_policy_overrides", RUBY_METHOD_FUNC(r2tao_Object_get_policy_overrides), 1);
  rb_define_method(k, "_set_policy_overrides", RUBY_METHOD_FUNC(r2tao_Object_set_policy_overrides), 2);
  rb_define_method(k, "_validate_connection", RUBY_METHOD_FUNC(r2tao_Object_validate_connection), 1);

  // policy manager and current interfaces
  r2tao_nsPolicyManager = k = rb_eval_string ("R2CORBA::CORBA::PolicyManager");
  rb_define_method(k, "get_policy_overrides", RUBY_METHOD_FUNC(r2tao_PolicyManager_get_policy_overrides), 1);
  rb_define_method(k, "set_policy_overrides", RUBY_METHOD_FUNC(r2tao_PolicyManager_set_policy_overrides), 2);
  r2tao_nsPolicyCurrent = k = rb_eval_string ("R2CORBA::CORBA::PolicyCurrent");

  // POA Policy support
  k = r2tao_nsPOA;
  rb_define_method(k, "create_thread_policy", RUBY_METHOD_FUNC(r2tao_POA_create_thread_policy), 1);
  rb_define_method(k, "create_lifespan_policy", RUBY_METHOD_FUNC(r2tao_POA_create_lifespan_policy), 1);
  rb_define_method(k, "create_id_assignment_policy", RUBY_METHOD_FUNC(r2tao_POA_create_id_assignment_policy), 1);
  rb_define_method(k, "create_id_uniqueness_policy", RUBY_METHOD_FUNC(r2tao_POA_create_id_uniqueness_policy), 1);
  rb_define_method(k, "create_implicit_activation_policy", RUBY_METHOD_FUNC(r2tao_POA_create_implicit_activation_policy), 1);
  rb_define_method(k, "create_servant_retention_policy", RUBY_METHOD_FUNC(r2tao_POA_create_servant_retention_policy), 1);
  rb_define_method(k, "create_request_processing_policy", RUBY_METHOD_FUNC(r2tao_POA_create_request_processing_policy), 1);

  k = r2tao_nsThreadPolicy = rb_eval_string ("R2CORBA::PortableServer::ThreadPolicy");
  rb_define_method(k, "value", RUBY_METHOD_FUNC(r2tao_ThreadPolicy_value), 0);
  k = r2tao_nsLifespanPolicy = rb_eval_string ("R2CORBA::PortableServer::LifespanPolicy");
  rb_define_method(k, "value", RUBY_METHOD_FUNC(r2tao_LifespanPolicy_value), 0);
  k = r2tao_nsIdUniquenessPolicy = rb_eval_string ("R2CORBA::PortableServer::IdUniquenessPolicy");
  rb_define_method(k, "value", RUBY_METHOD_FUNC(r2tao_IdUniquenessPolicy_value), 0);
  k = r2tao_nsIdAssignmentPolicy = rb_eval_string ("R2CORBA::PortableServer::IdAssignmentPolicy");
  rb_define_method(k, "value", RUBY_METHOD_FUNC(r2tao_IdAssignmentPolicy_value), 0);
  k = r2tao_nsImplicitActivationPolicy = rb_eval_string ("R2CORBA::PortableServer::ImplicitActivationPolicy");
  rb_define_method(k, "value", RUBY_METHOD_FUNC(r2tao_ImplicitActivationPolicy_value), 0);
  k = r2tao_nsServantRetentionPolicy = rb_eval_string ("R2CORBA::PortableServer::ServantRetentionPolicy");
  rb_define_method(k, "value", RUBY_METHOD_FUNC(r2tao_ServantRetentionPolicy_value), 0);
  k = r2tao_nsRequestProcessingPolicy = rb_eval_string ("R2CORBA::PortableServer::RequestProcessingPolicy");
  rb_define_method(k, "value", RUBY_METHOD_FUNC(r2tao_RequestProcessingPolicy_value), 0);

  k = rb_eval_string ("R2CORBA::BiDirPolicy::BidirectionalPolicy");
  rb_define_method(k, "value", RUBY_METHOD_FUNC(r2tao_BiDirPolicy_value), 0);

  k = rb_eval_string ("R2CORBA::Messaging::RelativeRoundtripTimeoutPolicy");
  rb_define_method(k, "relative_expiry", RUBY_METHOD_FUNC(r2tao_RelativeRoundtripTimeoutPolicy_relative_expiry), 0);

  k = rb_eval_string ("R2CORBA::TAO::ConnectionTimeoutPolicy");
  rb_define_method(k, "relative_expiry", RUBY_METHOD_FUNC(r2tao_ConnectionTimeoutPolicy_relative_expiry), 0);
}

//-------------------------------------------------------------------
//  R2TAO ORB class
//
//===================================================================

static VALUE rCORBA_ORB_create_policy(VALUE self, VALUE identifier, VALUE any)
{
  CORBA::ORB_ptr orb;
  CORBA::Policy_var policy;
  VALUE rpolicy = Qnil;

  orb = r2tao_ORB_r2t (self);

  R2TAO_TRY
  {
    try
    {
      CORBA::Any _xval;
      r2tao_Ruby_to_Any(_xval, any);
      policy = orb->create_policy(static_cast<CORBA::PolicyType> (NUM2LONG (identifier)), _xval);
      CORBA::Object_ptr polobj = dynamic_cast<CORBA::Object_ptr> (policy.in ());
      rpolicy = r2corba_Object_t2r (polobj);
      rpolicy = FN_narrow.invoke (r2tao_nsPolicy, 1, &rpolicy);
    }
    catch (const CORBA::PolicyError& ex)
    {
      VALUE reason = INT2NUM (ex.reason);
      rb_exc_raise (rb_class_new_instance (1, &reason, r2tao_x_PolicyError));
    }
  }
  R2TAO_CATCH;

  return rpolicy;
}

//-------------------------------------------------------------------
//  R2TAO Policy class
//
//===================================================================

CORBA::Policy_ptr r2tao_Policy_r2t(VALUE obj)
{
  CORBA::Object_ptr _obj = r2corba_Object_r2t (obj);
  return dynamic_cast<CORBA::Policy_ptr> (_obj);
}

VALUE r2tao_Policy_t2r(CORBA::Policy_ptr policy)
{
  VALUE robj = r2corba_Object_t2r (dynamic_cast<CORBA::Object_ptr> (policy));
  return FN_narrow.invoke (r2tao_nsPolicy, 1, &robj);
}

VALUE r2tao_Policy_destroy(VALUE self)
{
  R2TAO_TRY
  {
    CORBA::Policy_ptr _policy = r2tao_Policy_r2t (self);
    _policy->destroy ();
  }
  R2TAO_CATCH;
  return Qnil;
}

VALUE r2tao_Policy_type(VALUE self)
{
  VALUE ret = Qnil;

  R2TAO_TRY
  {
    CORBA::Policy_ptr _policy = r2tao_Policy_r2t (self);
    CORBA::PolicyType _typ = _policy->policy_type ();
    ret = LONG2NUM (static_cast<long> (_typ));
  }
  R2TAO_CATCH;

  return ret;
}

VALUE r2tao_Policy_copy(VALUE self)
{
  VALUE ret = Qnil;

  R2TAO_TRY
  {
    CORBA::Policy_ptr _policy = r2tao_Policy_r2t (self);
    CORBA::Policy_var _pol = _policy->copy ();
    ret = r2tao_Policy_t2r (_pol.in ());
  }
  R2TAO_CATCH;

  return ret;
}

//-------------------------------------------------------------------
//  R2TAO CORBA::Object class
//
//===================================================================

VALUE r2tao_Object_get_policy(VALUE self, VALUE ptype)
{
  CORBA::Object_ptr _obj = r2tao_Object_r2t(self);

  VALUE rPolicyType_tc = rb_eval_string ("CORBA::PolicyType._tc");
  rb_funcall (rPolicyType_tc, rb_intern ("validate"), 1, ptype);

  R2TAO_TRY
  {
    CORBA::Policy_var policy =
      _obj->_get_policy (static_cast<CORBA::PolicyType> (NUM2ULONG (ptype)));
    VALUE rpol = r2tao_Policy_t2r (policy.in ());
    return rpol;
  }
  R2TAO_CATCH;

  return Qnil;
}

VALUE r2tao_Object_get_policy_overrides(VALUE self, VALUE ptseq)
{
  CORBA::Object_ptr _obj = r2tao_Object_r2t(self);

  VALUE rPolicyTypeSeq_tc = rb_eval_string ("CORBA::PolicyTypeSeq._tc");
  rb_funcall (rPolicyTypeSeq_tc, rb_intern ("validate"), 1, ptseq);

  R2TAO_TRY
  {
    CORBA::ULong alen = static_cast<unsigned long> (RARRAY_LEN (ptseq));
    CORBA::PolicyTypeSeq _pts (alen);
    _pts.length (alen);
    for (CORBA::ULong l=0; l<alen ;++l)
      _pts[l] = static_cast<CORBA::PolicyType> (NUM2ULONG (rb_ary_entry (ptseq, l)));
    CORBA::PolicyList_var policies = _obj->_get_policy_overrides (_pts);
    VALUE rpolicies = rb_ary_new2 (policies->length ());
    for (CORBA::ULong l=0; l<policies->length () ;++l)
    {
      CORBA::Policy_ptr _policy = policies[l];
      VALUE rpol = r2tao_Policy_t2r (_policy);
      rb_ary_push (rpolicies, rpol);
    }
    return rpolicies;
  }
  R2TAO_CATCH;

  return Qnil;
}

VALUE r2tao_Object_set_policy_overrides(VALUE self, VALUE policies, VALUE set_or_add)
{
  CORBA::Object_ptr _obj = r2tao_Object_r2t(self);

  VALUE rPolicyList_tc = rb_eval_string ("CORBA::PolicyList._tc");
  rb_funcall (rPolicyList_tc, rb_intern ("validate"), 1, policies);
  VALUE rSetOverrideType_tc = rb_eval_string ("CORBA::SetOverrideType._tc");
  rb_funcall (rSetOverrideType_tc, rb_intern ("validate"), 1, set_or_add);

  R2TAO_TRY
  {
    try
    {
      CORBA::ULong alen = static_cast<unsigned long> (RARRAY_LEN (policies));
      CORBA::PolicyList pollist(alen);
      pollist.length (alen);
      for (CORBA::ULong l=0; l<alen ;++l)
      {
        VALUE pol = rb_ary_entry (policies, l);
        pollist[l] = CORBA::Policy::_duplicate (r2tao_Policy_r2t (pol));
      }

      _obj = _obj->_set_policy_overrides (pollist, static_cast<CORBA::SetOverrideType> (NUM2LONG (set_or_add)));
      return r2tao_Object_t2r (_obj);
    }
    catch (const CORBA::InvalidPolicies& ex)
    {
      VALUE rindices = rb_ary_new2 ((long)ex.indices.length ());
      for (CORBA::ULong i=0; i<ex.indices.length () ;++i)
      {
        rb_ary_push (rindices, ULONG2NUM (ex.indices[i]));
      }
      rb_exc_raise (rb_class_new_instance (1, &rindices, r2tao_x_InvalidPolicies));
    }
  }
  R2TAO_CATCH;

  return Qnil;
}

VALUE r2tao_Object_validate_connection(VALUE self, VALUE inconsistent_pol_out)
{
  CORBA::Object_ptr _obj = r2tao_Object_r2t(self);

  r2tao_check_type (inconsistent_pol_out, rb_cArray);

  R2TAO_TRY
  {
    CORBA::PolicyList_var pollist;
    CORBA::Boolean val = _obj->_validate_connection (pollist.out ());
    if (pollist.ptr () != 0)
    {
      for (CORBA::ULong l=0; l<pollist->length () ;++l)
      {
        CORBA::Policy_ptr _policy = pollist[l];
        VALUE rpol = r2tao_Policy_t2r (_policy);
        rb_ary_push (inconsistent_pol_out, rpol);
      }
    }
    return val ? Qtrue : Qfalse;
  }
  R2TAO_CATCH;

  return Qnil;
}

//-------------------------------------------------------------------
//  R2TAO PolicyManager class
//
//===================================================================

static CORBA::PolicyManager_ptr r2tao_PolicyManager_r2t(VALUE obj)
{
  CORBA::Object_ptr _obj = r2corba_Object_r2t (obj);
  return dynamic_cast<CORBA::PolicyManager_ptr> (_obj);
}

static VALUE r2tao_PolicyManager_get_policy_overrides(VALUE self, VALUE ptseq)
{
  CORBA::PolicyManager_ptr _polman = r2tao_PolicyManager_r2t(self);

  VALUE rPolicyTypeSeq_tc = rb_eval_string ("CORBA::PolicyTypeSeq._tc");
  rb_funcall (rPolicyTypeSeq_tc, rb_intern ("validate"), 1, ptseq);

  R2TAO_TRY
  {
    CORBA::ULong alen = static_cast<unsigned long> (RARRAY_LEN (ptseq));
    CORBA::PolicyTypeSeq _pts (alen);
    _pts.length (alen);
    for (CORBA::ULong l=0; l<alen ;++l)
      _pts[l] = static_cast<CORBA::PolicyType> (NUM2ULONG (rb_ary_entry (ptseq, l)));
    CORBA::PolicyList_var policies = _polman->get_policy_overrides (_pts);
    VALUE rpolicies = rb_ary_new2 (policies->length ());
    for (CORBA::ULong l=0; l<policies->length () ;++l)
    {
      CORBA::Policy_ptr _policy = policies[l];
      VALUE rpol = r2tao_Policy_t2r (_policy);
      rb_ary_push (rpolicies, rpol);
    }
    return rpolicies;
  }
  R2TAO_CATCH;

  return Qnil;
}

static VALUE r2tao_PolicyManager_set_policy_overrides(VALUE self, VALUE policies, VALUE set_or_add)
{
  CORBA::PolicyManager_ptr _polman = r2tao_PolicyManager_r2t(self);

  VALUE rPolicyList_tc = rb_eval_string ("CORBA::PolicyList._tc");
  rb_funcall (rPolicyList_tc, rb_intern ("validate"), 1, policies);
  VALUE rSetOverrideType_tc = rb_eval_string ("CORBA::SetOverrideType._tc");
  rb_funcall (rSetOverrideType_tc, rb_intern ("validate"), 1, set_or_add);

  R2TAO_TRY
  {
    try
    {
      CORBA::ULong alen = static_cast<unsigned long> (RARRAY_LEN (policies));
      CORBA::PolicyList pollist(alen);
      pollist.length (alen);
      for (CORBA::ULong l=0; l<alen ;++l)
      {
        VALUE pol = rb_ary_entry (policies, l);
        pollist[l] = CORBA::Policy::_duplicate (r2tao_Policy_r2t (pol));
      }

      _polman->set_policy_overrides (
          pollist,
          static_cast<CORBA::SetOverrideType> (NUM2LONG (set_or_add)));
    }
    catch (const CORBA::InvalidPolicies& ex)
    {
      VALUE rindices = rb_ary_new2 ((long)ex.indices.length ());
      for (CORBA::ULong i=0; i<ex.indices.length () ;++i)
      {
        rb_ary_push (rindices, ULONG2NUM (ex.indices[i]));
      }
      rb_exc_raise (rb_class_new_instance (1, &rindices, r2tao_x_InvalidPolicies));
    }
  }
  R2TAO_CATCH;

  return Qnil;
}

//-------------------------------------------------------------------
//  R2TAO POA policy support
//
//===================================================================

VALUE r2tao_POA_create_thread_policy(VALUE self, VALUE value)
{
  VALUE rpolicy = Qnil;

  VALUE rpoltc = rb_eval_string("PortableServer::ThreadPolicyValue._tc");
  rb_funcall (rpoltc, validate_ID, 1, value);

  R2TAO_TRY
  {
    PortableServer::POA_var _poa = r2tao_POA_r2t (self);
    PortableServer::LifespanPolicyValue pval =
      static_cast<PortableServer::LifespanPolicyValue> (NUM2LONG (value));
    PortableServer::LifespanPolicy_var policy = _poa->create_lifespan_policy (pval);
    rpolicy = r2tao_Policy_t2r (policy.in ());
  }
  R2TAO_CATCH;

  return rpolicy;
}

VALUE r2tao_POA_create_lifespan_policy(VALUE self, VALUE value)
{
  VALUE rpolicy = Qnil;

  VALUE rpoltc = rb_eval_string("PortableServer::LifespanPolicyValue._tc");
  rb_funcall (rpoltc, validate_ID, 1, value);

  R2TAO_TRY
  {
    PortableServer::POA_var _poa = r2tao_POA_r2t (self);
    PortableServer::LifespanPolicyValue pval =
      static_cast<PortableServer::LifespanPolicyValue> (NUM2LONG (value));
    PortableServer::LifespanPolicy_var policy = _poa->create_lifespan_policy (pval);
    rpolicy = r2tao_Policy_t2r (policy.in ());
  }
  R2TAO_CATCH;

  return rpolicy;
}

VALUE r2tao_POA_create_id_uniqueness_policy(VALUE self, VALUE value)
{
  VALUE rpolicy = Qnil;

  VALUE rpoltc = rb_eval_string("PortableServer::IdUniquenessPolicyValue._tc");
  rb_funcall (rpoltc, validate_ID, 1, value);

  R2TAO_TRY
  {
    PortableServer::POA_var _poa = r2tao_POA_r2t (self);
    PortableServer::IdUniquenessPolicyValue pval =
      static_cast<PortableServer::IdUniquenessPolicyValue> (NUM2LONG (value));
    PortableServer::IdUniquenessPolicy_var policy = _poa->create_id_uniqueness_policy (pval);
    rpolicy = r2tao_Policy_t2r (policy.in ());
  }
  R2TAO_CATCH;

  return rpolicy;
}

VALUE r2tao_POA_create_id_assignment_policy(VALUE self, VALUE value)
{
  VALUE rpolicy = Qnil;

  VALUE rpoltc = rb_eval_string("PortableServer::IdAssignmentPolicyValue._tc");
  rb_funcall (rpoltc, validate_ID, 1, value);

  R2TAO_TRY
  {
    PortableServer::POA_var _poa = r2tao_POA_r2t (self);
    PortableServer::IdAssignmentPolicyValue pval =
      static_cast<PortableServer::IdAssignmentPolicyValue> (NUM2LONG (value));
    PortableServer::IdAssignmentPolicy_var policy = _poa->create_id_assignment_policy (pval);
    rpolicy = r2tao_Policy_t2r (policy.in ());
  }
  R2TAO_CATCH;

  return rpolicy;
}

VALUE r2tao_POA_create_implicit_activation_policy(VALUE self, VALUE value)
{
  VALUE rpolicy = Qnil;

  VALUE rpoltc = rb_eval_string("PortableServer::ImplicitActivationPolicyValue._tc");
  rb_funcall (rpoltc, validate_ID, 1, value);

  R2TAO_TRY
  {
    PortableServer::POA_var _poa = r2tao_POA_r2t (self);
    PortableServer::ImplicitActivationPolicyValue pval =
      static_cast<PortableServer::ImplicitActivationPolicyValue> (NUM2LONG (value));
    PortableServer::ImplicitActivationPolicy_var policy = _poa->create_implicit_activation_policy (pval);
    rpolicy = r2tao_Policy_t2r (policy.in ());
  }
  R2TAO_CATCH;

  return rpolicy;
}

VALUE r2tao_POA_create_servant_retention_policy(VALUE self, VALUE value)
{
  VALUE rpolicy = Qnil;

  VALUE rpoltc = rb_eval_string("PortableServer::ServantRetentionPolicyValue._tc");
  rb_funcall (rpoltc, validate_ID, 1, value);

  R2TAO_TRY
  {
    PortableServer::POA_var _poa = r2tao_POA_r2t (self);
    PortableServer::ServantRetentionPolicyValue pval =
      static_cast<PortableServer::ServantRetentionPolicyValue> (NUM2LONG (value));
    PortableServer::ServantRetentionPolicy_var policy = _poa->create_servant_retention_policy (pval);
    rpolicy = r2tao_Policy_t2r (policy.in ());
  }
  R2TAO_CATCH;

  return rpolicy;
}

VALUE r2tao_POA_create_request_processing_policy(VALUE self, VALUE value)
{
  VALUE rpolicy = Qnil;

  VALUE rpoltc = rb_eval_string("PortableServer::RequestProcessingPolicyValue._tc");
  rb_funcall (rpoltc, validate_ID, 1, value);

  R2TAO_TRY
  {
    PortableServer::POA_var _poa = r2tao_POA_r2t (self);
    PortableServer::RequestProcessingPolicyValue pval =
      static_cast<PortableServer::RequestProcessingPolicyValue> (NUM2LONG (value));
    PortableServer::RequestProcessingPolicy_var policy = _poa->create_request_processing_policy (pval);
    rpolicy = r2tao_Policy_t2r (policy.in ());
  }
  R2TAO_CATCH;

  return rpolicy;
}

//-------------------------------------------------------------------
//  R2TAO specific policy classes
//
//===================================================================

VALUE r2tao_ThreadPolicy_value(VALUE self)
{
  VALUE ret = Qnil;

  R2TAO_TRY
  {
    PortableServer::ThreadPolicy_ptr _policy =
      dynamic_cast<PortableServer::ThreadPolicy_ptr> (r2tao_Policy_r2t (self));
    PortableServer::ThreadPolicyValue _val = _policy->value ();
    ret = LONG2NUM (static_cast<long> (_val));
  }
  R2TAO_CATCH;

  return ret;
}

VALUE r2tao_LifespanPolicy_value(VALUE self)
{
  VALUE ret = Qnil;

  R2TAO_TRY
  {
    PortableServer::LifespanPolicy_ptr _policy =
      dynamic_cast<PortableServer::LifespanPolicy_ptr> (r2tao_Policy_r2t (self));
    PortableServer::LifespanPolicyValue _val = _policy->value ();
    ret = LONG2NUM (static_cast<long> (_val));
  }
  R2TAO_CATCH;

  return ret;
}

VALUE r2tao_IdAssignmentPolicy_value(VALUE self)
{
  VALUE ret = Qnil;

  R2TAO_TRY
  {
    PortableServer::IdAssignmentPolicy_ptr _policy =
      dynamic_cast<PortableServer::IdAssignmentPolicy_ptr> (r2tao_Policy_r2t (self));
    PortableServer::IdAssignmentPolicyValue _val = _policy->value ();
    ret = LONG2NUM (static_cast<long> (_val));
  }
  R2TAO_CATCH;

  return ret;
}

VALUE r2tao_IdUniquenessPolicy_value(VALUE self)
{
  VALUE ret = Qnil;

  R2TAO_TRY
  {
    PortableServer::IdUniquenessPolicy_ptr _policy =
      dynamic_cast<PortableServer::IdUniquenessPolicy_ptr> (r2tao_Policy_r2t (self));
    PortableServer::IdUniquenessPolicyValue _val = _policy->value ();
    ret = LONG2NUM (static_cast<long> (_val));
  }
  R2TAO_CATCH;

  return ret;
}

VALUE r2tao_ImplicitActivationPolicy_value(VALUE self)
{
  VALUE ret = Qnil;

  R2TAO_TRY
  {
    PortableServer::ImplicitActivationPolicy_ptr _policy =
      dynamic_cast<PortableServer::ImplicitActivationPolicy_ptr> (r2tao_Policy_r2t (self));
    PortableServer::ImplicitActivationPolicyValue _val = _policy->value ();
    ret = LONG2NUM (static_cast<long> (_val));
  }
  R2TAO_CATCH;

  return ret;
}

VALUE r2tao_ServantRetentionPolicy_value(VALUE self)
{
  VALUE ret = Qnil;

  R2TAO_TRY
  {
    PortableServer::ServantRetentionPolicy_ptr _policy =
      dynamic_cast<PortableServer::ServantRetentionPolicy_ptr> (r2tao_Policy_r2t (self));
    PortableServer::ServantRetentionPolicyValue _val = _policy->value ();
    ret = LONG2NUM (static_cast<long> (_val));
  }
  R2TAO_CATCH;

  return ret;
}

VALUE r2tao_RequestProcessingPolicy_value(VALUE self)
{
  VALUE ret = Qnil;

  R2TAO_TRY
  {
    PortableServer::RequestProcessingPolicy_ptr _policy =
      dynamic_cast<PortableServer::RequestProcessingPolicy_ptr> (r2tao_Policy_r2t (self));
    PortableServer::RequestProcessingPolicyValue _val = _policy->value ();
    ret = LONG2NUM (static_cast<long> (_val));
  }
  R2TAO_CATCH;

  return ret;
}

VALUE r2tao_BiDirPolicy_value(VALUE self)
{
  VALUE ret = Qnil;

  R2TAO_TRY
  {
    BiDirPolicy::BidirectionalPolicy_ptr _policy =
      dynamic_cast<BiDirPolicy::BidirectionalPolicy_ptr> (r2tao_Policy_r2t (self));
    BiDirPolicy::BidirectionalPolicyValue _val = _policy->value ();
    ret = LONG2NUM (static_cast<long> (_val));
  }
  R2TAO_CATCH;

  return ret;
}

VALUE r2tao_RelativeRoundtripTimeoutPolicy_relative_expiry(VALUE self)
{
  VALUE ret = Qnil;

  R2TAO_TRY
  {
    Messaging::RelativeRoundtripTimeoutPolicy_ptr _policy =
        dynamic_cast<Messaging::RelativeRoundtripTimeoutPolicy_ptr> (r2tao_Policy_r2t (self));
    TimeBase::TimeT _val = _policy->relative_expiry ();
    ret = ULL2NUM (_val);
  }
  R2TAO_CATCH;

  return ret;
}

VALUE r2tao_ConnectionTimeoutPolicy_relative_expiry(VALUE self)
{
  VALUE ret = Qnil;

  R2TAO_TRY
  {
    TAO::ConnectionTimeoutPolicy_ptr _policy =
      dynamic_cast<TAO::ConnectionTimeoutPolicy_ptr> (r2tao_Policy_r2t (self));
    TimeBase::TimeT _val = _policy->relative_expiry ();
    ret = ULL2NUM (_val);
  }
  R2TAO_CATCH;

  return ret;
}

// end of orb.cpp
