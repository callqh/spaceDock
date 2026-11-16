// Exercise the real pre-move recovery boundary without moving or activating apps.
#import "../../Sources/SpaceDockWindowBridge/WindowMover.m"
#include <limits.h>
int main(void) { @autoreleasepool {
 BOOL ordinaryOpen=NO;
 NSString *failure=[SDWindowMover runSummon:INT_MAX space:0 current:^BOOL{return YES;} missingWindow:&ordinaryOpen];
 NSCAssert(failure!=nil,@"A vanished process must not be reported as a confirmed window");
 NSCAssert(ordinaryOpen==AXIsProcessTrusted(),@"Missing process may reopen only while permission and request remain valid");
 ordinaryOpen=NO;
 failure=[SDWindowMover runSummon:INT_MAX space:0 current:^BOOL{return NO;} missingWindow:&ordinaryOpen];
 NSCAssert(failure!=nil && !ordinaryOpen,@"Cancellation must never reopen an application");
 puts("2 window-recovery boundary checks passed");
 } return 0;
}
