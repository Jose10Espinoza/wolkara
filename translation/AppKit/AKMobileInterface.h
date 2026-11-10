#import <Foundation/Foundation.h>

// Companion addon commands are bound to CTRL-ALT-SHIFT-F5…F12.
// They originate only in explicit control actions or their individual touch gestures.
typedef NS_ENUM(NSUInteger, AKMobileCommand) {
    AKMobileEnable, AKMobileDisable, AKMobileEdit, AKMobileDone,
    AKMobileTap, AKMobileHold, AKMobileClear, AKMobileDrag
};
static NSString * const AKMobileEnabledKey = @"WolkaraMobileEnabled";
static NSString * const AKMobileAvailableKey = @"WolkaraMobileAvailable";
static inline BOOL AKMobileInterfaceEnabled(void) {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    return [defaults boolForKey:AKMobileAvailableKey] && [defaults boolForKey:AKMobileEnabledKey];
}
@protocol AKMobileInterfaceHost <NSObject>
- (void)ak_mobileCommand:(AKMobileCommand)command;
@end
