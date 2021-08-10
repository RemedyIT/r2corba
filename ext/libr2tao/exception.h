/*--------------------------------------------------------------------
# exception.h - R2TAO CORBA exception support
#
# Author: Martin Corino
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the R2CORBA LICENSE which is
# included with this program.
#
# Copyright (c) Remedy IT Expertise BV
#------------------------------------------------------------------*/

#ifndef __R2TAO_EXCEPTION_H
#define __R2TAO_EXCEPTION_H

#include "required.h"
#include <tao/SystemException.h>
#include <tao/UserException.h>
#include "tao/DynamicInterface/Unknown_User_Exception.h"

/*
 * see 19.16 "Mapping for Exception Types" and 19.22 "Handling Exceptions".
 *
 */
#define R2TAO_TRY   try
#define R2TAO_CATCH \
  catch (const CORBA::SystemException& sex) \
  { \
    r2tao_sysex(sex); \
  } \
  catch (const CORBA::UnknownUserException& uex) \
  { \
    r2tao_unknown_userex (uex); \
  } \
  catch (const CORBA::UserException& uex) \
  { \
    r2tao_userex (uex); \
  } \
  catch (const CORBA::Exception& cex) \
  { \
    r2tao_corbaex (cex); \
  } \
  catch (...) \
  { \
    r2tao_anyex (); \
  }

/* check environment argument and raise if need.*/
extern R2TAO_EXPORT void r2tao_sysex(const CORBA::SystemException& ex);
extern R2TAO_EXPORT void r2tao_unknown_userex(const CORBA::UnknownUserException& ex);
extern R2TAO_EXPORT void r2tao_userex(const CORBA::UserException& ex);
extern R2TAO_EXPORT void r2tao_corbaex(const CORBA::Exception& ex);
extern R2TAO_EXPORT void r2tao_anyex();

extern VALUE r2tao_cError;
extern R2TAO_EXPORT VALUE r2tao_cSystemException;
extern R2TAO_EXPORT VALUE r2tao_cUserException;
extern R2TAO_EXPORT VALUE r2tao_cUNKNOWN;
extern R2TAO_EXPORT VALUE r2tao_cBAD_PARAM;
extern R2TAO_EXPORT VALUE r2tao_cNO_MEMORY;
extern R2TAO_EXPORT VALUE r2tao_cIMP_LIMIT;
extern R2TAO_EXPORT VALUE r2tao_cCOMM_FAILURE;
extern R2TAO_EXPORT VALUE r2tao_cINV_OBJREF;
extern R2TAO_EXPORT VALUE r2tao_cNO_PERMISSION;
extern R2TAO_EXPORT VALUE r2tao_cINTERNAL;
extern R2TAO_EXPORT VALUE r2tao_cMARSHAL;
extern R2TAO_EXPORT VALUE r2tao_cINITIALIZE;
extern R2TAO_EXPORT VALUE r2tao_cNO_IMPLEMENT;
extern R2TAO_EXPORT VALUE r2tao_cBAD_TYPECODE;
extern R2TAO_EXPORT VALUE r2tao_cBAD_OPERATION;
extern R2TAO_EXPORT VALUE r2tao_cNO_RESOURCES;
extern R2TAO_EXPORT VALUE r2tao_cNO_RESPONSE;
extern R2TAO_EXPORT VALUE r2tao_cPERSIST_STORE;
extern R2TAO_EXPORT VALUE r2tao_cBAD_INV_ORDER;
extern R2TAO_EXPORT VALUE r2tao_cTRANSIENT;
extern R2TAO_EXPORT VALUE r2tao_cFREE_MEM;
extern R2TAO_EXPORT VALUE r2tao_cINV_IDENT;
extern R2TAO_EXPORT VALUE r2tao_cINV_FLAG;
extern R2TAO_EXPORT VALUE r2tao_cINTF_REPOS;
extern R2TAO_EXPORT VALUE r2tao_cBAD_CONTEXT;
extern R2TAO_EXPORT VALUE r2tao_cOBJ_ADAPTER;
extern R2TAO_EXPORT VALUE r2tao_cDATA_CONVERSION;
extern R2TAO_EXPORT VALUE r2tao_cOBJECT_NOT_EXIST;
extern R2TAO_EXPORT VALUE r2tao_cTRANSACTION_REQUIRED;
extern R2TAO_EXPORT VALUE r2tao_cTRANSACTION_ROLLEDBACK;
extern R2TAO_EXPORT VALUE r2tao_cINVALID_TRANSACTION;
extern R2TAO_EXPORT VALUE r2tao_cINV_POLICY;
extern R2TAO_EXPORT VALUE r2tao_cCODESET_INCOMPATIBLE;

extern void r2tao_Init_Exception();

#define X_CORBA(ex) \
  rb_raise (r2tao_c ## ex, " ")

#define X_CORBA_(ex,msg) \
  rb_raise (r2tao_c ## ex, msg)

#define CHECK_RTYPE(v,t)\
  if (rb_type ((v)) != (t)) \
  { throw CORBA::BAD_PARAM(0, CORBA::COMPLETED_NO); }

#endif
