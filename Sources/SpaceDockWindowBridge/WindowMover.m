#import "SpaceDockWindowBridge.h"
#import <AppKit/AppKit.h>
#import <Carbon/Carbon.h>
#import <ApplicationServices/ApplicationServices.h>
#include <dlfcn.h>
#import "BridgedOperation.h"
#import "WindowSelection.h"
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
static id axValue(AXUIElementRef element,CFStringRef key) {
 CFTypeRef value=NULL;
 return AXUIElementCopyAttributeValue(element,key,&value)==kAXErrorSuccess ? CFBridgingRelease(value) : nil;
}
static uint32_t axWindowID(id element) {
 if(!element || CFGetTypeID((__bridge CFTypeRef)element)!=AXUIElementGetTypeID())return 0;
 typedef AXError (*GetWindow)(AXUIElementRef,CGWindowID *);
 static GetWindow getWindow; static dispatch_once_t once;
 dispatch_once(&once,^{getWindow=dlsym(RTLD_DEFAULT,"_AXUIElementGetWindow");});
 uint32_t wid=0;
 if(getWindow)getWindow((__bridge AXUIElementRef)element,&wid);
 return wid;
}

// Request-local identity: never reuse an AX reference or window ID in a later request.
@interface SDWindowTarget : NSObject
@property(nonatomic) int pid;
@property(nonatomic) uint32_t wid;
@property(nonatomic,strong) NSRunningApplication *application;
@property(nonatomic,strong) id element;
@end
@implementation SDWindowTarget
@end

static NSArray *drawingWindows(void) {
 return CFBridgingRelease(CGWindowListCopyWindowInfo(kCGWindowListOptionAll,kCGNullWindowID));
}
static BOOL validTarget(SDWindowTarget *target) {
 if(target.application.terminated || target.application.processIdentifier!=target.pid ||
    axWindowID(target.element)!=target.wid)return NO;
 AXUIElementRef ax=(__bridge AXUIElementRef)target.element;
 if(![axValue(ax,kAXSubroleAttribute) isEqual:(__bridge NSString *)kAXStandardWindowSubrole])return NO;
 return SDSelectPrimaryWindow(drawingWindows(),target.pid,@[@(target.wid)],^NSArray *(uint32_t wid){return windowSpaces(wid);})==target.wid;
}
static BOOL onSpace(uint32_t wid,uint64_t space) {
 NSArray *spaces=windowSpaces(wid);
 return spaces.count==1 && [spaces containsObject:@(space)];
}
static BOOL visible(uint32_t wid) {
 for(NSDictionary *w in drawingWindows())
  if([w[(id)kCGWindowNumber] unsignedIntValue]==wid)
   return [w[(id)kCGWindowIsOnscreen] boolValue] && [w[(id)kCGWindowAlpha] doubleValue]>0;
 return NO;
}
static BOOL focused(SDWindowTarget *target) {
 AXUIElementRef app=AXUIElementCreateApplication(target.pid);
 AXUIElementSetMessagingTimeout(app,0.2);
 uint32_t wid=axWindowID(axValue(app,kAXFocusedWindowAttribute));
 CFRelease(app);
 return wid==target.wid && NSWorkspace.sharedWorkspace.frontmostApplication.processIdentifier==target.pid;
}
static SDWindowTarget *resolveTarget(int pid,NSString **failure,BOOL (^current)(void)) {
 NSRunningApplication *running=[NSRunningApplication runningApplicationWithProcessIdentifier:pid];
 if(!running || running.terminated){*failure=@"应用已退出，请先正常打开主窗口。";return nil;}
 AXUIElementRef app=AXUIElementCreateApplication(pid);
 AXUIElementSetMessagingTimeout(app,0.2);
 NSMutableArray *ordered=[NSMutableArray array];
 NSMutableArray *preferred=[NSMutableArray array];
 NSTimeInterval deadline=NSProcessInfo.processInfo.systemUptime+1.5;
 AXError readError=kAXErrorSuccess;
 for(NSString *key in @[(__bridge NSString *)kAXMainWindowAttribute,(__bridge NSString *)kAXFocusedWindowAttribute,(__bridge NSString *)kAXWindowsAttribute]) {
  if(!current()){CFRelease(app);*failure=@"请求已取消。";return nil;}
  CFTypeRef raw=NULL;
  AXError result=AXUIElementCopyAttributeValue(app,(__bridge CFStringRef)key,&raw);
  id value=CFBridgingRelease(raw);
  if(result!=kAXErrorSuccess){readError=result;continue;}
  if([value isKindOfClass:NSArray.class])[ordered addObjectsFromArray:value];
  else if(value){[ordered addObject:value];uint32_t wid=axWindowID(value);if(wid)[preferred addObject:@(wid)];}
 }
 CFRelease(app);
 NSMutableArray *candidates=[NSMutableArray array];
 NSMutableDictionary *elements=[NSMutableDictionary dictionary];
 for(id element in ordered) {
  if(!current() || NSProcessInfo.processInfo.systemUptime>deadline){*failure=@"窗口查询已取消或超时，请稍后重试。";return nil;}
  if(CFGetTypeID((__bridge CFTypeRef)element)!=AXUIElementGetTypeID())continue;
  AXUIElementRef ax=(__bridge AXUIElementRef)element;
  AXUIElementSetMessagingTimeout(ax,0.2);
  if(![axValue(ax,kAXSubroleAttribute) isEqual:(__bridge NSString *)kAXStandardWindowSubrole])continue;
  uint32_t wid=axWindowID(element);
  if(wid && !elements[@(wid)]){[candidates addObject:@(wid)];elements[@(wid)]=element;}
 }
 uint32_t wid=SDSelectPrimaryWindow(drawingWindows(),pid,SDUnambiguousCandidates(candidates,preferred),^NSArray *(uint32_t wid){return windowSpaces(wid);});
 if(!wid) {
  if(!AXIsProcessTrusted() || readError==kAXErrorAPIDisabled)*failure=@"辅助功能权限不可用，请在设置中检查授权。";
  else if(readError==kAXErrorCannotComplete)*failure=@"应用暂未响应窗口查询，请稍后重试。";
  else *failure=@"未找到可可靠操作的主窗口。请正常打开主窗口后重试；不会自动切换桌面。";
  return nil;
 }
 SDWindowTarget *target=[SDWindowTarget new];target.pid=pid;target.wid=wid;target.element=elements[@(wid)];target.application=running;
 return target;
}

