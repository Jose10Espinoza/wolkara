#import <Foundation/Foundation.h>
#include "NetworkHealth.h"
#include <assert.h>
#include <errno.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <unistd.h>

static NSString *Log(FILE *file) {
    fflush(file); long length = ftell(file); rewind(file);
    NSMutableData *data = [NSMutableData dataWithLength:(NSUInteger)length];
    assert(fread(data.mutableBytes, 1, data.length, file) == data.length);
    assert(!fseek(file, 0, SEEK_END));
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}
int main(void) {
    @autoreleasepool {
        alarm(10);
        FILE *log = tmpfile(); assert(log);
        errno = ERANGE; nh_start(log, 10); assert(errno == ERANGE);
        int listener = socket(AF_INET, SOCK_STREAM, 0); assert(listener >= 0);
        struct sockaddr_in address = {.sin_len=sizeof address, .sin_family=AF_INET,
            .sin_addr.s_addr=htonl(INADDR_LOOPBACK)};
        assert(!bind(listener, (struct sockaddr *)&address, sizeof address));
        assert(!listen(listener, 1));
        socklen_t size = sizeof address;
        assert(!getsockname(listener, (struct sockaddr *)&address, &size));
        int client = nh_socket(AF_INET, SOCK_STREAM, 0); assert(client >= 0);
        assert(!connect(client, (struct sockaddr *)&address, sizeof address));
        int server = accept(listener, NULL, NULL); assert(server >= 0);
        const char message[] = "synthetic-private-payload";
        assert(send(client, message, sizeof message, 0) == sizeof message);
        char bytes[sizeof message];
        assert(recv(server, bytes, sizeof bytes, MSG_WAITALL) == sizeof bytes);
        assert(!memcmp(bytes, message, sizeof bytes));
        assert(send(server, message, sizeof message, 0) == sizeof message);
        usleep(20000);
        errno = EDOM; nh_sample_now(); assert(errno == EDOM);
        NSString *shown = Log(log);
        assert([shown containsString:@"tracked=1"] && [shown containsString:@"rtt_ms="]);
        assert(([shown containsString:[NSString stringWithFormat:@"rx_pending=%zu", sizeof message]]));
        assert(![shown containsString:@"unavailable_errno="]);
        assert(![shown containsString:@"synthetic-private-payload"] && ![shown containsString:@"127.0.0.1"]);
        // Sampling did not consume data or change the stream's behavior.
        assert(recv(client, bytes, sizeof bytes, MSG_WAITALL) == sizeof bytes);
        assert(!memcmp(bytes, message, sizeof bytes));
        nh_sample_now(); assert([Log(log) containsString:@"rx_pending=0"]);
        assert(!nh_close(client)); assert(!close(server)); assert(!close(listener));
        // Descriptor reuse starts a new anonymous connection identity.
        client = nh_socket(AF_INET, SOCK_STREAM, 0); assert(client >= 0);
        nh_sample_now(); assert([Log(log) containsString:@"id=2"]); assert(!nh_close(client));
        int udp = nh_socket(AF_INET, SOCK_DGRAM, 0); assert(udp >= 0);
        nh_sample_now(); assert([Log(log) containsString:@"tracked=0"]); assert(!nh_close(udp));
        errno = 0; assert(nh_close(-1) == -1 && errno == EBADF);
        assert(nh_socket(-1, SOCK_STREAM, 0) == -1);
        errno = EDOM; nh_stop(); assert(errno == EDOM);
        long stopped = ftell(log); nh_sample_now(); assert(ftell(log) == stopped);
        // Disabled wrappers are plain native operations, with no new records.
        client = nh_socket(AF_INET, SOCK_STREAM, 0); assert(client >= 0); assert(!nh_close(client));
        nh_sample_now(); assert(ftell(log) == stopped);
        // The sampler expires independently of the main run loop.
        nh_start(log, 1); usleep(2500000); nh_sample_now();
        assert([Log(log) hasSuffix:@"[net-health] stopped\n"]);
        nh_stop(); fclose(log); alarm(0);
        puts("NETWORK_HEALTH_PASS: TCP counters, unread queue, unchanged payload/errno, reuse, UDP exclusion, stop and bounded timer.");
    }
}
