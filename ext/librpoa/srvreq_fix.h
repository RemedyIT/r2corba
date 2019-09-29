/*--------------------------------------------------------------------
# srvreq_fix.h - R2TAO CORBA Servant support
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

#ifndef __SRVREQ_FIX_H__
#define __SRVREQ_FIX_H__

#include "tao/TAO_Server_Request.h"
#include "tao/CDR.h"
#include "ace/Atomic_Op.h"

namespace R2CORBA
{
  class ServerRequest;
  typedef ServerRequest *ServerRequest_ptr;

  typedef TAO_Pseudo_Var_T<ServerRequest> ServerRequest_var;
  typedef TAO_Pseudo_Out_T<ServerRequest> ServerRequest_out;

  /**
   * @class ServerRequest
   *
   * @brief Class representing the CORBA ServerRequest pseudo-object.
   *
   * R2CORBA fixed version for older (< 6.0.2) TAO versions
   */
  class ServerRequest
  {
  public:
    ServerRequest (TAO_ServerRequest &orb_server_request);

    ~ServerRequest (void);

    void arguments (CORBA::NVList_ptr &list);

    void set_result (const CORBA::Any &value);

    void set_exception (const CORBA::Any &value);

    void dsi_marshal (void);

    CORBA::Context_ptr ctx (void) const;

    void ctx (CORBA::Context_ptr);

    const char *operation (void) const;

    static ServerRequest_ptr _duplicate (ServerRequest_ptr);
    static ServerRequest_ptr _nil (void);

    CORBA::ULong _incr_refcount (void);
    CORBA::ULong _decr_refcount (void);

    void _tao_lazy_evaluation (bool lazy_evaluation);

    int _tao_incoming_byte_order (void) const;

    void _tao_reply_byte_order (int byte_order);

    TAO_ServerRequest & _tao_server_request (void);

    void gateway_exception_reply (ACE_CString &raw_exception);

    typedef R2CORBA::ServerRequest_ptr _ptr_type;
    typedef R2CORBA::ServerRequest_var _var_type;
    typedef R2CORBA::ServerRequest_out _out_type;

  private:
    bool lazy_evaluation_;
    CORBA::Context_ptr ctx_;
    CORBA::NVList_ptr params_;
    CORBA::Any_ptr retval_;
    CORBA::Any_ptr exception_;
    ACE_Atomic_Op<TAO_SYNCH_MUTEX, unsigned long> refcount_;
    TAO_ServerRequest &orb_server_request_;
    bool sent_gateway_exception_;
  };
} // End R2CORBA namespace

inline R2CORBA::ServerRequest_ptr
R2CORBA::ServerRequest::_duplicate (R2CORBA::ServerRequest_ptr x)
{
  if (x != 0)
    {
      x->_incr_refcount ();
    }

  return x;
}

inline R2CORBA::ServerRequest_ptr
R2CORBA::ServerRequest::_nil (void)
{
  return static_cast <R2CORBA::ServerRequest_ptr>(0);
}

inline CORBA::Context_ptr
R2CORBA::ServerRequest::ctx (void) const
{
  return this->ctx_;
}

inline void
R2CORBA::ServerRequest::ctx (CORBA::Context_ptr ctx)
{
  this->ctx_ = ctx;
}

inline const char *
R2CORBA::ServerRequest::operation (void) const
{
  return this->orb_server_request_.operation ();
}

inline void
R2CORBA::ServerRequest::_tao_lazy_evaluation (bool lazy_evaluation)
{
  this->lazy_evaluation_ = lazy_evaluation;
}

inline int
R2CORBA::ServerRequest::_tao_incoming_byte_order (void) const
{
  return this->orb_server_request_.incoming ()->byte_order ();
}

inline void
R2CORBA::ServerRequest::_tao_reply_byte_order (int byte_order)
{
  this->orb_server_request_.outgoing ()->reset_byte_order (byte_order);
}


inline TAO_ServerRequest &
R2CORBA::ServerRequest::_tao_server_request (void)
{
  return this->orb_server_request_;
}

#endif