static dispatch_queue_t windowQueue(void) {
 static dispatch_queue_t worker;static dispatch_once_t once;
 dispatch_once(&once,^{worker=dispatch_queue_create("local.spacedock.window-request",DISPATCH_QUEUE_SERIAL);});
 return worker;
}

@implementation SDWindowMover
+ (void)checkFocusedWindowForPID:(int)pid completion:(void (^)(BOOL))completion {
 dispatch_async(windowQueue(),^{@autoreleasepool {
  NSString *failure=nil;
  SDWindowTarget *target=available()?resolveTarget(pid,&failure,^BOOL{return YES;}):nil;
  BOOL result=target && validTarget(target) && visible(target.wid) && focused(target) && !target.application.hidden;
  dispatch_async(dispatch_get_main_queue(),^{completion(result);});
 }});
}
+ (NSNumber*)currentSpace {
 if(!available())return nil;
 uint64_t space=active(connection());return space && spaceType(connection(),space)==0?@(space):nil;
}
+ (void)summonWindowForPID:(int)pid onSpace:(uint64_t)space isCurrent:(BOOL (^)(void))isCurrent completion:(void (^)(SDWindowSummonResult,NSString *))completion {
 dispatch_async(windowQueue(),^{@autoreleasepool {
  // The model belongs to the main queue. Never call it directly from AX work.
  BOOL (^current)(void)=^BOOL{
   __block BOOL value=NO;dispatch_sync(dispatch_get_main_queue(),^{value=isCurrent();});
   return value && available() && active(connection())==space;
  };
  BOOL missingWindow=NO;
  NSString *failure=[self runSummon:pid space:space current:current missingWindow:&missingWindow];
  SDWindowSummonResult result=missingWindow?SDWindowSummonResultWindowUnavailable:(failure?SDWindowSummonResultFailed:SDWindowSummonResultConfirmed);
  dispatch_async(dispatch_get_main_queue(),^{if(isCurrent())completion(result,failure);});
 }});
}
+ (NSString *)runSummon:(int)pid space:(uint64_t)space current:(BOOL (^)(void))current missingWindow:(BOOL *)missingWindow {
 if(!current())return @"请求已取消。";
 NSString *failure=nil;
 SDWindowTarget *target=resolveTarget(pid,&failure,current);
 if(!target) {
  // Only pre-move discovery can request ordinary opening. Cancellation,
  // permission loss and failures after a move must not trigger this fallback.
  *missingWindow=current() && AXIsProcessTrusted();
  return failure;
 }
 if(!current())return @"请求已取消。";
 NSArray *source=windowSpaces(target.wid);
 if(source.count!=1)return @"请在 Dock 的应用选项中将“分配给”设为“无”。";
 if(spaceType(connection(),[source.firstObject unsignedLongLongValue])!=0)
  return @"暂不支持搬移全屏窗口，请先退出全屏。";
 AXUIElementRef ax=(__bridge AXUIElementRef)target.element;
 if(!validTarget(target))return @"窗口已变化，未执行唤起，请重试。";
 // Toggle only the exact focused, visible window already on the target desktop.
 if(onSpace(target.wid,space) && focused(target) && visible(target.wid) && !target.application.hidden) {
  if(!current())return @"请求已取消。";
  [target.application hide];
  return [self waitFor:^{return target.application.hidden;} current:current] ? nil : @"尚未确认应用已隐藏。";
 }
 // Move while still hidden/minimized, then restore the same window on the target.
 if(!onSpace(target.wid,space)) {
  Class cls=NSClassFromString(@"SLSBridgedMoveWindowsToManagedSpaceOperation");
  if(![cls instancesRespondToSelector:@selector(initWithWindows:spaceID:)])return @"系统窗口搬移接口不可用。";
  if(!validTarget(target) || !current())return @"目标窗口或桌面已变化。";
  id operation=[[cls alloc]initWithWindows:@[@(target.wid)] spaceID:space];
  if(!operation)return @"无法创建窗口搬移请求。";
  submitMove((__bridge void*)operation);
  BOOL moved=[self waitFor:^{return onSpace(target.wid,space);} current:current];
  // Keep the asynchronous operation alive through its readback.
  (void)[operation class];
  if(!moved)return @"窗口未能移到当前桌面，未激活应用。";
 }
 if(!validTarget(target) || !onSpace(target.wid,space) || !current())return @"目标窗口或桌面已变化。";
 id minimized=axValue(ax,kAXMinimizedAttribute);
 if(![minimized isKindOfClass:NSNumber.class])return @"暂时无法确认窗口状态，未激活应用。";
 if([minimized boolValue]) {
  if(!current())return @"请求已取消。";
  if(AXUIElementSetAttributeValue(ax,kAXMinimizedAttribute,kCFBooleanFalse)!=kAXErrorSuccess)return @"无法恢复最小化窗口。";
 }
 if(!validTarget(target) || !onSpace(target.wid,space) || !current())return @"恢复时窗口或桌面发生变化。";
 if(AXUIElementSetAttributeValue(ax,kAXMainAttribute,kCFBooleanTrue)!=kAXErrorSuccess)
  return @"无法选定主窗口，未执行应用级切换。";
 if(!current())return @"请求已取消。";
 [target.application unhide];
 typedef OSStatus (*FocusWindow)(ProcessSerialNumber*,uint32_t,uint32_t);
 static FocusWindow focus;static dispatch_once_t once;
 dispatch_once(&once,^{focus=dlsym(RTLD_DEFAULT,"_SLPSSetFrontProcessWithOptions");});
 ProcessSerialNumber psn;
 if(!focus || GetProcessForPID(pid,&psn)!=noErr)return @"系统窗口级激活接口不可用。";
 if(!validTarget(target) || !onSpace(target.wid,space) || !current())return @"目标窗口或桌面已变化，未激活窗口。";
 if(focus(&psn,target.wid,0x200)!=noErr)return @"无法激活目标窗口。";
 if(!current())return @"请求已取消。";
 AXError raised=AXUIElementPerformAction(ax,kAXRaiseAction);
 if(raised!=kAXErrorSuccess)return @"无法显示目标窗口，请重试。";
 // Focus is advisory; the readback below, not this return code, decides success.
 if(!current())return @"请求已取消。";
 AXUIElementSetAttributeValue(ax,kAXFocusedAttribute,kCFBooleanTrue);
 BOOL confirmed=[self waitFor:^BOOL{
  id minimizedNow=axValue(ax,kAXMinimizedAttribute);
  return validTarget(target) && onSpace(target.wid,space) && !target.application.hidden &&
   [minimizedNow isKindOfClass:NSNumber.class] && ![minimizedNow boolValue] && visible(target.wid) && focused(target);
 } current:current];
 return confirmed?nil:@"尚未确认目标窗口已显示并获得焦点；未执行普通打开回退。";
}
// Bounded readback only: never repeats move, reopen, activation or Raise.
+ (BOOL)waitFor:(BOOL (^)(void))condition current:(BOOL (^)(void))current {
 NSTimeInterval deadline=NSProcessInfo.processInfo.systemUptime+1.5;
 NSTimeInterval stableSince=0;
 do {
  if(!current())return NO;
  if(condition()) {
   NSTimeInterval now=NSProcessInfo.processInfo.systemUptime;
   if(!stableSince)stableSince=now;
   if(now-stableSince>=0.15)return current();
  } else stableSince=0;
  [NSThread sleepForTimeInterval:0.05];
 }while(NSProcessInfo.processInfo.systemUptime<deadline);
 return NO;
}
@end
