#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
@interface SDWindowMover : NSObject
+ (nullable NSNumber *)currentSpace;
+ (BOOL)mainWindowForPID:(int)pid isOnSpace:(uint64_t)space;
+ (BOOL)mainWindowIsVisibleForPID:(int)pid;
+ (void)moveMainWindowForPID:(int)pid toSpace:(uint64_t)space
                  isCurrent:(BOOL (^)(void))isCurrent
                 completion:(void (^)(NSString * _Nullable error))completion;
@end
NS_ASSUME_NONNULL_END
