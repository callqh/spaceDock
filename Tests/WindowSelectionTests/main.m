#import "../../Sources/SpaceDockWindowBridge/WindowSelection.h"
static NSDictionary *window(int number,int pid,int layer,int width,int height) {
 return @{(id)kCGWindowNumber:@(number),(id)kCGWindowOwnerPID:@(pid),
 (id)kCGWindowLayer:@(layer),(id)kCGWindowBounds:CFBridgingRelease(CGRectCreateDictionaryRepresentation(CGRectMake(0,0,width,height)))};
}
int main(void) { @autoreleasepool {
 NSArray *windows=@[window(205,1,0,500,500),window(204,1,0,1512,948),window(193,1,0,1512,948)];
 NSArray *(^spaces)(uint32_t)=^NSArray *(uint32_t wid){return wid==193?@[@5]:@[];};
 NSCAssert(SDSelectPrimaryWindow(windows,1,spaces)==193,@"Must ignore Lark's same-size unmanaged helper");
 NSCAssert(SDSelectPrimaryWindow([[windows reverseObjectEnumerator] allObjects],1,spaces)==193,@"Ordering must not choose a helper");
 NSCAssert(SDSelectPrimaryWindow(windows,2,spaces)==0,@"Must respect owner PID");
 NSCAssert(SDSelectPrimaryWindow(windows,1,^NSArray *(uint32_t wid){return @[];})==0,@"No managed window must not select a helper");
 NSCAssert(SDSelectPrimaryWindow(@[window(1,1,0,1000,800)],1,^NSArray *(uint32_t wid){return @[@4,@5];})==1,@"Keep all-desktop windows for explicit assignment validation");
 NSCAssert(SDSelectPrimaryWindow(@[window(1,1,1,2000,1500),window(193,1,0,1512,948)],1,^NSArray *(uint32_t wid){return @[@5];})==193,@"Ignore floating layers");
 puts("6 window-selection regression checks passed");
} return 0; }
