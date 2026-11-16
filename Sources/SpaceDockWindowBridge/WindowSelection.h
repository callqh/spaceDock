#import <ApplicationServices/ApplicationServices.h>
#import <Foundation/Foundation.h>

// The ordered candidates must come from AX standard windows (main first).
// CG geometry or Space membership alone cannot identify an interactive window.
static uint32_t SDSelectPrimaryWindow(NSArray *windows, int pid, NSArray<NSNumber *> *candidates, NSArray *(^spaces)(uint32_t)) {
 for(NSNumber *candidate in candidates) {
  for(NSDictionary *w in windows) {
   if([w[(id)kCGWindowOwnerPID] intValue]!=pid ||
      [w[(id)kCGWindowLayer] intValue]!=0 ||
      ![w[(id)kCGWindowNumber] isEqual:candidate])continue;
   if(spaces(candidate.unsignedIntValue).count>0)return candidate.unsignedIntValue;
  }
 }
 return 0;
}
