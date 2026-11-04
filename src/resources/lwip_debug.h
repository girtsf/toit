// Copyright (C) 2026 Toit contributors.
//
// This library is free software; you can redistribute it and/or
// modify it under the terms of the GNU Lesser General Public
// License as published by the Free Software Foundation; version
// 2.1 only.
//
// This library is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
// Lesser General Public License for more details.
//
// The license can be found in the file `LICENSE` in the top level
// directory of this repository.

#pragma once

#include <lwip/ip_addr.h>
#include <lwip/pbuf.h>

#include "../top.h"

namespace toit {

// One socket, as reported by the `sockets_info` debug primitives of the tcp
// and udp modules. Decoded by lib/net/debug.toit, which must be kept in sync.
struct SocketDebugRecord {
  static const uint8 PROTOCOL_TCP = 0;
  static const uint8 PROTOCOL_UDP = 1;

  static const uint8 KIND_LISTEN = 0;
  static const uint8 KIND_ACTIVE = 1;
  static const uint8 KIND_TIME_WAIT = 2;

  static const uint8 FLAG_OWNED = 1 << 0;       // Belongs to a Toit process.
  static const uint8 FLAG_IN_BACKLOG = 1 << 1;  // Connected, not yet accepted.
  static const uint8 FLAG_IPV6 = 1 << 2;        // Addresses not shown.

  uint8 protocol;
  uint8 kind;
  uint8 state;          // lwIP's tcp_state.
  uint8 flags;
  uint16 local_port;
  uint16 remote_port;
  uint8 local_ip[4];
  uint8 remote_ip[4];
  int32 owner;          // Process id, or -1.
  uint16 queued;        // Listener: backlog length. UDP: datagrams queued.
  uint16 pbufs;         // Received pbufs held, unread.
  uint16 custom_pbufs;  // Of those, the ones wrapping a driver's buffer.
  uint16 ooseq_pbufs;   // Out-of-order segments' pbufs.
  uint32 bytes;         // Received bytes held, unread.
  uint16 send_queue;    // pbufs queued for sending.
  uint8 retransmits;    // Retransmissions of the oldest unacked segment.
  uint8 padding;
  uint32 dropped;       // UDP: datagrams dropped because the queue was full.

  void set_addresses(const ip_addr_t* local, const ip_addr_t* remote) {
    if (IP_IS_V6(local) || IP_IS_V6(remote)) {
      flags |= FLAG_IPV6;
      return;
    }
    uint32 l = ip_addr_get_ip4_u32(local);
    uint32 r = ip_addr_get_ip4_u32(remote);
    memcpy(local_ip, &l, 4);
    memcpy(remote_ip, &r, 4);
  }

  void count_pbufs(const pbuf* p) {
    for (const pbuf* q = p; q != null; q = q->next) {
      pbufs++;
      if ((q->flags & PBUF_FLAG_IS_CUSTOM) != 0) custom_pbufs++;
    }
  }
};

static_assert(sizeof(SocketDebugRecord) == 40, "lib/net/debug.toit decodes 40-byte records");

// Collects records into a caller-provided buffer, counting those that did not
// fit, so the caller can retry with a bigger one.
class SocketDebugWriter {
 public:
  SocketDebugWriter(uint8* buffer, word length)
      : buffer_(buffer)
      , capacity_(length / sizeof(SocketDebugRecord)) {}

  void add(const SocketDebugRecord& record) {
    if (count_ < capacity_) {
      memcpy(buffer_ + count_ * sizeof(SocketDebugRecord), &record, sizeof(record));
    }
    count_++;
  }

  word count() const { return count_; }

 private:
  uint8* buffer_;
  word capacity_;
  word count_ = 0;
};

} // namespace toit
