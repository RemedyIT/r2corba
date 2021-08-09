/*--------------------------------------------------------------------
# exception.cpp - R2TAO CORBA exception support
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
#include "tao/corba.h"
#include "tao/AnyTypeCode/Any.h"
#include "tao/AnyTypeCode/Any_Unknown_IDL_Type.h"

VALUE r2tao_cError = 0;
R2TAO_EXPORT VALUE r2tao_cSystemException;
R2TAO_EXPORT VALUE r2tao_cUserException;
VALUE r2tao_cUNKNOWN;
VALUE r2tao_cBAD_PARAM;
VALUE r2tao_cNO_MEMORY;
VALUE r2tao_cIMP_LIMIT;
VALUE r2tao_cCOMM_FAILURE;
VALUE r2tao_cINV_OBJREF;
VALUE r2tao_cNO_PERMISSION;
VALUE r2tao_cINTERNAL;
VALUE r2tao_cMARSHAL;
VALUE r2tao_cINITIALIZE;
VALUE r2tao_cNO_IMPLEMENT;
VALUE r2tao_cBAD_TYPECODE;
VALUE r2tao_cBAD_OPERATION;
VALUE r2tao_cNO_RESOURCES;
VALUE r2tao_cNO_RESPONSE;
VALUE r2tao_cPERSIST_STORE;
VALUE r2tao_cBAD_INV_ORDER;
VALUE r2tao_cTRANSIENT;
VALUE r2tao_cFREE_MEM;
VALUE r2tao_cINV_IDENT;
VALUE r2tao_cINV_FLAG;
VALUE r2tao_cINTF_REPOS;
VALUE r2tao_cBAD_CONTEXT;
VALUE r2tao_cOBJ_ADAPTER;
VALUE r2tao_cDATA_CONVERSION;
VALUE r2tao_cOBJECT_NOT_EXIST;
VALUE r2tao_cTRANSACTION_UNAVAILABLE;
VALUE r2tao_cTRANSACTION_MODE;
VALUE r2tao_cTRANSACTION_REQUIRED;
VALUE r2tao_cTRANSACTION_ROLLEDBACK;
VALUE r2tao_cINVALID_TRANSACTION;
VALUE r2tao_cINV_POLICY;
VALUE r2tao_cCODESET_INCOMPATIBLE;
VALUE r2tao_cREBIND;
VALUE r2tao_cTIMEOUT;
VALUE r2tao_cBAD_QOS;
VALUE r2tao_cINVALID_ACTIVITY;
VALUE r2tao_cACTIVITY_COMPLETED;
VALUE r2tao_cACTIVITY_REQUIRED;
VALUE r2tao_cTHREAD_CANCELLED;

static void sysexc_raise(const CORBA::SystemException& sex, char *_reason = 0)
{
  static ID _raise_ID = rb_intern ("_raise");

  VALUE id, reason, minor, completed;

  id = rb_str_new2 (sex._rep_id ());
  minor = ULONG2NUM (sex.minor ());
  completed = INT2NUM ((int)sex.completed ());
  reason    = rb_str_new2 (_reason ? _reason : sex._info ().c_str ());

  rb_funcall (r2tao_cSystemException,
              _raise_ID, 4, id, reason, minor, completed);
}

R2TAO_EXPORT void r2tao_sysex(const CORBA::SystemException& ex)
{
  sysexc_raise(ex);
}

R2TAO_EXPORT void r2tao_unknown_userex(const CORBA::UnknownUserException& ex)
{
  VALUE exc = r2tao_Any2Ruby (const_cast<CORBA::UnknownUserException&> (ex).exception (),
                              ex._tao_type (), Qnil, Qnil);
  rb_exc_raise(exc);
}

R2TAO_EXPORT void r2tao_userex(const CORBA::UserException& ex)
{
  try
  {
    // only way to convert these exceptions to Ruby
    // is to marshal them, encapsulate in an any and
    // from there demarshal them into a Ruby version of
    // the exception
    // NOTE: this does not work on UserExceptions from TAO
    // core pseudo objects (like POA) since no marshaling
    // code is generated for these.
    TAO_OutputCDR outstrm;
    ex._tao_encode (outstrm);
    TAO_InputCDR instrm (outstrm);
    TAO::Unknown_IDL_Type *any_impl = nullptr;
    ACE_NEW_NORETURN (any_impl,
                    TAO::Unknown_IDL_Type (ex._tao_type ()));
    if (!any_impl)
    {
      X_CORBA (NO_MEMORY);
    }
    any_impl->_tao_decode (instrm);
    CORBA::Any any_;
    any_.replace (any_impl);

    VALUE exc = r2tao_Any2Ruby(any_, ex._tao_type (), Qnil, Qnil);
    rb_exc_raise(exc);
  }
  // marshaling/unmarshaling the exceptions might raise (system) exceptions
  catch (const CORBA::SystemException& ex)
  {
    sysexc_raise(ex);
  }
  catch (const CORBA::Exception& ex)
  {
    r2tao_corbaex(ex);
  }
  catch (...)
  {
    r2tao_anyex();
  }
}

R2TAO_EXPORT void r2tao_corbaex(const CORBA::Exception& ex)
{
  VALUE exc = rb_funcall(r2tao_cError, rb_intern("new"), 1,
                         rb_str_new2 (ex._rep_id ()));
  rb_exc_raise(exc);
}

R2TAO_EXPORT void r2tao_anyex()
{
  VALUE exc = rb_funcall(r2tao_cError, rb_intern("new"), 1,
                         rb_str_new2 ("Unknown exception raised"));
  rb_exc_raise(exc);
}


void r2tao_Init_Exception()
{
  if (r2tao_cError) return;

  r2tao_cError = rb_const_get (r2tao_nsCORBA, rb_intern ("InternalError"));

#define GET_EXCEPTION_CLASS(NAME)\
  r2tao_c ## NAME = rb_const_get(r2tao_nsCORBA, rb_intern(#NAME));

  GET_EXCEPTION_CLASS(SystemException);
  GET_EXCEPTION_CLASS(UserException);
  GET_EXCEPTION_CLASS(UNKNOWN);
  GET_EXCEPTION_CLASS(BAD_PARAM);
  GET_EXCEPTION_CLASS(NO_MEMORY);
  GET_EXCEPTION_CLASS(IMP_LIMIT);
  GET_EXCEPTION_CLASS(COMM_FAILURE);
  GET_EXCEPTION_CLASS(INV_OBJREF);
  GET_EXCEPTION_CLASS(NO_PERMISSION);
  GET_EXCEPTION_CLASS(INTERNAL);
  GET_EXCEPTION_CLASS(MARSHAL);
  GET_EXCEPTION_CLASS(INITIALIZE);
  GET_EXCEPTION_CLASS(NO_IMPLEMENT);
  GET_EXCEPTION_CLASS(BAD_TYPECODE);
  GET_EXCEPTION_CLASS(BAD_OPERATION);
  GET_EXCEPTION_CLASS(NO_RESOURCES);
  GET_EXCEPTION_CLASS(NO_RESPONSE);
  GET_EXCEPTION_CLASS(PERSIST_STORE);
  GET_EXCEPTION_CLASS(BAD_INV_ORDER);
  GET_EXCEPTION_CLASS(TRANSIENT);
  GET_EXCEPTION_CLASS(FREE_MEM);
  GET_EXCEPTION_CLASS(INV_IDENT);
  GET_EXCEPTION_CLASS(INV_FLAG);
  GET_EXCEPTION_CLASS(INTF_REPOS);
  GET_EXCEPTION_CLASS(BAD_CONTEXT);
  GET_EXCEPTION_CLASS(OBJ_ADAPTER);
  GET_EXCEPTION_CLASS(DATA_CONVERSION);
  GET_EXCEPTION_CLASS(OBJECT_NOT_EXIST);
  GET_EXCEPTION_CLASS(TRANSACTION_UNAVAILABLE);
  GET_EXCEPTION_CLASS(TRANSACTION_MODE);
  GET_EXCEPTION_CLASS(TRANSACTION_REQUIRED);
  GET_EXCEPTION_CLASS(TRANSACTION_ROLLEDBACK);
  GET_EXCEPTION_CLASS(INVALID_TRANSACTION);
  GET_EXCEPTION_CLASS(INV_POLICY);
  GET_EXCEPTION_CLASS(CODESET_INCOMPATIBLE);
  GET_EXCEPTION_CLASS(REBIND);
  GET_EXCEPTION_CLASS(TIMEOUT);
  GET_EXCEPTION_CLASS(BAD_QOS);
  GET_EXCEPTION_CLASS(INVALID_ACTIVITY);
  GET_EXCEPTION_CLASS(ACTIVITY_COMPLETED);
  GET_EXCEPTION_CLASS(ACTIVITY_REQUIRED);
  GET_EXCEPTION_CLASS(THREAD_CANCELLED);
#undef   GET_EXCEPTION_CLASS
}
