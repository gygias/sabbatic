//
//  STCalendarView.h
//  Sabbatic
//
//  Created by david on 3/20/25.
//

//#ifdef __APPLE__
//#include "TargetConditionals.h"
//#if /*defined(TARGET_OS_IPHONE) ||*/ defined(__IS_NOT_MACOS)// || defined(TARGET_IPHONE_SIMULATOR)
//#ifdef MAC_OS_X_VERSION_MIN_REQUIRED
//#elif TARGET_IPHONE_SIMULATORif defined(TARGET_OS_MAC) && defined(__MAC_OS_X_VERSION_MAX_ALLOWED)
#if !__has_include(<UIKit/UIKit.h>) // this was impressively difficult to narrow down
#import <Cocoa/Cocoa.h>
#define STCalendarViewSuper NSView
#else
#import <UIKit/UIKit.h>
#define STCalendarViewSuper UIView
#endif

NS_ASSUME_NONNULL_BEGIN

@interface STCalendarView : STCalendarViewSuper

@property (strong) NSDate *effectiveNewMoonStart;

@end

NS_ASSUME_NONNULL_END
