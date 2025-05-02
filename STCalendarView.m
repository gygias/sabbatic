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
//#define MyNow
#ifdef MyNow
    //NSDate *lastConjunction = [[STState state] lastConjunction];
    //NSDate *lastNewMoonDay = [STCalendar newMoonDayForConjunction:lastConjunction];
    
    // 5 secs before last new moon
    //NSDate *lastNewMoonStart = [[STState state] lastNewMoonStart];
    //NSDate *myNow = [STCalendar date:lastNewMoonStart byAddingDays:0 hours:0 minutes:0 seconds:-5];
    
    // yesterday 5 seconds to midnight
    //NSDate *myNow =   [STCalendar date:[[STState state] normalizeDate:[STCalendar date:[NSDate date] byAddingDays:-1 hours:0 minutes:0 seconds:0]]
    //                      byAddingDays:0 hours:23 minutes:59 seconds:55];
    
    //NSDate *myNow = [STCalendar date:[NSDate myNow] byAddingDays:0 hours:2 minutes:0 seconds:0];
    
    // 5 secs before last sunset
    NSDate *myNow = [[STState state] lastSunsetForDate:[NSDate myNow] momentAfter:YES];
    myNow = [STCalendar date:myNow byAddingDays:0 hours:0 minutes:0 seconds:-5];
    
    NSInteger fast = 0;
    [NSDate setMyNow:myNow realSecondsPerDay:fast];
#else
    [NSDate enqueueRealSunsetNotifications];
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
    
    BOOL foundToday = NO;
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
    NSLog(@"drawing at myNow %@ with lastNewMoonStart %@",[NSDate myNow],lastNewMoonStart);
    NSDictionary *textAttributes = @{ NSForegroundColorAttributeName : [STColorClass redColor],
                                      NSFontAttributeName : [STFontClass systemFontOfSize:[self _fontSizeForViewWidth:dirtyRect.size.width]] };
    NSDictionary *smallAttributes = @{ NSForegroundColorAttributeName : [STColorClass lightGrayColor],
                                       NSFontAttributeName : [STFontClass systemFontOfSize:[self _smallFontSizeForViewWidth:dirtyRect.size.width]] };
    NSDictionary *smallerAttributes = @{ NSForegroundColorAttributeName : [STColorClass grayColor],
                                       NSFontAttributeName : [STFontClass systemFontOfSize:[self _smallerFontSizeForViewWidth:dirtyRect.size.width]] };
    NSString *delimiter = @" - ";
    
    CGSize textSize = [@"foo" sizeWithAttributes:textAttributes];
    CGSize smallTextSize = [@"foo" sizeWithAttributes:smallAttributes];
    CGSize smallerTextSize = [@"foo" sizeWithAttributes:smallerAttributes];
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
#ifdef __MAC_OS_X_VERSION_MAX_ALLOWED
        CGFloat gdY = ldY + STGregorianDayOffset;
        CGFloat ssY = gdY + smallerTextSize.height + 3;
        CGFloat fcY = ssY + smallerTextSize.height + 3;
        //CGFloat sY = ldY + dayHeight / 3;
        ldY += dayHeight - lineWidth - textSize.height;
#else
        CGFloat gdY = ldY + dayHeight - textSize.height;
        CGFloat ssY = gdY - smallerTextSize.height - 1;
        CGFloat fcY = ssY - smallerTextSize.height - 1;
