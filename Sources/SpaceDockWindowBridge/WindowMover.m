#import "SpaceDockWindowBridge.h"
#import <AppKit/AppKit.h>
#import <ApplicationServices/ApplicationServices.h>
#include <dlfcn.h>
#import "BridgedOperation.h"
static int (*connection)(void);
static uint64_t (*active)(int);
static int (*spaceType)(int,uint64_t);
static CFArrayRef (*spacesFor)(int,int,CFArrayRef);
static BOOL available(void) {
 static dispatch_once_t once;static BOOL ready;
 dispatch_once(&once,^{
  void *lib=dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight",RTLD_NOW|RTLD_LOCAL);
  if(!lib)return;
  connection=dlsym(lib,"SLSMainConnectionID");active=dlsym(lib,"SLSGetActiveSpace");spaceType=dlsym(lib,"SLSSpaceGetType");spacesFor=dlsym(lib,"SLSCopySpacesForWindows");submitMove=findMoveSymbol();
  ready=connection && active && spaceType && spacesFor && submitMove;
 });return ready;
}
static NSArray *windowSpaces(uint32_t wid){return CFBridgingRelease(spacesFor(connection(),7,(__bridge CFArrayRef)@[@(wid)]));}
static uint32_t primaryWindow(int pid) {
 NSArray *windows=CFBridgingRelease(CGWindowListCopyWindowInfo(kCGWindowListOptionAll,kCGNullWindowID));
 uint32_t selected=0;double largest=0;
 for(NSDictionary *w in windows){
  if([w[(id)kCGWindowOwnerPID] intValue]!=pid || [w[(id)kCGWindowLayer] intValue]!=0)continue;
  CGRect r;if(!CGRectMakeWithDictionaryRepresentation((__bridge CFDictionaryRef)w[(id)kCGWindowBounds],&r))continue;
  double area=r.size.width*r.size.height;if(r.size.width>100 && r.size.height>100 && area>largest){selected=[w[(id)kCGWindowNumber] unsignedIntValue];largest=area;}
 }return selected;
}
@implementation SDWindowMover
+ (BOOL)mainWindowIsVisibleForPID:(int)pid {
 uint32_t wid=primaryWindow(pid);if(!wid)return NO;
 NSArray *windows=CFBridgingRelease(CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly,kCGNullWindowID));
 for(NSDictionary *w in windows) {
  if([w[(id)kCGWindowNumber] unsignedIntValue]==wid && [w[(id)kCGWindowAlpha] doubleValue]>0)return YES;
 }
 return NO;
}
+ (NSNumber*)currentSpace {if(!available())return nil;uint64_t space=active(connection());return space && spaceType(connection(),space)==0?@(space):nil;}
+ (BOOL)mainWindowForPID:(int)pid isOnSpace:(uint64_t)space {
 if(!available())return NO;uint32_t wid=primaryWindow(pid);if(!wid)return NO;
 NSArray *list=windowSpaces(wid);return list.count==1 && [list containsObject:@(space)];
}
+ (void)moveMainWindowForPID:(int)pid toSpace:(uint64_t)space isCurrent:(BOOL (^)(void))isCurrent completion:(void (^)(NSString*))completion {
 [self attempt:pid target:space remaining:30 current:isCurrent completion:completion];
}
+ (void)attempt:(int)pid target:(uint64_t)target remaining:(int)remaining current:(BOOL (^)(void))current completion:(void (^)(NSString*))completion {
 if(!current()){completion(@"请求已取消");return;}
 if(!available() || active(connection())!=target || spaceType(connection(),target)!=0){completion(@"当前桌面已变化或不支持搬移，未唤起应用。");return;}
 uint32_t wid=primaryWindow(pid);
 if(!wid){
  if(remaining<=0){completion(@"暂未找到应用主窗口，请待应用启动完成后重试。");return;}
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW,100*NSEC_PER_MSEC),dispatch_get_main_queue(),^{[self attempt:pid target:target remaining:remaining-1 current:current completion:completion];});return;
 }
 NSArray *source=windowSpaces(wid);
 if(source.count!=1){completion(@"请在 Dock 的应用选项中将“分配给”设为“无”，然后重试。");return;}
 if(spaceType(connection(),[source.firstObject unsignedLongLongValue])!=0){completion(@"暂不支持搬移全屏窗口，请先退出全屏。");return;}
 if([source containsObject:@(target)]){completion(nil);return;}
 Class cls=NSClassFromString(@"SLSBridgedMoveWindowsToManagedSpaceOperation");
 if(![cls instancesRespondToSelector:@selector(initWithWindows:spaceID:)]){completion(@"系统窗口搬移接口不可用。");return;}
 id operation=[[cls alloc]initWithWindows:@[@(wid)] spaceID:target];
 if(!operation){completion(@"无法创建窗口搬移请求。");return;}
 submitMove((__bridge void*)operation);
 [self verify:wid target:target operation:operation remaining:40 current:current completion:completion];
}
+ (void)verify:(uint32_t)wid target:(uint64_t)target operation:(id)operation remaining:(int)remaining current:(BOOL (^)(void))current completion:(void (^)(NSString*))completion {
 if(!current()){completion(@"请求已取消");return;}
 if(active(connection())!=target){completion(@"当前桌面已变化，未激活应用。");return;}
 NSArray *after=windowSpaces(wid);
 if(after.count==1 && [after containsObject:@(target)]){completion(nil);return;}
 if(remaining<=0){completion(@"窗口未能移到当前桌面，未激活应用以避免跳转。");return;}
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,50*NSEC_PER_MSEC),dispatch_get_main_queue(),^{[self verify:wid target:target operation:operation remaining:remaining-1 current:current completion:completion];});
}
@end
