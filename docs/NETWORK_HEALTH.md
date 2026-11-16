# Opt-in connection diagnostics

Launch Wolkara with `--network-health`, then start the game normally. The flag
retains the normal launcher and does not change the game's arguments. It lasts
only for that process; an ordinary launch does not activate the diagnostic hooks.

The runtime observes TCP sockets created through its public `socket` import and
forgets them on `close`. Every two seconds, for at most fifteen minutes, it queries
`TCP_CONNECTION_INFO` and `FIONREAD` on up to 32 tracked sockets. Sampling runs on
a separate serial queue. The native return values and errno are preserved.
It never consumes received data, changes socket options or routes, retries calls,
sends probe traffic, or records payloads, addresses, ports, credentials or game
memory. Records in `Documents/native-guest.log` start with `[net-health]` and use
anonymous per-session connection numbers.

The counters are cumulative except queue/window sizes and RTT. Compare successive
records while the symptom occurs:

- Rising retransmission counters and outgoing queued bytes can indicate transport
  delivery trouble; they alone do not identify Wi-Fi, the route or the server.
- Incoming bytes with a persistently growing unread queue suggest the application
  is not consuming received socket data promptly.
- A zero peer window means the peer is not currently offering receive capacity.
- Small RTT and empty local queues do not prove that the server is processing
  game actions normally. An idle connection can retain an old RTT estimate.

Coverage is limited to TCP sockets created through the observed import. UDP,
sockets opened internally by native frameworks, unsupported kernel queries and
capacity omissions are not evidence of a healthy connection. Check `tracked`,
`capacity_omitted` and `unavailable_errno` before interpreting the report. The
sampler does not inspect game state or identify which connection carries chat
versus world traffic. A descriptor closed outside the observed import may remain
listed until a failed query or a subsequently observed socket reuses it.

`bash tools/test_network_health.sh` uses only an original local TCP fixture and
ASan/UBSan. It verifies counters, unread bytes without consuming the payload,
error preservation, descriptor reuse, UDP exclusion, stop and timer expiry.
The same fixture can be compiled for the iOS simulator. Device results are needed
to diagnose an actual game session; synthetic success is not a network fix.
