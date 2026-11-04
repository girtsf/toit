// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the tests/LICENSE file.

import expect show *
import net

import system.api.network show NetworkService NetworkServiceClient
import system.base.network show ProxyingNetworkServiceProvider
import system.services show ServiceProvider ServiceResource

TAG ::= "bind-to-interface-$(random 1024)"
SELECTOR ::= NetworkService.SELECTOR.restrict.allow --tag=TAG

main:
  service := Provider
  service.install
  client := (NetworkServiceClient SELECTOR).open as NetworkServiceClient

  test-requires-proxied-address service client
  test-bound-sockets service client
  test-unbound-sockets service client

  client.close
  service.uninstall

test-requires-proxied-address service/Provider client/NetworkServiceClient:
  service.mask = 0
  expect-throw "Network service doesn't report its interface address":
    net.Client client --name=null client.connect --bind-to-interface
  // The connection must not be left open.
  expect-null service.network

// Host sockets can't be bound, so reaching the primitive shows up as UNIMPLEMENTED.
test-bound-sockets service/Provider client/NetworkServiceClient:
  service.mask = NetworkService.PROXY-ADDRESS
  network := net.Client client --name=null client.connect --bind-to-interface
  try:
    expect-throw "UNIMPLEMENTED": network.udp-open
    expect-throw "UNIMPLEMENTED":
      network.tcp-connect (net.SocketAddress (net.IpAddress #[127, 0, 0, 1]) 1234)

    // Listening and multicast sockets aren't bound.
    server := network.tcp-listen 0
    server.close
    multicast := network.udp-open-multicast
    multicast.close
  finally:
    network.close

test-unbound-sockets service/Provider client/NetworkServiceClient:
  service.mask = NetworkService.PROXY-ADDRESS
  network := net.Client client --name=null client.connect
  try:
    socket := network.udp-open
    socket.close
  finally:
    network.close

class Provider extends ProxyingNetworkServiceProvider:
  mask/int := 0
  network/net.Interface? := null

  constructor:
    super "system/network/test" --major=1 --minor=0
    provides NetworkService.SELECTOR
        --handler=this
        --priority=ServiceProvider.PRIORITY-UNPREFERRED
        --tags=[TAG]

  proxy-mask -> int:
    return mask

  open-network -> net.Interface:
    network = net.open
    return network

  close-network network/net.Interface -> none:
    this.network = null
    network.close

  address resource/ServiceResource -> ByteArray:
    return network.address.to-byte-array
