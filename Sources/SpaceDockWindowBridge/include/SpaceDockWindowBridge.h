#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSInteger, SDWindowSummonResult) {
    SDWindowSummonResultConfirmed,
    SDWindowSummonResultWindowUnavailable,
    SDWindowSummonResultFailed
};
@interface SDWindowMover : NSObject
+ (nullable NSNumber *)currentSpace;
+ (void)checkFocusedWindowForPID:(int)pid completion:(void (^)(BOOL visible))completion;
// Callbacks run on the main queue; foreign AX queries run on a serial worker.
// Existing standard windows only. No reopen, persistent cache or app-level activation.
+ (void)summonWindowForPID:(int)pid onSpace:(uint64_t)space
                isCurrent:(BOOL (^)(void))isCurrent
               completion:(void (^)(SDWindowSummonResult result, NSString * _Nullable error))completion;
@end
NS_ASSUME_NONNULL_END
