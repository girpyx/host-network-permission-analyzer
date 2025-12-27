## Layer 2 — Link-Level Communication Permission

Layer 2 analysis determines whether the host is permitted to exchange
link-layer frames with other devices on the same network segment.

A Layer 2 communication exists when:
- A network interface is operational
- The physical or wireless link is active
- A peer MAC address is known or resolvable

Authoritative evidence sources:
- rfkill
- ip link
- iw
- ip neigh

Layer 2 permission is granted if frame transmission and reception are possible.
Failure at this layer prevents all higher-layer communication.

---

## Layer 3 — Network-Level Communication Permission

Layer 3 analysis determines whether the host is permitted to send IP packets
to a destination address.

A Layer 3 communication exists when:
- The host has a valid IP address
- A routing decision exists for the destination
- The next hop is reachable at Layer 2

Authoritative evidence sources:
- ip addr
- ip route get
- ip neigh
- ping / ICMP responses

Layer 3 permission does not imply application-level reachability; it only
confirms packet routing viability.


