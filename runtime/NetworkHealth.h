#pragma once
#include <stdio.h>

// Opt-in, bounded TCP statistics for sockets created through the guest's public
// socket/close imports. No payloads, addresses, ports or socket options are changed.
// Start/stop/sample are host-side calls; do not call them from the sampler queue.
void nh_start(FILE *log, unsigned seconds);
void nh_stop(void);
void nh_sample_now(void);
int nh_socket(int domain, int type, int protocol);
int nh_close(int fd);
