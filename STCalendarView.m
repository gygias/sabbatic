//
//  STCalendarView.m
//  Sabbatic
//
//  Created by david on 3/20/25.
//

#import "STCalendarView.h"

#import "STState.h"
#import "STCalendar.h"
#import "NSDate+MyNow.h"
#import "STDefines.h"

#ifdef __MAC_OS_X_VERSION_MAX_ALLOWED
CGRect gMyInitRect;
#endif

@implementation STCalendarView

- (void)_initMyNowStuff
{    
#define MyNow
#ifdef MyNow
    //NSDate *lastConjunction = [[STState state] lastConjunction];
    //NSDate *lastNewMoonDay = [STCalendar newMoonDayForConjunction:lastConjunction];
#warning START HERE five seconds before lastNewMoonStart, bugs!
    //NSDate *lastNewMoonStart = [[STState state] lastNewMoonStart];
    //NSDate *myNow = [STCalendar date:lastNewMoonDay byAddingDays:24 hours:23 minutes:59 seconds:55];
    //NSDate *myNow = [STCalendar date:lastNewMoonDay byAddingDays:6 hours:23 minutes:59 seconds:55];
    //NSDate *myNow = [STCalendar date:lastNewMoonStart byAddingDays:0 hours:0 minutes:0 seconds:-5];
    //NSDate *myNow = lastNewMoonDay;
    //NSDate *myNow = [[STState state] normalizeDate:[NSDate date] hour:19 minute:53 second:56];
    NSDate *myNow =   [STCalendar date:[[STState state] normalizeDate:[STCalendar date:[NSDate date] byAddingDays:-1 hours:0 minutes:0 seconds:0]]
                          byAddingDays:0 hours:23 minutes:59 seconds:55];
    
    //NSInteger tzOffset = [[NSTimeZone localTimeZone] secondsFromGMTForDate:myNow];
    //myNow = [STCalendar date:myNow byAddingDays:0 hours:0 minutes:0 seconds:tzOffset];
    [NSDate setMyNow:myNow];
#endif
}

#ifdef __MAC_OS_X_VERSION_MAX_ALLOWED
- (id)initWithFrame:(NSRect)frameRect
{
    if ( self = [super initWithFrame:frameRect] ) {
        gMyInitRect = frameRect;
        [self _initMyNowStuff];
    }
    return self;
}
#else
- (id)initWithFrame:(CGRect)frameRect
{
    if ( self = [super initWithFrame:frameRect] ) {
        [self _initMyNowStuff];
    }
    return self;
}
#endif

- (NSInteger)_fontSizeForViewWidth:(CGFloat)width
{
    return 10 + ( width / STFontSizeScalar );
}

- (NSInteger)_smallFontSizeForViewWidth:(CGFloat)width
{
    return STLocalGregorianFontSize + ( width / STFontSizeScalar );
}

- (NSInteger)_smallerFontSizeForViewWidth:(CGFloat)width
{
    return STSmallLocalGregorianFontSize + ( width / STFontSizeScalar );
}

- (void)drawRect:(STRect)dirtyRect {
#ifdef __MAC_OS_X_VERSION_MAX_ALLOWED
    [super drawRect:dirtyRect];
    if ( ! CGRectEqualToRect(dirtyRect, gMyInitRect) ) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            NSLog(@"macos drawrect workaround applied");
        });
        dirtyRect = CGRectInset(dirtyRect, 50, 50);
    }
