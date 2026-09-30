/*--------------------------------------------------------------------
# fixed.h - R2TAO CORBA fixed point support
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the R2CORBA LICENSE which is
# included with this program.
#
# Copyright (c) Remedy IT Expertise BV
#------------------------------------------------------------------*/
#ifndef __R2TAO_FIXED_H
#define __R2TAO_FIXED_H

#include "tao/CDR.h"
#include "tao/AnyTypeCode/TypeCode.h"
#include "tao/SystemException.h"

inline ACE_CDR::Fixed r2tao_read_fixed (TAO_InputCDR& cdr,
                                       CORBA::TypeCode_ptr tc)
{
  const CORBA::UShort digits = tc->fixed_digits ();
  if (digits == 0 || digits > ACE_CDR::Fixed::MAX_DIGITS)
    throw CORBA::MARSHAL ();

  ACE_CDR::Octet octets[16];
  const int count = (digits + 2) / 2;
  for (int i = 0; i < count; ++i)
    if (!cdr.read_octet (octets[i]))
      throw CORBA::MARSHAL ();

  // For an even number of digits the high nibble is a leading zero.
  if (digits % 2 == 0 && (octets[0] >> 4) != 0)
    throw CORBA::MARSHAL ();

  for (int i = 0; i < count; ++i)
  {
    const unsigned int high = octets[i] >> 4;
    const unsigned int low = octets[i] & 0xf;
    if ((i != 0 || digits % 2 != 0) && high > 9)
      throw CORBA::MARSHAL ();
    if (i == count - 1)
    {
      if (low != ACE_CDR::Fixed::POSITIVE && low != ACE_CDR::Fixed::NEGATIVE)
        throw CORBA::MARSHAL ();
    }
    else if (low > 9)
      throw CORBA::MARSHAL ();
  }

  return ACE_CDR::Fixed::from_octets (octets, count, tc->fixed_scale ());
}

#endif /* __R2TAO_FIXED_H */
