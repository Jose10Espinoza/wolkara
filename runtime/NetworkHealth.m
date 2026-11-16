#import "NetworkHealth.h"
#import <Foundation/Foundation.h>
#include <errno.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <pthread.h>
#include <stdatomic.h>
#include <sys/ioctl.h>
#include <sys/socket.h>
#include <time.h>
#include <unistd.h>

// Deliberately bounded: no packet capture, DNS lookup, traffic generation or
// per-send/receive callback. The kernel supplies counters every two seconds.
enum { NHCapacity = 32, NHMaximumSeconds = 900 };
typedef struct { int fd; unsigned identifier; } NHSocket;
static NHSocket sockets[NHCapacity];
static pthread_mutex_t socketLock = PTHREAD_MUTEX_INITIALIZER;
static atomic_bool enabled;
static unsigned nextIdentifier, omitted;
static dispatch_source_t timer;
static FILE *output;
static double began, deadline;

static double Now(void) {
    struct timespec time; clock_gettime(CLOCK_MONOTONIC, &time);
    return time.tv_sec + time.tv_nsec / 1e9;
}
static dispatch_queue_t Queue(void) {
    static dispatch_queue_t queue; static dispatch_once_t once;
    dispatch_once(&once, ^{ queue = dispatch_queue_create("local.wolkara.network-health", DISPATCH_QUEUE_SERIAL); });
    return queue;
}
static void StopOnQueue(void) {
    pthread_mutex_lock(&socketLock);
    atomic_store(&enabled, false);
    for (unsigned i = 0; i < NHCapacity; i++) sockets[i].fd = -1;
    pthread_mutex_unlock(&socketLock);
    if (timer) dispatch_source_cancel(timer);
    timer = nil;
    if (output) { fprintf(output, "[net-health] stopped\n"); fflush(output); }
    output = NULL;
}
static void SampleOnQueue(void) {
    if (!output || !atomic_load(&enabled)) return;
    struct {
        unsigned identifier;
        int error, pending;
        struct tcp_connection_info tcp;
    } samples[NHCapacity] = {0};
    unsigned count = 0, skipped;
    // A wrapped close cannot recycle a descriptor while its statistics are
    // being read. Only nonblocking kernel queries run under this lock.
    pthread_mutex_lock(&socketLock);
    for (unsigned i = 0; i < NHCapacity; i++) {
        if (sockets[i].fd < 0) continue;
        samples[count].identifier = sockets[i].identifier;
        socklen_t length = sizeof samples[count].tcp;
        if (getsockopt(sockets[i].fd, IPPROTO_TCP, TCP_CONNECTION_INFO, &samples[count].tcp, &length)) {
            samples[count].error = errno;
            if (errno == EBADF || errno == ENOTSOCK) sockets[i].fd = -1;
        }
        samples[count].pending = -1;
        int pending;
        if (!ioctl(sockets[i].fd, FIONREAD, &pending)) samples[count].pending = pending;
        count++;
    }
    skipped = omitted;
    pthread_mutex_unlock(&socketLock);
    double elapsed = Now() - began;
    fprintf(output, "[net-health] t=%.1f tracked=%u capacity_omitted=%u\n", elapsed, count, skipped);
    for (unsigned i = 0; i < count; i++) {
        struct tcp_connection_info *tcp = &samples[i].tcp;
        if (samples[i].error) {
            fprintf(output, "[net-health] id=%u unavailable_errno=%d\n", samples[i].identifier, samples[i].error);
            continue;
        }
        fprintf(output, "[net-health] id=%u state=%u rtt_ms=%u srtt_ms=%u rto_ms=%u "
            "tx_bytes=%llu rx_bytes=%llu retrans_bytes=%llu retrans_packets=%llu "
            "out_of_order_bytes=%llu tx_buffer=%u rx_pending=%d peer_window=%u receive_window=%u\n",
            samples[i].identifier, tcp->tcpi_state, tcp->tcpi_rttcur, tcp->tcpi_srtt, tcp->tcpi_rto,
            (unsigned long long)tcp->tcpi_txbytes, (unsigned long long)tcp->tcpi_rxbytes,
            (unsigned long long)tcp->tcpi_txretransmitbytes, (unsigned long long)tcp->tcpi_txretransmitpackets,
            (unsigned long long)tcp->tcpi_rxoutoforderbytes, tcp->tcpi_snd_sbbytes, samples[i].pending,
            tcp->tcpi_snd_wnd, tcp->tcpi_rcv_wnd);
    }
    fflush(output);
}
void nh_start(FILE *log, unsigned seconds) {
    int saved = errno;
    dispatch_sync(Queue(), ^{
        StopOnQueue();
        if (!log || !seconds) return;
        output = log; began = Now(); deadline = began + MIN(seconds, NHMaximumSeconds);
        pthread_mutex_lock(&socketLock);
        nextIdentifier = omitted = 0; atomic_store(&enabled, true);
        pthread_mutex_unlock(&socketLock);
        fprintf(output, "[net-health] enabled interval_s=2 duration_s=%u tcp_only=1 payloads=0 endpoints=0\n",
            MIN(seconds, NHMaximumSeconds));
        fflush(output);
        timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, Queue());
        dispatch_source_set_timer(timer, dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), 2 * NSEC_PER_SEC, NSEC_PER_SEC / 5);
        dispatch_source_set_event_handler(timer, ^{
            @autoreleasepool {
                SampleOnQueue();
                if (Now() >= deadline) StopOnQueue();
            }
        });
        dispatch_resume(timer);
    });
    errno = saved;
}
void nh_stop(void) {
    int saved = errno; dispatch_sync(Queue(), ^{ StopOnQueue(); }); errno = saved;
}
void nh_sample_now(void) {
    int saved = errno; dispatch_sync(Queue(), ^{ SampleOnQueue(); }); errno = saved;
}
int nh_socket(int domain, int type, int protocol) {
    int fd = socket(domain, type, protocol), saved = errno;
    if (fd >= 0 && atomic_load(&enabled) && (domain == AF_INET || domain == AF_INET6) &&
        type == SOCK_STREAM && (!protocol || protocol == IPPROTO_TCP)) {
        pthread_mutex_lock(&socketLock);
        if (atomic_load(&enabled)) {
            unsigned slot = NHCapacity;
            for (unsigned i = 0; i < NHCapacity; i++) {
                if (sockets[i].fd == fd) { slot = i; break; }
                if (sockets[i].fd < 0 && slot == NHCapacity) slot = i;
            }
            if (slot < NHCapacity) sockets[slot] = (NHSocket){fd, ++nextIdentifier};
            else omitted++;
        }
        pthread_mutex_unlock(&socketLock);
    }
    errno = saved; return fd;
}
int nh_close(int fd) {
    int saved = errno;
    if (atomic_load(&enabled)) {
        pthread_mutex_lock(&socketLock);
        for (unsigned i = 0; i < NHCapacity; i++) if (sockets[i].fd == fd) sockets[i].fd = -1;
        pthread_mutex_unlock(&socketLock);
    }
    errno = saved; return close(fd);
}
