#import <Metal/Metal.h>
#include <stdbool.h>

void AKInstallMetalBackgroundLifecycle(void);
void AKInstallMetalBackgroundSubmission(id<MTLDevice> device);
void AKWaitForMetalForeground(void);
// Lock-free: the main thread may be waiting for a worker parked at commit.
// Exported for the runtime's optional adapter lookup.
__attribute__((visibility("default"))) bool AKMetalMainThreadWaitPending(void);
