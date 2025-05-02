//
//  STDefines.h
//  Sabbatic
//
//  Created by david on 4/25/25.
//

#ifndef STDefines_h
#define STDefines_h

#ifdef __MAC_OS_X_VERSION_MAX_ALLOWED
#define STRect NSRect
#define STContext [NSGraphicsContext currentContext].CGContext
#define STColorClass NSColor
#define STFontClass NSFont
#define STLocalGregorianFontSize 6
#define STSmallLocalGregorianFontSize 5
#define STFontSizeScalar 100
#define STGregorianDayOffset 3
#define STCalendarViewMacosInset 25
#else
#define STRect CGRect
#define STContext UIGraphicsGetCurrentContext()
#define STColorClass UIColor
#define STFontClass UIFont
#define STLocalGregorianFontSize 6
#define STSmallLocalGregorianFontSize 6
#define STFontSizeScalar 320
#define STGregorianDayOffset 3
#define STCalendarViewInsetX 25
#define STCalendarViewInsetY 200
#endif

#define STSecondsPerGregorianDay 86400

#endif /* STDefines_h */
