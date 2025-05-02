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
#define USNOLunarPhasesFormat @"com.combobulated.Sabbatic.usno.%ld"
#define USNOSolarEventsFormat @"com.combobulated.Sabbatic.usno.solar.%ld"
#define USNOOnedayFormat @"com.combobulated.Sabbatic.usno.oneday.%@"

#define STSecondsPerGregorianDay 86400
#define STMinutesPerGregorianDay 1440
#define STNotificationRequestDelay 5.0
#define STSabbathNotificationDelay 5.0

#ifdef __MAC_OS_X_VERSION_MAX_ALLOWED
#define STRect NSRect
#define STContext [NSGraphicsContext currentContext].CGContext
#define STColorClass NSColor
#define STFontClass NSFont
#define STLocalGregorianFontSize 6
#define STSmallLocalGregorianFontSize 5
#define STFontSizeScalar 100
#define STSmallTextOffsetY 3
#define STCalendarViewMacosInset 25
#define STLunarDayOffsetX (-2)
#define STLunarDayScalarX 4
#define STLunarDayScalarY 6
#else
#define STRect CGRect
#define STContext UIGraphicsGetCurrentContext()
#define STColorClass UIColor
#define STFontClass UIFont
#define STLocalGregorianFontSize 6
#define STSmallLocalGregorianFontSize 6
#define STFontSizeScalar 320
#define STSmallTextOffsetY 3
#define STCalendarViewInsetX 0
#define STCalendarViewInsetY 175
#define STLunarDayScalarX 2
#define STLunarDayScalarY 3
#endif

#endif /* STDefines_h */
