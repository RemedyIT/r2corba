/*--------------------------------------------------------------------
# orb.h - R2TAO CORBA ORB support
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
#ifndef __R2TAO_ORB_H
#define __R2TAO_ORB_H

#include "required.h"
#include "tao/ORB.h"

extern void r2tao_Init_ORB();

// Ruby CORBA::Native::ORB
extern R2TAO_EXPORT VALUE r2corba_cORB;
// Ruby CORBA::ORB
extern R2TAO_EXPORT VALUE r2tao_cORB;

// wraps TAO CORBA::ORB in Ruby CORBA::Native::ORB
extern R2TAO_EXPORT VALUE r2tao_ORB_t2r(CORBA::ORB_ptr obj);
// unwraps TAO CORBA::ORB from Ruby CORBA::Native::ORB
extern R2TAO_EXPORT CORBA::ORB_ptr r2tao_ORB_r2t(VALUE obj);

// wraps TAO CORBA::ORB as Ruby CORBA::Native::ORB in CORBA::ORB
extern R2TAO_EXPORT VALUE r2corba_ORB_t2r(CORBA::ORB_ptr obj);
// unwraps TAO CORBA::ORB from Ruby CORBA::Native::ORB in CORBA::ORB
extern R2TAO_EXPORT CORBA::ORB_ptr r2corba_ORB_r2t(VALUE obj);

#endif