#endif
    
    CGContextRef context = STContext;
    
    //[[NSColor clearColor] set];
    //NSRectFill(dirtyRect);
    CGContextSetFillColorWithColor(context, [STColorClass clearColor].CGColor);
    CGContextFillRect(context, dirtyRect);
    
    // Drawing code here.
    CGFloat dayWidth = dirtyRect.size.width / 7;
    CGFloat dayHeight = dayWidth;
    
    CGFloat lineWidth = 1;
    CGContextSetLineWidth(context, lineWidth);
    
    // draw calendar frame
    CGRect monthRect = CGRectMake(dirtyRect.origin.x,dirtyRect.origin.y,dirtyRect.size.width,dirtyRect.size.height);
    CGContextAddRect(context, monthRect);
    CGContextSetFillColorWithColor(context, [STColorClass blackColor].CGColor);
    CGContextFillPath(context);
    CGContextSetStrokeColorWithColor(context, [STColorClass redColor].CGColor);
    CGContextStrokePath(context);
    
    for ( int i = 0; i < 8; i++ ) {
        CGFloat columnX = dirtyRect.origin.x + ( i * dayWidth );
        
        CGFloat lineHeight;
        if ( i < 6 ) {
#ifdef __MAC_OS_X_VERSION_MAX_ALLOWED
            lineHeight = dayHeight * 4;
            CGFloat yOff = 0;
#else
            lineHeight = dayHeight * 5;
            CGFloat yOff = dayHeight;
#endif
            CGContextMoveToPoint(context, columnX, dirtyRect.origin.y + yOff);
        } else {
            lineHeight = dayHeight * 5;
            CGContextMoveToPoint(context, columnX, dirtyRect.origin.y);
        }
        CGFloat endY = dirtyRect.size.height > lineHeight ? lineHeight : dirtyRect.size.height;
        CGFloat startY = dirtyRect.origin.y;
        CGContextAddLineToPoint(context, columnX, startY + endY);
        //[[NSString stringWithFormat:@"%d",i] drawAtPoint:CGPointMake(columnX,dirtyRect.origin.y + endY) withAttributes:textAttributes];
    }
    for ( int i = 0; i < 6; i++ ) {
        CGFloat rowY = dirtyRect.origin.y + ( i * dayHeight );
        CGFloat rowX =
#ifdef __MAC_OS_X_VERSION_MAX_ALLOWED
                        ( i < 5 ) ?
#else
                        ( i > 0 ) ?
#endif
                            dirtyRect.origin.x : dirtyRect.origin.x + dayWidth * 6;
        CGContextMoveToPoint(context, rowX, rowY);
        CGContextAddLineToPoint(context, dirtyRect.origin.x + dirtyRect.size.width, rowY);
        //[[NSString stringWithFormat:@"%d",i] drawAtPoint:CGPointMake(rowX,rowY) withAttributes:textAttributes];
    }
    CGContextStrokePath(context);
    
    // draw day numbers
    //NSDate *lastConjunction = [[STState state] lastConjunction];
    //NSDate *lastNewMoonDay = [STCalendar newMoonDayForConjunction:lastConjunction];
    NSDate *lastNewMoonStart = [[STState state] lastNewMoonStart];
    NSLog(@"drawing calendar on %@ with last new moon start %@",[NSDate myNow],lastNewMoonStart);
    NSDictionary *textAttributes = @{ NSForegroundColorAttributeName : [STColorClass redColor],
                                      NSFontAttributeName : [STFontClass systemFontOfSize:[self _fontSizeForViewWidth:dirtyRect.size.width]] };
    NSDictionary *smallAttributes = @{ NSForegroundColorAttributeName : [STColorClass lightGrayColor],
                                       NSFontAttributeName : [STFontClass systemFontOfSize:[self _smallFontSizeForViewWidth:dirtyRect.size.width]] };
    NSDictionary *smallerAttributes = @{ NSForegroundColorAttributeName : [STColorClass grayColor],
                                       NSFontAttributeName : [STFontClass systemFontOfSize:[self _smallerFontSizeForViewWidth:dirtyRect.size.width]] };
    CGSize textSize = [@"foo" sizeWithAttributes:textAttributes];
    CGFloat singleDigitDateXOffset = [@"0" sizeWithAttributes:textAttributes].width / 2;
    //CGSize smallSize = [@"foo" sizeWithAttributes:smallAttributes];
    
    // draw lunation #
    NSInteger monthsSinceNewYear = [[STState state] currentLunarMonth];
    NSString *hebrewMonthString = [STCalendar hebrewMonthForMonth:monthsSinceNewYear];
    CGPoint monthPoint;
