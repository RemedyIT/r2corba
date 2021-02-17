/*--------------------------------------------------------------------
# r2tao_ext.h - R2TAO CORBA basic support
#
# Author: Martin Corino
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the R2CORBA LICENSE which is
# included with this program.
#
# Copyright (c) Remedy IT Expertise BV
#------------------------------------------------------------------*/
#ifndef __R2TAO_EXT_H
#define __R2TAO_EXT_H

#if defined (OLD_MSC_VER)
  // un-fudge the version macro here that was fudged
  // in required.h otherwise ACE will complain
  #undef _MSC_VER
  #define _MSC_VER OLD_MSC_VER
#endif

#include <ace/config-lite.h>
#if defined (WIN32) || defined (_MSC_VER) || defined (__MINGW32__)
// Ruby ships its own msghdr
# undef ACE_LACKS_MSGHDR
// Ruby ships its own iovec
# undef ACE_LACKS_IOVEC
// Resolve conflict between mingw and ruby gettimeofday
# define ACE_LACKS_SYS_TIME_H
#endif

#endif

