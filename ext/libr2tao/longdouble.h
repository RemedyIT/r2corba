/*--------------------------------------------------------------------
# longdouble.h - R2TAO CORBA LongDouble support
#
# Author: Martin Corino
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the R2CORBA LICENSE which is
# included with this program.
#
# Copyright (c) Remedy IT Expertise BV
#------------------------------------------------------------------*/

#if defined (NONNATIVE_LONGDOUBLE)
#define NATIVE_LONGDOUBLE ACE_CDR::LongDouble::NativeImpl
#else
#define NATIVE_LONGDOUBLE long double
#endif

VALUE r2tao_cld2rld(const NATIVE_LONGDOUBLE& _d);

#define RLD2CLD(_x) \
  ((NATIVE_LONGDOUBLE)*static_cast<ACE_CDR::LongDouble*> (DATA_PTR (_x)))

#define SETCLD2RLD(_x, _d) \
  ACE_CDR_LONG_DOUBLE_ASSIGNMENT ((*static_cast<ACE_CDR::LongDouble*> (DATA_PTR (_x))), _d)

#define CLD2RLD(_d) \
  r2tao_cld2rld(_d)


