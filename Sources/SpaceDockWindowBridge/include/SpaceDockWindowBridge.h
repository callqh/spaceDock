#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
@interface SDWindowMover : NSObject
+ (nullable NSNumber *)currentSpace;
+ (BOOL)mainWindowForPID:(int)pid isOnSpace:(uint64_t)space;
+ (BOOL)mainWindowIsVisibleForPID:(int)pid;
+ (BOOL)hasMainWindowForPID:(int)pid;
+ (BOOL)window:(uint32_t)wid isOnSpace:(uint64_t)space;
+ (BOOL)windowIsVisible:(uint32_t)wid;
+ (nullable NSString *)showWindow:(uint32_t)wid forPID:(int)pid onSpace:(uint64_t)space;
+ (void)moveMainWindowForPID:(int)pid toSpace:(uint64_t)space
                  isCurrent:(BOOL (^)(void))isCurrent
                 completion:(void (^)(NSNumber * _Nullable windowID, NSString * _Nullable error))completion;
@end
NS_ASSUME_NONNULL_END
