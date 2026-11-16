// Only original synthetic data: repair must not fetch or change game files.
#import "../launcher/WoW/Updater.h"
#import "../launcher/WoW/UpdateLock.h"
#include <assert.h>

@interface TKMetadataClient : TKWoWClient @end
@implementation TKMetadataClient
- (NSData *)fetch:(NSURL *)url limit:(NSUInteger)limit error:(NSError **)error {
    (void)url; (void)limit; (void)error; assert(!"Metadata repair must not download"); return nil;
}
@end
static NSData *Text(NSString *s) { return [s dataUsingEncoding:NSUTF8StringEncoding]; }
int main(void) { @autoreleasepool {
    NSFileManager *fm=NSFileManager.defaultManager;
    NSString *root=[[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString] stringByResolvingSymlinksInPath];
    assert([fm createDirectoryAtPath:root withIntermediateDirectories:YES attributes:nil error:NULL]);
    NSString *path=[root stringByAppendingPathComponent:@".build.info"];
    NSDictionary *plan=@{@"product":@"wowf",@"version":@{@"BuildConfig":@"11111111111111111111111111111111",
        @"CDNConfig":@"22222222222222222222222222222222",@"VersionsName":@"synthetic-1"},
        @"cdnHosts":@"level3.blizzard.com level3.ssl.blizzard.com",
        @"cdnServers":@"http://level3.blizzard.com/?maxhosts=8 https://level3.ssl.blizzard.com/?fallback=1"};
    NSString *row=@"wowf|1|11111111111111111111111111111111|22222222222222222222222222222222|synthetic-1|custom enUS tags|eu|keep forever\n";
    NSString *header=@"Product|Active|Build Key|CDN Key|Version|Tags|Branch|Custom\n";
    NSData *legacy=Text([[header stringByAppendingString:row] stringByAppendingString:@"wow|0|aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb|other|custom retail tags|us|keep retail\n"]);
    assert([legacy writeToFile:path atomically:YES]);
    NSArray *before=TKWoWTable(legacy,NULL);
    NSArray *protected=@[@"_forever_/Synthetic.app/Original",@"_forever_/WTF/Config.wtf",@"_forever_/Interface/AddOns/Original.lua"];
    for(NSString *relative in protected) {
        NSString *file=[root stringByAppendingPathComponent:relative];
        assert([fm createDirectoryAtPath:file.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:NULL]);
        assert([Text(relative) writeToFile:file atomically:YES]);
    }
    TKMetadataClient *client=[TKMetadataClient new];
    TKWoWUpdater *updater=[[TKWoWUpdater alloc] initWithClient:client];
    NSError *error=nil;
    assert([updater repairBuildInfoForPlan:plan root:root error:&error] && !error);
    NSData *repaired=[NSData dataWithContentsOfFile:path];
    NSArray *after=TKWoWTable(repaired,NULL); assert(after.count==before.count);
    for(NSDictionary *old in before) {
        NSDictionary *new=nil;
        for(NSDictionary *candidate in after)if([candidate[@"Product"] isEqual:old[@"Product"]])new=candidate;
        assert(new);
        for(NSString *key in old)assert([new[key] isEqual:old[key]]);
        if([old[@"Product"] isEqual:@"wowf"]) {
            assert([new[@"CDN Hosts"] isEqual:plan[@"cdnHosts"]]);
            assert([new[@"CDN Servers"] isEqual:plan[@"cdnServers"]]);
        }
    }
    for(NSString *relative in protected)assert([[NSData dataWithContentsOfFile:[root stringByAppendingPathComponent:relative]] isEqual:Text(relative)]);
    assert([updater repairBuildInfoForPlan:plan root:root error:&error]);
    assert([[NSData dataWithContentsOfFile:path] isEqual:repaired]); // idempotent

    int lock=TKWoWAcquireUpdateLock(root,&error); assert(lock>=0);
    assert(![updater repairBuildInfoForPlan:plan root:root error:&error] && error);
    TKWoWReleaseUpdateLock(lock);
    assert([[NSData dataWithContentsOfFile:path] isEqual:repaired]);
    NSMutableDictionary *changed=[plan mutableCopy];
    changed[@"version"]=@{@"BuildConfig":@"33333333333333333333333333333333",@"CDNConfig":@"22222222222222222222222222222222",@"VersionsName":@"synthetic-2"};
    error=nil;
    assert(![updater repairBuildInfoForPlan:changed root:root error:&error] && error);
    assert([[NSData dataWithContentsOfFile:path] isEqual:repaired]);
    changed=[plan mutableCopy]; changed[@"cdnServers"]=@""; error=nil;
    assert(![updater repairBuildInfoForPlan:changed root:root error:&error] && error);
    assert([[NSData dataWithContentsOfFile:path] isEqual:repaired]);

    // Ambiguity and missing metadata must not be turned into a new installation.
    assert([Text([[header stringByAppendingString:row] stringByAppendingString:row]) writeToFile:path atomically:YES]);
    NSData *duplicate=[NSData dataWithContentsOfFile:path]; error=nil;
    assert(![updater repairBuildInfoForPlan:plan root:root error:&error] && error);
    assert([[NSData dataWithContentsOfFile:path] isEqual:duplicate]);
    assert([fm removeItemAtPath:path error:NULL]); error=nil;
    assert(![updater repairBuildInfoForPlan:plan root:root error:&error] && error);
    assert(![fm fileExistsAtPath:path]);
    assert([repaired writeToFile:path atomically:YES]);
    [client cancel]; error=nil;
    assert(![updater repairBuildInfoForPlan:plan root:root error:&error] && error);
    assert([[NSData dataWithContentsOfFile:path] isEqual:repaired]);
    assert([fm removeItemAtPath:root error:NULL]);
    puts("WoW metadata repair PASS: no downloads, only CDN fields, other rows/files preserved, repeat, lock, changed build, missing/ambiguous metadata and cancellation.");
} return 0; }
