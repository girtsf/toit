// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by an MIT-style license that can be
// found in the lib/LICENSE file.

/**
Debugging views of the lwIP network stack.

They see the whole device, not just the calling process: every TCP and UDP
  socket, of every container, and those of the system itself.

A received packet is held in a buffer until the program owning the socket
  reads it. On the ESP32 that buffer is usually the WiFi driver's own, of
  which there are few (CONFIG_ESP_WIFI_DYNAMIC_RX_BUFFER_NUM), and when they
  run out the device stops receiving anything at all. $sockets shows which
  sockets hold them.
*/

import io
import net

TCP-STATES_ ::= [
  "closed", "listen", "syn-sent", "syn-received", "established", "fin-wait-1",
  "fin-wait-2", "close-wait", "closing", "last-ack", "time-wait",
]

/** A TCP or UDP socket of lwIP, as returned by $sockets. */
class SocketInfo:
  static PROTOCOL-TCP ::= 0
  static PROTOCOL-UDP ::= 1

  static KIND-LISTEN ::= 0
  static KIND-ACTIVE ::= 1
  static KIND-TIME-WAIT ::= 2

  static FLAG-OWNED_ ::= 1 << 0
  static FLAG-IN-BACKLOG_ ::= 1 << 1
  static FLAG-IPV6_ ::= 1 << 2

  static SIZE_ ::= 40

  /** Either $PROTOCOL-TCP or $PROTOCOL-UDP. */
  protocol/int
  /** For TCP, one of $KIND-LISTEN, $KIND-ACTIVE, or $KIND-TIME-WAIT. */
  kind/int
  /** For TCP, lwIP's state of the connection; see $state-name. */
  state/int
  /** The local address, or null if it is an IPv6 one. */
  local/net.SocketAddress?
  /**
  The remote address, or null if it is an IPv6 one.

  For a UDP socket that is not connected, and a listening TCP socket, the
    address is 0.0.0.0 and the port 0.
  */
  remote/net.SocketAddress?
  /**
  The id of the Toit process the socket belongs to, or null if it is not a
    Toit socket, or one that is already closed.

  The system process uses some too, for DNS and the like.
  */
  owner/int?
  /**
  Whether the connection is waiting in the backlog of a listening socket:
    connected, but not accepted by the program yet.
  */
  is-in-backlog/bool
  /** For a listening TCP socket, the connections in its backlog. For UDP, the datagrams received, but not read. */
  queued/int
  /** The received buffers (lwIP pbufs) held, because the program has not read them yet. */
  pbufs/int
  /**
  Of the $pbufs, the ones wrapping a buffer of the network driver, and so
    taking one away from it.
  */
  driver-pbufs/int
  /** For TCP, the buffers of segments received out of order. */
  out-of-order-pbufs/int
  /** The received bytes held, because the program has not read them yet. */
  bytes/int
  /** For TCP, the buffers queued for sending, or sent but not acknowledged. */
  send-queue/int
  /**
  For TCP, how often the oldest unacknowledged segment has been sent again.

  It keeps going up if acknowledgments do not arrive.
  */
  retransmits/int
  /** For UDP, the datagrams dropped because too many were queued. */
  dropped/int

  constructor.from-bytes_ record/ByteArray:
    le := io.LITTLE-ENDIAN
    protocol = record[0]
    kind = record[1]
    state = record[2]
    flags := record[3]
    is-ipv4 := flags & FLAG-IPV6_ == 0
    local = is-ipv4 ? (net.SocketAddress (net.IpAddress record[8..12]) (le.uint16 record 4)) : null
    remote = is-ipv4 ? (net.SocketAddress (net.IpAddress record[12..16]) (le.uint16 record 6)) : null
    owner = flags & FLAG-OWNED_ != 0 ? (le.int32 record 16) : null
    is-in-backlog = flags & FLAG-IN-BACKLOG_ != 0
    queued = le.uint16 record 20
    pbufs = le.uint16 record 22
    driver-pbufs = le.uint16 record 24
    out-of-order-pbufs = le.uint16 record 26
    bytes = le.uint32 record 28
    send-queue = le.uint16 record 32
    retransmits = record[34]
    dropped = le.uint32 record 36

  /** Whether this is a TCP socket. */
  is-tcp -> bool: return protocol == PROTOCOL-TCP

  /** The name of the TCP $state, like "established". */
  state-name -> string:
    return state < TCP-STATES_.size ? TCP-STATES_[state] : "$state"

  stringify -> string:
    result := is-tcp ? "tcp $state-name" : "udp"
    result += " $(local or "ipv6") -> $(remote or "ipv6")"
    result += owner ? " pid $owner" : " no owner"
    if is-in-backlog: result += " in backlog"
    if is-tcp and kind == KIND-LISTEN: result += " backlog $queued"
    if not is-tcp: result += " queued $queued dropped $dropped"
    result += " held $pbufs pbufs ($driver-pbufs driver) $bytes bytes"
    if is-tcp:
      result += " out-of-order $out-of-order-pbufs send-queue $send-queue retransmits $retransmits"
    return result

