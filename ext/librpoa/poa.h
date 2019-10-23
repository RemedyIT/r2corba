/*--------------------------------------------------------------------
# poa.h - R2TAO CORBA PortableServer support
#
# Author: Martin Corino
#
# Copyright (c) Remedy IT Expertise BV
#------------------------------------------------------------------*/
#ifndef __R2TAO_POA_H
#define __R2TAO_POA_H

#include "required.h"
#include "rpoa_export.h"
#include "tao/PortableServer/PortableServer.h"

R2TAO_POA_EXPORT PortableServer::POA_ptr r2tao_POA_r2t(VALUE obj);

extern R2TAO_POA_EXPORT VALUE r2tao_nsPOA;
extern VALUE r2tao_cServant;

VALUE r2tao_ObjectId_t2r(const PortableServer::ObjectId& oid);

#endif