#ifdef __MAC_OS_X_VERSION_MAX_ALLOWED
    monthPoint = CGPointMake([self frame].size.width / 2 - textSize.width / 2,[self frame].size.height - textSize.height);
#else
    monthPoint = CGPointMake([self frame].size.width / 2 - textSize.width / 2,dayHeight / 2 - textSize.height / 2);
#endif
    [hebrewMonthString drawAtPoint:monthPoint withAttributes:textAttributes];
    
#ifdef __MAC_OS_X_VERSION_MAX_ALLOWED
    for ( int i = 0; i < 4; i++ ) {
#else
    for ( int i = 1; i < 5; i++ ) {
#endif
        CGFloat ldY = dirtyRect.origin.y + ( i * dayHeight );
        CGFloat ssY = ldY + textSize.height + 3;
#ifdef __MAC_OS_X_VERSION_MAX_ALLOWED
        CGFloat gdY = ldY + STGregorianDayOffset;
        //CGFloat sY = ldY + dayHeight / 3;
        ldY += dayHeight - lineWidth - textSize.height;
#else
        CGFloat gdY = ldY + dayHeight - textSize.height;
        CGFloat sY = ldY + dayHeight / 3;
#endif
        for ( int j = 0; j < 7; j++ ) {
            CGFloat columnX = dirtyRect.origin.x + ( j * dayWidth );
            CGFloat columnXOffset = lineWidth;
#ifdef __MAC_OS_X_VERSION_MAX_ALLOWED
            int day = 7 * ( 3 - i ) + j + 2;
#else
            int day = 7 * ( i - 1 ) + j + 2;
#endif
            NSDate *newMoonGregorianStart = [[STState state] lastNewMoonDay];
            NSDate *thisDate = [STCalendar date:newMoonGregorianStart byAddingDays:day - 1 hours:1 minutes:0 seconds:0];
            BOOL isLunarToday = [STCalendar isDateInLunarToday:[[STState state] lastSunsetForDate:thisDate momentAfter:YES]];
            
            if ( isLunarToday ) {
                [self _drawTodayCircleAtPoint:CGPointMake(columnX + columnXOffset, ldY) withLineWidth:lineWidth textAttributes:textAttributes context:context];
            }
            
            CGFloat yOffset = 0;
//#ifndef __MAC_OS_X_VERSION_MAX_ALLOWED
            yOffset = 1;
//#endif
            if ( day < 10 )
                columnXOffset += singleDigitDateXOffset;
            
            [[NSString stringWithFormat:@"%d",day] drawAtPoint:CGPointMake(columnX + columnXOffset + lineWidth,ldY + yOffset) withAttributes:textAttributes];
            
            NSString *sunsetHourMinute = [NSString stringWithFormat:@"SS %@",[[[STState state] lastSunsetForDate:thisDate momentAfter:NO] localHourMinuteString]];
            [sunsetHourMinute drawAtPoint:CGPointMake(columnX + columnXOffset, ssY) withAttributes:smallerAttributes];
            
            NSString *delimiter = @" - ";
            NSString *gregorianString = nil;
            NSAttributedString *attrString = nil;
            if ( isLunarToday ) {
                gregorianString = [STCalendar localGregorianPreviousAndCurrentDayFromDate:thisDate delimiter:delimiter];
                attrString = [[NSMutableAttributedString alloc] initWithString:gregorianString];
                NSRange delimiterRange = [gregorianString rangeOfString:delimiter];
                if ( delimiterRange.location != NSNotFound ) {
                    BOOL betweenSunsetAndMidnight = [STCalendar isDateBetweenSunsetAndGregorianMidnight:[NSDate myNow]];
                    [(NSMutableAttributedString *)attrString addAttributes:betweenSunsetAndMidnight ? smallAttributes : smallerAttributes range:NSMakeRange(0, delimiterRange.location + [delimiter length])];
                    delimiterRange = [gregorianString rangeOfString:delimiter];
                    NSUInteger thisStart = delimiterRange.location + delimiterRange.length;
                    [(NSMutableAttributedString *)attrString addAttributes:betweenSunsetAndMidnight ? smallerAttributes : smallAttributes range:NSMakeRange(thisStart, [attrString length] - thisStart)];
                }
            } else {
                gregorianString = [STCalendar localGregorianDayOfTheMonthFromDate:thisDate];
                attrString = [[NSAttributedString alloc] initWithString:gregorianString attributes:smallerAttributes];
            }
            [attrString drawAtPoint:CGPointMake(columnX + columnXOffset,gdY)];
            
            // a sabbath
            if ( j == 6 ) {
            }
        }
    }
#ifdef __MAC_OS_X_VERSION_MAX_ALLOWED
    CGFloat ldY = dirtyRect.origin.y + ( 4 * dayHeight );
    CGFloat ssY = ldY + textSize.height + 3;
    CGFloat gdY = ldY + STGregorianDayOffset;
    ldY += dayHeight - textSize.height;
#else
    CGFloat ldY = dirtyRect.origin.y;
    CGFloat gdY = ldY + dayHeight - textSize.height;
#endif
    CGFloat oneX = dirtyRect.origin.x + ( 6 * dayWidth );
    if ( [STCalendar isDateInLunarToday:lastNewMoonStart] ) {
        [self _drawTodayCircleAtPoint:CGPointMake(oneX + lineWidth, ldY) withLineWidth:lineWidth textAttributes:textAttributes context:context];
    }
    oneX += singleDigitDateXOffset;
    [@"1" drawAtPoint:CGPointMake(oneX,ldY) withAttributes:textAttributes];
    NSDate *lastNewMoonDayMidnight = [[STState state] lastNewMoonDay];
    NSDate *sunsetOnNewMoonDay = [[STState state] lastSunsetForDate:lastNewMoonDayMidnight momentAfter:NO];
    NSString *sunsetHourMinute = [NSString stringWithFormat:@"SS %@",[sunsetOnNewMoonDay localHourMinuteString]];
    [sunsetHourMinute drawAtPoint:CGPointMake(oneX, ssY) withAttributes:smallerAttributes];
    NSString *gregorianMonthDay = [STCalendar localGregorianDayOfTheMonthFromDate:lastNewMoonDayMidnight];
    [gregorianMonthDay drawAtPoint:CGPointMake(oneX,gdY) withAttributes:smallerAttributes];
}

- (void)_drawTodayCircleAtPoint:(CGPoint)point withLineWidth:(CGFloat)lineWidth textAttributes:(NSDictionary *)textAttributes context:(CGContextRef)context
{
    
    CGSize dateSize = [@"00" sizeWithAttributes:textAttributes];
    CGPoint dateCenter = CGPointMake(point.x + dateSize.width / 2 + lineWidth,
                                     point.y + dateSize.height / 2);
#ifdef __MAC_OS_X_VERSION_MAX_ALLOWED
    dateCenter.y -= lineWidth;
#else
    dateCenter.y += lineWidth * 2;
#endif
    
    CGContextSetLineWidth(context,1);
    CGContextSetFillColorWithColor(context, [STColorClass grayColor].CGColor);
    CGContextAddArc(context,dateCenter.x,dateCenter.y,dateSize.width / 2 + lineWidth,0.0,M_PI*2,YES);
    CGContextFillPath(context);
    
    //[@"🌞" drawAtPoint:CGPointMake(columnX + dayWidth / 3,sY) withAttributes:textAttributes];
}

@end
