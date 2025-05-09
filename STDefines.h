//
//  STDefines.h
//  Sabbatic
//
//  Created by david on 4/25/25.
//

#ifndef STDefines_h
#define STDefines_h

// preferences
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

#ifdef __MAC_OS_X_VERSION_MAX_ALLOWED
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
#define STLunarDayScalarX 2
#define STLunarDayScalarY 3
#define STSpinnerWidth 20
#define STSpinnerHeight 20
#endif

#endif /* STDefines_h */