#endif
        for ( int j = 0; j < 7; j++ ) {
            CGFloat columnX = dirtyRect.origin.x + ( j * dayWidth );
            CGFloat columnXOffset = lineWidth;
#ifdef __MAC_OS_X_VERSION_MAX_ALLOWED
            int day = 7 * ( 3 - i ) + j + 1;
#else
            int day = 7 * ( i - 1 ) + j + 1;
#endif
            // +1 hour to handle shortening and lengthening days in one pass (hopefully)
            int effectiveDay = day;
            NSDate *thisDate = [STCalendar date:lastNewMoonStart byAddingDays:effectiveDay hours:1 minutes:0 seconds:0];
            BOOL isLunarToday = [STCalendar isDateInLunarToday:thisDate];
            
            if ( isLunarToday ) {
                if ( foundToday ) {
                    NSLog(@"something is wrong on %@",[NSDate myNow]);
                    //abort();
                }
                foundToday = YES;
                
                NSLog(@"today is lunar %dth, %@",effectiveDay,thisDate);
                [self _drawTodayCircleAtPoint:CGPointMake(columnX + columnXOffset, ldY) withLineWidth:lineWidth textAttributes:textAttributes context:context];
            }
            
            CGFloat yOffset = 0;
//#ifndef __MAC_OS_X_VERSION_MAX_ALLOWED
            yOffset = 1;
//#endif
            if ( effectiveDay < 10 )
                columnXOffset += singleDigitDateXOffset;
            
            [[NSString stringWithFormat:@"%d",effectiveDay + 1] drawAtPoint:CGPointMake(columnX + columnXOffset + lineWidth,ldY + yOffset) withAttributes:textAttributes];
            
            NSString *sunsetHourMinute = [NSString stringWithFormat:@"SS %@",[[[STState state] lastSunsetForDate:thisDate momentAfter:NO] localHourMinuteString]];
            [sunsetHourMinute drawAtPoint:CGPointMake(columnX + columnXOffset, ssY) withAttributes:smallerAttributes];
            
            BOOL waning = NO;
            double fracillum = [[STState state] moonFracillumForDate:thisDate :&waning];
            NSString *fracillumString = [NSString stringWithFormat:@"%0.0f%%%@",fracillum * 100,waning?@" (waning)":@""];
            [fracillumString drawAtPoint:CGPointMake(columnX + columnXOffset, fcY) withAttributes:smallerAttributes];
            
            
            NSString *gregorianString = nil;
            NSAttributedString *attrString = nil;
            // account for lunar day start
            NSDate *mainGregorianDay = [STCalendar date:thisDate byAddingDays:1 hours:0 minutes:0 seconds:0];
            if ( isLunarToday ) {
                gregorianString = [STCalendar localGregorianPreviousAndCurrentDayFromDate:mainGregorianDay delimiter:delimiter];
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
                gregorianString = [STCalendar localGregorianDayOfTheMonthFromDate:mainGregorianDay];
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
    CGFloat ssY = ldY - textSize.height - 3;
    CGFloat gdY = ldY + dayHeight - textSize.height;
#endif
    CGFloat oneX = dirtyRect.origin.x + ( 6 * dayWidth );
    NSDate *lastNewMoonDayMidnight = [[STState state] lastNewMoonDay];
    NSDate *sunsetOnNewMoonDay = [[STState state] lastSunsetForDate:lastNewMoonDayMidnight momentAfter:NO];
    BOOL isLunarToday = [STCalendar isDateInLunarToday:lastNewMoonDayMidnight];
    if ( isLunarToday ) {
        [self _drawTodayCircleAtPoint:CGPointMake(oneX + lineWidth, ldY) withLineWidth:lineWidth textAttributes:textAttributes context:context];
    }
    oneX += singleDigitDateXOffset;
    [@"1" drawAtPoint:CGPointMake(oneX,ldY) withAttributes:textAttributes];
    NSString *sunsetHourMinute = [NSString stringWithFormat:@"SS %@",[sunsetOnNewMoonDay localHourMinuteString]];
    [sunsetHourMinute drawAtPoint:CGPointMake(oneX, ssY) withAttributes:smallerAttributes];
    NSString *gregorianString = nil;
    NSAttributedString *attrString = nil;
    if ( isLunarToday ) {
        
        if ( foundToday ) {
            NSLog(@"something is wrong on %@",[NSDate myNow]);
            //abort();
        }
        foundToday = YES;
        
        gregorianString = [STCalendar localGregorianPreviousAndCurrentDayFromDate:lastNewMoonDayMidnight delimiter:delimiter];
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
        gregorianString = [STCalendar localGregorianDayOfTheMonthFromDate:lastNewMoonDayMidnight];
        attrString = [[NSAttributedString alloc] initWithString:gregorianString attributes:smallerAttributes];
    }
    [attrString drawAtPoint:CGPointMake(oneX,gdY)];

    if ( ! foundToday ) {
        NSLog(@"something is wrong on %@",[NSDate myNow]);
        //abort();
    }
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
