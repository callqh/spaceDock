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
static NSArray *standardWindows(int pid) {
 AXUIElementRef app=AXUIElementCreateApplication(pid);
 AXUIElementSetMessagingTimeout(app,0.25);
 NSMutableArray *ordered=[NSMutableArray array];
 id main=axValue(app,kAXMainWindowAttribute), focused=axValue(app,kAXFocusedWindowAttribute);
 if(main)[ordered addObject:main];
 if(focused)[ordered addObject:focused];
 id windows=axValue(app,kAXWindowsAttribute);
 if([windows isKindOfClass:NSArray.class])[ordered addObjectsFromArray:windows];
 CFRelease(app);
 NSMutableArray *result=[NSMutableArray array];
 for(id element in ordered) {
  if(CFGetTypeID((__bridge CFTypeRef)element)!=AXUIElementGetTypeID())continue;
  AXUIElementRef ax=(__bridge AXUIElementRef)element;
  AXUIElementSetMessagingTimeout(ax,0.25);
  if([axValue(ax,kAXSubroleAttribute) isEqual:(__bridge NSString *)kAXStandardWindowSubrole] &&
     ![result containsObject:element])[result addObject:element];
 }
 return result;
}
static uint32_t primaryWindow(int pid) {
 if(!available())return 0;
 NSMutableArray *ids=[NSMutableArray array];
 for(id element in standardWindows(pid)) {uint32_t wid=axWindowID(element);if(wid)[ids addObject:@(wid)];}
 NSArray *windows=CFBridgingRelease(CGWindowListCopyWindowInfo(kCGWindowListOptionAll,kCGNullWindowID));
 return SDSelectPrimaryWindow(windows,pid,ids,^NSArray *(uint32_t wid){return windowSpaces(wid);});
}
@implementation SDWindowMover
+ (BOOL)mainWindowIsVisibleForPID:(int)pid {
 return [self windowIsVisible:primaryWindow(pid)];
}
+ (BOOL)hasMainWindowForPID:(int)pid {return primaryWindow(pid)!=0;}
+ (BOOL)windowIsVisible:(uint32_t)wid {
 if(!wid)return NO;
 NSArray *windows=CFBridgingRelease(CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly,kCGNullWindowID));
 for(NSDictionary *w in windows) {
  if([w[(id)kCGWindowNumber] unsignedIntValue]==wid && [w[(id)kCGWindowAlpha] doubleValue]>0)return YES;
 }
 return NO;
}
+ (NSNumber*)currentSpace {if(!available())return nil;uint64_t space=active(connection());return space && spaceType(connection(),space)==0?@(space):nil;}
+ (BOOL)mainWindowForPID:(int)pid isOnSpace:(uint64_t)space {
 if(!available())return NO;uint32_t wid=primaryWindow(pid);if(!wid)return NO;
 return [self window:wid isOnSpace:space];
}
+ (BOOL)window:(uint32_t)wid isOnSpace:(uint64_t)space {
 if(!wid || !available())return NO;
 NSArray *list=windowSpaces(wid);return list.count==1 && [list containsObject:@(space)];
}
// Never send an application reopen event for a window already selected and moved.
+ (NSString *)showWindow:(uint32_t)wid forPID:(int)pid onSpace:(uint64_t)space {
 if(!available() || active(connection())!=space || ![self window:wid isOnSpace:space])
  return @"目标窗口或桌面已变化，未激活应用。";
 id selected=nil;
 for(id element in standardWindows(pid))if(axWindowID(element)==wid){selected=element;break;}
 if(!selected)return @"目标窗口已关闭或不可访问，请重试。";
 AXUIElementRef ax=(__bridge AXUIElementRef)selected;
 id minimized=axValue(ax,kAXMinimizedAttribute);
 if([minimized boolValue] && AXUIElementSetAttributeValue(ax,kAXMinimizedAttribute,kCFBooleanFalse)!=kAXErrorSuccess)
  return @"无法恢复最小化窗口。";
 // Select the exact main window before process activation can consult its old main window.
 if(AXUIElementSetAttributeValue(ax,kAXMainAttribute,kCFBooleanTrue)!=kAXErrorSuccess)
  return @"无法将目标窗口设为主窗口，未激活应用。";
 if(active(connection())!=space || ![self window:wid isOnSpace:space])
  return @"恢复窗口时桌面发生变化，请重试。";
 NSRunningApplication *app=[NSRunningApplication runningApplicationWithProcessIdentifier:pid];
 [app unhide];
 // An application-level activation may select another managed drawing window
 // and switch Spaces even after its AX main window has moved. Target the exact
 // verified window, as AltTab's window-focus implementation does.
 typedef OSStatus (*FocusWindow)(ProcessSerialNumber*,uint32_t,uint32_t);
 static FocusWindow focus; static dispatch_once_t once;
 dispatch_once(&once,^{focus=dlsym(RTLD_DEFAULT,"_SLPSSetFrontProcessWithOptions");});
 ProcessSerialNumber psn;
 if(!focus || GetProcessForPID(pid,&psn)!=noErr)
  return @"系统窗口级激活接口不可用，未执行应用级切换。";
 if(active(connection())!=space || ![self window:wid isOnSpace:space])
  return @"目标桌面发生变化，未激活窗口。";
 if(focus(&psn,wid,0x200)!=noErr)
  return @"无法激活目标窗口，请重试。";
 AXUIElementPerformAction(ax,kAXRaiseAction);
 AXUIElementSetAttributeValue(ax,kAXFocusedAttribute,kCFBooleanTrue);
 return nil;
}
+ (void)moveMainWindowForPID:(int)pid toSpace:(uint64_t)space isCurrent:(BOOL (^)(void))isCurrent completion:(void (^)(NSNumber*,NSString*))completion {
 [self attempt:pid target:space remaining:30 current:isCurrent completion:completion];
}
+ (void)attempt:(int)pid target:(uint64_t)target remaining:(int)remaining current:(BOOL (^)(void))current completion:(void (^)(NSNumber*,NSString*))completion {
 if(!current()){completion(nil,@"请求已取消");return;}
 if(!available() || active(connection())!=target || spaceType(connection(),target)!=0){completion(nil,@"当前桌面已变化或不支持搬移，未唤起应用。");return;}
 uint32_t wid=primaryWindow(pid);
 if(!wid){
  if(remaining<=0){completion(nil,@"暂未找到应用主窗口，请待应用启动完成后重试。");return;}
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW,100*NSEC_PER_MSEC),dispatch_get_main_queue(),^{[self attempt:pid target:target remaining:remaining-1 current:current completion:completion];});return;
 }
 NSArray *source=windowSpaces(wid);
 if(source.count==0){completion(nil,@"应用窗口的桌面归属暂不可用，请重试。");return;}
 if(source.count!=1){completion(nil,@"请在 Dock 的应用选项中将“分配给”设为“无”，然后重试。");return;}
 if(spaceType(connection(),[source.firstObject unsignedLongLongValue])!=0){completion(nil,@"暂不支持搬移全屏窗口，请先退出全屏。");return;}
 if([source containsObject:@(target)]){completion(@(wid),nil);return;}
 Class cls=NSClassFromString(@"SLSBridgedMoveWindowsToManagedSpaceOperation");
 if(![cls instancesRespondToSelector:@selector(initWithWindows:spaceID:)]){completion(nil,@"系统窗口搬移接口不可用。");return;}
 id operation=[[cls alloc]initWithWindows:@[@(wid)] spaceID:target];
 if(!operation){completion(nil,@"无法创建窗口搬移请求。");return;}
 submitMove((__bridge void*)operation);
 [self verify:wid target:target operation:operation remaining:40 current:current completion:completion];
}
+ (void)verify:(uint32_t)wid target:(uint64_t)target operation:(id)operation remaining:(int)remaining current:(BOOL (^)(void))current completion:(void (^)(NSNumber*,NSString*))completion {
 if(!current()){completion(nil,@"请求已取消");return;}
 if(active(connection())!=target){completion(nil,@"当前桌面已变化，未激活应用。");return;}
 NSArray *after=windowSpaces(wid);
 if(after.count==1 && [after containsObject:@(target)]){completion(@(wid),nil);return;}
 if(remaining<=0){completion(nil,@"窗口未能移到当前桌面，未激活应用以避免跳转。");return;}
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,50*NSEC_PER_MSEC),dispatch_get_main_queue(),^{[self verify:wid target:target operation:operation remaining:remaining-1 current:current completion:completion];});
}
@end
