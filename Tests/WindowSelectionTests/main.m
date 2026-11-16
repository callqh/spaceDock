#import "../../Sources/SpaceDockWindowBridge/WindowSelection.h"
static NSDictionary *window(int number,int pid,int layer,int width,int height) {
 return @{(id)kCGWindowNumber:@(number),(id)kCGWindowOwnerPID:@(pid),
 (id)kCGWindowLayer:@(layer),(id)kCGWindowBounds:CFBridgingRelease(CGRectCreateDictionaryRepresentation(CGRectMake(0,0,width,height)))};
}
int main(void) { @autoreleasepool {
 NSArray *windows=@[window(205,1,0,500,500),window(204,1,0,1512,948),window(193,1,0,1512,948)];
 NSArray *(^spaces)(uint32_t)=^NSArray *(uint32_t wid){return wid==193?@[@5]:@[];};
 NSCAssert(SDSelectPrimaryWindow(windows,1,@[@193],spaces)==193,@"Must ignore Lark's same-size unmanaged helper");
 NSCAssert(SDSelectPrimaryWindow([[windows reverseObjectEnumerator] allObjects],1,@[@193],spaces)==193,@"Ordering must not choose a helper");
 NSCAssert(SDSelectPrimaryWindow(windows,2,@[@193],spaces)==0,@"Must respect owner PID");
 NSCAssert(SDSelectPrimaryWindow(windows,1,@[@193],^NSArray *(uint32_t wid){return @[];})==0,@"No managed window must not select a helper");
 NSCAssert(SDSelectPrimaryWindow(@[window(1,1,0,1000,800)],1,@[@1],^NSArray *(uint32_t wid){return @[@4,@5];})==1,@"Keep all-desktop windows for explicit assignment validation");
 NSCAssert(SDSelectPrimaryWindow(@[window(1,1,1,2000,1500),window(193,1,0,1512,948)],1,@[@1,@193],^NSArray *(uint32_t wid){return @[@5];})==193,@"Ignore floating layers");
 NSArray *lark=@[window(1223,1,0,2304,1269),window(204,1,0,2304,1269),window(193,1,0,2304,1269)];
 NSCAssert(SDSelectPrimaryWindow(lark,1,@[@193],^NSArray *(uint32_t wid){return @[@5];})==193,@"Regression: a managed drawing window must not beat the real main window");
 NSCAssert(SDSelectPrimaryWindow(lark,1,@[],^NSArray *(uint32_t wid){return @[@5];})==0,@"Missing AX data must not fall back to a drawing window");
 NSCAssert(SDSelectPrimaryWindow(@[window(10,1,0,300,300),window(11,1,0,2000,1500)],1,@[@10,@11],^NSArray *(uint32_t wid){return @[@5];})==10,@"AX main takes priority over a larger standard window");
 puts("9 window-selection regression checks passed");
} return 0; }
