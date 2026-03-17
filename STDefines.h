//
//  STDefines.h
//  Sabbatic
//
//  Created by david on 4/25/25.
//

#ifndef STDefines_h
#define STDefines_h

// preferences
#define LocationPreferenceGathered @"LocationPreferenceGathered"
#define UseManualLocation @"UseManualLocation"
#define ManualLatitude @"ManualLatitude"
#define ManualLongitude @"ManualLongitude"
#define LastLSLatitude @"LastLSLatitude"
#define LastLSLongitude @"LastLSLongitude"
#define LastLocationServicesRequested @"LastLocationServicesRequested"
#define LastLocationServicesStatus @"LastLocationServicesStatus"
#define LastGeneralNoteDate @"LastGeneralNoteDate"
#define LastUrgentNoteDate @"LastUrgentNoteDate"
//
#define LastNotificationRequestDate @"LastNotificationRequestDate"
#define LastNotificationRequestResult @"LastNotificationRequestResult"
#define LastNotificationRequestResultDomain @"LastNotificationRequestResultDomain"
#define LastNotificationRequestResultCode @"LastNotificationRequestResultCode"
//
#define USNODataKey @"USNOData"
#define USNOLunarPhasesKey @"LunarPhaseYear"
#define USNOSolarEventsKey @"SolarEventYear"
#define USNOOneDayKey @"OneDay"

#define STMileRadius 50.
#define STMilePerLatitude 69.
#define STMeterPerMile 1609.344

#define STDataProviderClass STAstronomyProvider

#define STSecondsPerGregorianDay 86400
#define STSecondsPerLunarMonth ( 29.53 * STSecondsPerGregorianDay )
#define STMinutesPerGregorianDay 1440
#define STNotificationRequestDelay 5.0
#define STSabbathNotificationDelay 5.0
#define STMomentAfterInterval 0.000001
#define STMoonRedrawInterval ( 10 * 60 )
#define STCalendarAnimationDuration .25
#define STPeriodicRedrawSeconds 1

//#ifdef __MAC_OS_X_VERSION_MAX_ALLOWED doesn't seem to work anymore on tahoe
#if !__has_include(<UIKit/UIKit.h>)
#define STViewControllerClass NSViewController
#define STRect NSRect
#define STContext [NSGraphicsContext currentContext].CGContext
#define STColorClass NSColor
#define STFontClass NSFont
#define STLocalGregorianFontSize 6
#define STSmallLocalGregorianFontSize 5
#define STFontSizeScalar 100
#define STSmallTextStackOffsetY 1
#define STSmallTextOffsetY 0
#define STCalendarLineWidth (2.)
#define STCalendarViewInsetX 10
#define STCalendarViewInsetY 10
#define STVerseViewInsetX 5
#define STLunarDayOffsetX (-2)
#define STLunarDayScalarX 4
#define STLunarDayScalarY 6
#else
#define STViewControllerClass UIViewController
#define STRect CGRect
#define STContext UIGraphicsGetCurrentContext()
#define STColorClass UIColor
#define STFontClass UIFont
#define STLocalGregorianFontSize 6
#define STSmallLocalGregorianFontSize 6
#define STFontSizeScalar 320
#define STSmallTextOffsetY 3
#define STCalendarLineWidth (2.)
#define STCalendarViewInsetX 0
#define STCalendarViewInsetY 150
#define STVerseViewInsetX 25
#define STLunarDayScalarX 2
#define STLunarDayScalarY 3
#define STSpinnerWidth 20
#define STSpinnerHeight 20
#endif

//#ifdef __APPLE__
//#include "TargetConditionals.h"
//#if /*defined(TARGET_OS_IPHONE) ||*/ defined(__IS_NOT_MACOS)// || defined(TARGET_IPHONE_SIMULATOR)
//#ifdef MAC_OS_X_VERSION_MIN_REQUIRED // stopped working on tahoe (?)
//#elif TARGET_IPHONE_SIMULATORif defined(TARGET_OS_MAC) && defined(__MAC_OS_X_VERSION_MAX_ALLOWED)
#if !__has_include(<UIKit/UIKit.h>) // this was impressively difficult to narrow down
#import <Cocoa/Cocoa.h>
#define STViewSuper NSView
#define STMacOS
#else
#import <UIKit/UIKit.h>
#define STViewSuper UIView
#undef STMacOS
#endif

#endif /* STDefines_h */