/** An entry of lwIP's ARP table, as returned by $arp-table. */
class ArpEntry:
  address/net.IpAddress
  /** The MAC address, 6 bytes. */
  mac/ByteArray
  /** The name of lwIP's network interface, like "st" for the WiFi station. */
  interface-name/string

  constructor .address .mac .interface-name:

  stringify -> string:
    return "$address $((List mac.size: "$(%02x mac[it])").join ":") $interface-name"

/**
Returns all TCP and UDP sockets of lwIP, as $SocketInfo objects.

Throws "UNIMPLEMENTED" if the network stack is not lwIP.
*/
sockets -> List:
  records := (records_ SocketInfo.SIZE_: tcp-sockets-info_ it) + (records_ SocketInfo.SIZE_: udp-sockets-info_ it)
  return records.map: SocketInfo.from-bytes_ it

/**
Returns the stable entries of lwIP's ARP table, as $ArpEntry objects.

Entries waiting for an answer to their ARP request are not included, so a
  device that receives no ARP replies has its entries disappear one by one as
  they expire.
*/
arp-table -> List:
  records := records_ ARP-RECORD-SIZE_: arp-table_ it
  return records.map: | record/ByteArray |
    ArpEntry (net.IpAddress record[..4]) record[4..10] record[10..12].to-string

ARP-RECORD-SIZE_ ::= 12

LWIP-STATS-PROTOCOLS_ ::= ["link", "etharp", "ip", "icmp", "udp", "tcp"]
LWIP-STATS-COUNTERS_ ::= [
  "xmit", "recv", "fw", "drop", "chkerr", "lenerr",
  "memerr", "rterr", "proterr", "opterr", "err", "cachehit",
]

/**
Returns lwIP's packet counters, as a map from protocol ("link", "etharp",
  "ip", "icmp", "udp", "tcp") to a map from counter name to count. The
  counters are those of lwIP's `struct stats_proto`, like "xmit", "recv",
  "drop", and "memerr".

Returns null if lwIP was built without statistics (CONFIG_LWIP_STATS).
*/
lwip-stats -> Map?:
  bytes := ByteArray LWIP-STATS-PROTOCOLS_.size * LWIP-STATS-COUNTERS_.size * 4
  if not lwip-stats_ bytes: return null
  result := {:}
  LWIP-STATS-PROTOCOLS_.size.repeat: | protocol/int |
    counters := {:}
    LWIP-STATS-COUNTERS_.size.repeat: | counter/int |
      counters[LWIP-STATS-COUNTERS_[counter]] = io.LITTLE-ENDIAN.uint32 bytes (protocol * LWIP-STATS-COUNTERS_.size + counter) * 4
    // A protocol built without counters has all of them at 0xffffffff.
    if counters["xmit"] != 0xffff_ffff: result[LWIP-STATS-PROTOCOLS_[protocol]] = counters
  return result

/** The buffer status of the WiFi driver, for $wifi-statistics-dump. */
WIFI-STATISTICS-BUFFER ::= 1 << 0
/** The receive and transmit status of the WiFi driver, for $wifi-statistics-dump. */
WIFI-STATISTICS-RXTX ::= 1 << 1
/** The hardware status of the WiFi driver, for $wifi-statistics-dump. */
WIFI-STATISTICS-HW ::= 1 << 2
/** The diagnostic status of the WiFi driver, for $wifi-statistics-dump. */
WIFI-STATISTICS-DIAG ::= 1 << 3
/** The power save status of the WiFi driver, for $wifi-statistics-dump. */
WIFI-STATISTICS-PS ::= 1 << 4
/** All status of the WiFi driver, for $wifi-statistics-dump. */
WIFI-STATISTICS-ALL ::= -1

/**
Prints the WiFi driver's statistics for the given $modules, a combination of
  the `WIFI-STATISTICS-*` constants, to the serial console.

What it prints is up to the closed-source driver (`esp_wifi_statis_dump`).
  It goes to the console only: not to stdout, and not to the print service.

Throws if WiFi is not started.
*/
wifi-statistics-dump modules/int=WIFI-STATISTICS-BUFFER -> none:
  wifi-statis-dump_ modules

/** Calls $block with a buffer until it fits the records it says there are, and returns them split. */
records_ size/int [block] -> List:
  capacity := 32
  while true:
    buffer := ByteArray capacity * size
    count := block.call buffer
    if count <= capacity:
      return List count: buffer[it * size..(it + 1) * size]
    capacity = count + 8

tcp-sockets-info_ buffer/ByteArray -> int:
  #primitive.tcp.sockets-info

udp-sockets-info_ buffer/ByteArray -> int:
  #primitive.udp.sockets-info

arp-table_ buffer/ByteArray -> int:
  #primitive.tcp.arp-table

lwip-stats_ buffer/ByteArray -> bool:
  #primitive.tcp.lwip-stats

wifi-statis-dump_ modules/int -> none:
  #primitive.wifi.statis-dump
