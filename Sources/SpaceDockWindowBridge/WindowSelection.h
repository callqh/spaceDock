#import <ApplicationServices/ApplicationServices.h>
#import <Foundation/Foundation.h>

// Apps may retain large off-desktop helper windows. Only a window with an
// actual Space membership can be moved or used to verify activation.
static uint32_t SDSelectPrimaryWindow(NSArray *windows, int pid, NSArray *(^spaces)(uint32_t)) {
 uint32_t selected=0; double largest=0;
 for(NSDictionary *w in windows) {
  if([w[(id)kCGWindowOwnerPID] intValue]!=pid || [w[(id)kCGWindowLayer] intValue]!=0)continue;
  CGRect r;
  if(!CGRectMakeWithDictionaryRepresentation((__bridge CFDictionaryRef)w[(id)kCGWindowBounds],&r))continue;
  double area=r.size.width*r.size.height;
  if(r.size.width<=100 || r.size.height<=100 || area<=largest)continue;
  uint32_t wid=[w[(id)kCGWindowNumber] unsignedIntValue];
  if(spaces(wid).count==0)continue;
  selected=wid; largest=area;
 }
 return selected;
}
