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
#define STLocalGregorianFontSize 8
#define STFontSizeScalar 100
#else
#define STRect CGRect
#define STContext UIGraphicsGetCurrentContext()
#define STColorClass UIColor
#define STFontClass UIFont
#define STLocalGregorianFontSize 7
#define STFontSizeScalar 320
#endif

#endif /* STDefines_h */
