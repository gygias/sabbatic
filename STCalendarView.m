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

@interface STCalendarView ()
@property STRect dirtyRect;
@property CGFloat dayHeight;
@property CGFloat dayWidth;
@property CGFloat lineWidth;
@property CGFloat calendarBoxOriginX;
@property CGFloat calendarBoxOriginY;
@property (strong) NSDictionary *bigTextAttributes;
@property (strong) NSDictionary *textAttributes;
@property (strong) NSDictionary *redAttributes;
@property (strong) NSDictionary *smallAttributes;
@property (strong) NSDictionary *smallerAttributes;
@property CGSize bigTextSize;
@property CGSize textSize;
@property CGSize smallTextSize;
@property CGSize smallerTextSize;
@property (strong) NSString *delimiter;
@end

@implementation STCalendarView

- (void)_initMyNowStuff
{    
//#define MyNow
#define fast 0
#ifdef MyNow
#warning this becomes -66 seconds from nms notification. if you wait it out the transition is smooth. \
        if you don't and try to add a minute here, there is no today until the notification fires, \
        there is a minute of no-mans-land would benefit from longer or "real life" draw intervals \
        (and, it draws intercalary, as if based on this month) \
        put it on fast mode and 'two todays' will walk across the calendar :-)
    //NSDate *myNow = [STCalendar date:[DP lastNewMoonStart] byAddingDays:0 hours:0 minutes:0 seconds:-5];
    
    //NSDate *myNow = [NSDate myNow];
    //NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    //NSDate *myNow = [gregorian dateWithEra:1 year:2025 month:4 day:27 hour:19 minute:49 second:0 nanosecond:0];
    
    // yesterday 5 seconds to midnight
    //NSDate *myNow =   [STCalendar date:[DP normalizeDate:[STCalendar date:[NSDate date] byAddingDays:-1 hours:0 minutes:0 seconds:0]]
    //                      byAddingDays:0 hours:23 minutes:59 seconds:55];
    
    // today at x x x
    //NSDate *myNow =   [[NSDate date] normalizedDatePlusHour:19 minute:57 second:55];
    
    // 5 secs before last sunset
    //NSDate *myNow = [DP lastSunsetForDate:[NSDate myNow] momentAfter:YES];
    //myNow = [STCalendar date:myNow byAddingDays:0 hours:0 minutes:0 seconds:-5];
    
    // plain old now
    //NSDate *myNow = [NSDate myNow];
    
    // 15 days ago
    //NSDate *myNow = [STCalendar date:[NSDate date] byAddingDays:-15 hours:0 minutes:0 seconds:0];
    
    // 30 days from now
    //NSDate *myNow = [STCalendar date:[NSDate date] byAddingDays:30 hours:0 minutes:0 seconds:0];
    
    // 1 hour ago
    //NSDate *myNow = [STCalendar date:[NSDate date] byAddingDays:0 hours:-1 minutes:0 seconds:0];
    
    // 12 hours from now
    NSDate *myNow = [STCalendar date:[NSDate date] byAddingDays:0 hours:12 minutes:0 seconds:0];
    
    [NSDate setMyNow:myNow realSecondsPerDay:fast];
#else
    [NSDate enqueueRealSunsetNotifications];
#endif
}

- (void)preload
{
    if ( [DP isKindOfClass:[STUSNODataProvider class]] ) {
#ifdef __MAC_OS_X_VERSION_MAX_ALLOWED
        for ( int i = 0; i < 4; i++ ) {
#else
            for ( int i = 1; i < 5; i++ ) {
#endif
                for ( int j = 0; j < 7; j++ ) {
#ifdef __MAC_OS_X_VERSION_MAX_ALLOWED
                    NSInteger day = 7 * ( 3 - i ) + j + 1;
#else
                    NSInteger day = 7 * ( i - 1 ) + j + 1;
#endif
                    NSInteger effectiveDay = day;
                    NSDate *thisDate = [STCalendar date:self.effectiveNewMoonStart byAddingDays:effectiveDay hours:1 minutes:0 seconds:0];
                    [DP lastSunsetForDate:thisDate momentAfter:YES];
            }
        }
    }
}


#ifdef __MAC_OS_X_VERSION_MAX_ALLOWED
- (BOOL)acceptsFirstResponder {
    return YES;
}

- (void)keyDown:(NSEvent *)event {
    NSLog(@"keyDown: %@",event);
    if ( event.type == NSEventTypeKeyDown ) {
        if ( ! event.ARepeat ) {
            if ( event.keyCode == 126 )
                self.moveUpHandler();
            else if ( event.keyCode == 125 )
                self.moveDownHandler();
        }
    }
}
#endif

- (void)drawRect:(STRect)dirtyRect {
#ifdef __MAC_OS_X_VERSION_MAX_ALLOWED
    [super drawRect:dirtyRect];
    if ( ! CGRectEqualToRect(dirtyRect, gMyInitRect) ) {
        dirtyRect = CGRectInset(dirtyRect, STCalendarViewInsetX, STCalendarViewInsetY);
    }
#endif
    BOOL foundToday = NO;
    NSDate *lastNewMoonStart = self.effectiveNewMoonStart;
    // may be two literal conjunctions ago, when drawing between conjunction and new moon start
    NSDate *effectiveLastConjunction = [DP conjunctionPriorToDate:lastNewMoonStart];
    NSDate *nextConjunction = [DP conjunctionPriorToDate:[STCalendar date:effectiveLastConjunction byAddingDays:30 hours:0 minutes:0 seconds:0]];
    // handle time between conjunction and next new moon day
    //NSTimeInterval timeUntilNextConjunction = [aConjunction timeIntervalSinceDate:[NSDate myNow]];
    //if ( timeUntilNextConjunction > STSecondsPerLunarDay )
    //    aConjunction = [DP lastConjunction];
    BOOL intercalary = NO;
    __unused NSDate *nextNewMoonStart = [STCalendar newMoonDayForConjunction:nextConjunction :&intercalary];
    NSLog(@"drawing %@month at myNow %@ with\n\tlastNewMoonStart %@\n\teffectiveLastConjunction %@\n\tnextNewMoonStart %@",intercalary?@"intercalary ":@"",[NSDate myNow],lastNewMoonStart,effectiveLastConjunction,nextNewMoonStart);
    
    CGContextRef context = STContext;
    
    // Drawing code here.
    self.dirtyRect = dirtyRect;
    self.dayWidth = dirtyRect.size.width / 7;
#ifdef __MAC_OS_X_VERSION_MAX_ALLOWED
    self.dayHeight = intercalary ? self.dayWidth * .8 : self.dayWidth;
#else
#warning todo scale based on screen height
    self.dayHeight = self.dayWidth * 1.5;
#endif
    
    self.lineWidth = STCalendarLineWidth;
    CGContextSetLineWidth(context, self.lineWidth);
    
    // draw calendar frame
#ifdef __MAC_OS_X_VERSION_MAX_ALLOWED
    self.calendarBoxOriginX = dirtyRect.origin.x;
    self.calendarBoxOriginY = intercalary ? dirtyRect.origin.y + self.dayHeight : dirtyRect.origin.y;
#else
    self.calendarBoxOriginX = dirtyRect.origin.x + self.lineWidth / 2;
    self.calendarBoxOriginY = dirtyRect.origin.y;
#endif
    [self _drawCalendarFrame:intercalary];
    
    self.bigTextAttributes = @{ NSForegroundColorAttributeName : [STColorClass lightGrayColor],
                                NSFontAttributeName : [STFontClass systemFontOfSize:[self _bigFontSizeForViewWidth:dirtyRect.size.width]] };
    self.textAttributes = @{ NSForegroundColorAttributeName : [STColorClass lightGrayColor],
                              NSFontAttributeName : [STFontClass systemFontOfSize:[self _fontSizeForViewWidth:dirtyRect.size.width]] };
    self.redAttributes = @{ NSForegroundColorAttributeName : [STColorClass redColor],
                              NSFontAttributeName : [STFontClass systemFontOfSize:[self _fontSizeForViewWidth:dirtyRect.size.width]] };
    self.smallAttributes = @{ NSForegroundColorAttributeName : [STColorClass lightGrayColor],
                               NSFontAttributeName : [STFontClass systemFontOfSize:[self _smallFontSizeForViewWidth:dirtyRect.size.width]] };
    self.smallerAttributes = @{ NSForegroundColorAttributeName : [STColorClass grayColor],
                                   NSFontAttributeName : [STFontClass systemFontOfSize:[self _smallerFontSizeForViewWidth:dirtyRect.size.width]] };
#ifdef __MAC_OS_X_VERSION_MAX_ALLOWED
    self.delimiter = @" - ";
#else
    self.delimiter = @"-";
#endif
    
    NSInteger monthsSinceNewYear = [DP lunarMonthForDate:self.effectiveNewMoonStart];
    NSString *hebrewMonthString = [STCalendar hebrewStringMonthForMonth:monthsSinceNewYear :self.effectiveNewMoonStart];
    self.bigTextSize = [hebrewMonthString sizeWithAttributes:self.bigTextAttributes];
    self.textSize = [@"foo" sizeWithAttributes:self.textAttributes];
    self.smallTextSize = [@"foo" sizeWithAttributes:self.smallAttributes];
    self.smallerTextSize = [@"foo" sizeWithAttributes:self.smallerAttributes];
    //CGFloat singleDigitDateXOffset = [@"0" sizeWithAttributes:self.textAttributes].width / 2;
    //CGSize smallSize = [@"foo" sizeWithAttributes:smallAttributes];
    
    // draw lunation #
    CGPoint monthPoint;
#ifdef __MAC_OS_X_VERSION_MAX_ALLOWED
    monthPoint = CGPointMake([self frame].size.width / 2 - self.bigTextSize.width / 2,[self frame].size.height - self.bigTextSize.height * 4);
#else
    monthPoint = CGPointMake([self frame].size.width / 2 - self.bigTextSize.width / 2,self.dayHeight / 2 - self.bigTextSize.height / 2);
#endif
    [hebrewMonthString drawAtPoint:monthPoint withAttributes:self.bigTextAttributes];
    
#ifdef __MAC_OS_X_VERSION_MAX_ALLOWED
    for ( int i = 0; i < 4; i++ ) {
#else
    for ( int i = 1; i < 5; i++ ) {
#endif
        CGFloat ldY = self.calendarBoxOriginY + ( i * self.dayHeight );
        for ( int j = 0; j < 7; j++ ) {
            CGFloat columnX = self.calendarBoxOriginX + ( j * self.dayWidth );
            //CGFloat columnXOffset = lineWidth;
#ifdef __MAC_OS_X_VERSION_MAX_ALLOWED
            NSInteger day = 7 * ( 3 - i ) + j + 1;
#else
            NSInteger day = 7 * ( i - 1 ) + j + 1;
            columnX--;
#endif
            NSInteger effectiveDay = day;
            // +1 hour to handle shortening and lengthening days in one pass (hopefully)
            NSDate *thisDate = [STCalendar date:lastNewMoonStart byAddingDays:effectiveDay hours:1 minutes:0 seconds:0];
            BOOL isLunarToday = [STCalendar isDateInLunarToday:thisDate];
            [self drawDayAtPoint:CGPointMake(columnX,ldY) lunarDay:effectiveDay + 1 lunarMonth:monthsSinceNewYear date:thisDate asToday:isLunarToday foundToday:&foundToday];
        }
    }
        
    CGFloat oneX = dirtyRect.origin.x + ( 6 * self.dayWidth );
#ifdef __MAC_OS_X_VERSION_MAX_ALLOWED
    CGFloat ldY = self.calendarBoxOriginY + ( 4 * self.dayHeight );
#else
    CGFloat ldY = self.calendarBoxOriginY;
    oneX--;
#endif
    
    BOOL isLunarToday = [STCalendar isDateInLunarToday:self.effectiveNewMoonStart];
    NSDate *someTimeLater = [STCalendar date:self.effectiveNewMoonStart byAddingDays:0 hours:5 minutes:0 seconds:0];
    [self drawDayAtPoint:CGPointMake(oneX,ldY) lunarDay:1 lunarMonth:monthsSinceNewYear date:someTimeLater asToday:isLunarToday foundToday:&foundToday];
    
    if ( intercalary ) {
        int effectiveDay = 29;
        oneX = dirtyRect.origin.x;
#ifdef __MAC_OS_X_VERSION_MAX_ALLOWED
        CGFloat ldY = self.calendarBoxOriginY - self.dayHeight;
#else
        CGFloat ldY = self.calendarBoxOriginY + ( 5 * self.dayHeight );
#endif
        NSDate *thisDate = [STCalendar date:lastNewMoonStart byAddingDays:effectiveDay hours:1 minutes:0 seconds:0];
        BOOL isLunarToday = [STCalendar isDateInLunarToday:thisDate];
        [self drawDayAtPoint:CGPointMake(oneX,ldY) lunarDay:effectiveDay + 1 lunarMonth:monthsSinceNewYear date:thisDate asToday:isLunarToday foundToday:&foundToday];
    }
    
    if ( ! foundToday ) {
        NSLog(@"BUG: no todays on %@",[NSDate myNow]);
        //abort();
    }
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
    
- (NSInteger)_bigFontSizeForViewWidth:(CGFloat)width
{
    return 15 + ( width / STFontSizeScalar );
}

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

- (void)_drawCalendarFrame:(BOOL)intercalary
{
    CGContextRef context = STContext;
    
    CGContextAddRect(context, self.dirtyRect);
    CGContextSetFillColorWithColor(context, [STColorClass clearColor].CGColor);
    CGContextFillPath(context);
    CGContextSetStrokeColorWithColor(context, [STColorClass darkGrayColor].CGColor);
    CGContextStrokePath(context);
    
    for ( int i = 0; i < 8; i++ ) {
        CGFloat columnX = self.calendarBoxOriginX + ( i * self.dayWidth );
        if ( i == 7 )
            columnX -= 2 * ( self.calendarBoxOriginX - self.dirtyRect.origin.x);
        
        CGFloat endY;
        if ( intercalary && ( i == 0 || i == 1 ) ) {
#ifdef __MAC_OS_X_VERSION_MAX_ALLOWED
            endY = self.dayHeight * 4;
            CGFloat yOrigin = self.dirtyRect.origin.y;
#else
            CGFloat yOrigin = self.calendarBoxOriginY + self.dayHeight;
            endY = self.dayHeight * 6;
#endif
            CGContextMoveToPoint(context, columnX, yOrigin);
        } else if ( i >= 6 ) {
            endY = self.dayHeight * 5;
            CGContextMoveToPoint(context, columnX, self.calendarBoxOriginY);
        } else {
#ifdef __MAC_OS_X_VERSION_MAX_ALLOWED
            endY = self.dayHeight * 4;
            CGFloat yOff = 0;
#else
            endY = self.dayHeight * 5;
            CGFloat yOff = self.dayHeight;
#endif
            CGContextMoveToPoint(context, columnX, self.calendarBoxOriginY + yOff);
        }
        
        CGContextAddLineToPoint(context, columnX, self.calendarBoxOriginY + endY);
        //[[NSString stringWithFormat:@"%d",i] drawAtPoint:CGPointMake(columnX,dirtyRect.origin.y + endY) withAttributes:textAttributes];
    }
    
    // draw common lines to RHS
    for ( int i = 0; i < 6; i++ ) {
        CGFloat rowY = self.calendarBoxOriginY + ( i * self.dayHeight );
        CGFloat rowX =
#ifdef __MAC_OS_X_VERSION_MAX_ALLOWED
                        ( i < 5 ) ?
#else
                        ( i > 0 ) ?
#endif
                            self.dirtyRect.origin.x : self.dirtyRect.origin.x + self.dayWidth * 6;
        CGContextMoveToPoint(context, rowX, rowY);
        CGContextAddLineToPoint(context, self.dirtyRect.origin.x + self.dirtyRect.size.width, rowY);
        //[[NSString stringWithFormat:@"%d",i] drawAtPoint:CGPointMake(rowX,rowY) withAttributes:textAttributes];
    }
    CGContextStrokePath(context);
    
    if ( intercalary ) {
#ifdef __MAC_OS_X_VERSION_MAX_ALLOWED
        CGFloat yOrigin = self.dirtyRect.origin.y;
#else
        CGFloat yOrigin = self.calendarBoxOriginY + self.dayHeight * 6;
#endif
        CGContextMoveToPoint(context, self.dirtyRect.origin.x, yOrigin);
        CGContextAddLineToPoint(context, self.dirtyRect.origin.x + self.dayWidth, yOrigin);
        CGContextStrokePath(context);
    }
}

- (void)drawDayAtPoint:(CGPoint)point lunarDay:(NSInteger)lunarDay lunarMonth:(NSInteger)lunarMonth date:(NSDate *)date asToday:(BOOL)asToday foundToday:(BOOL *)foundToday
{
    CGContextRef context = STContext;
    
    CGFloat oneX = point.x;
    CGFloat ldY = point.y;
    
    NSString *lunarString = [NSString stringWithFormat:@"%ld",lunarDay];
    CGFloat lunarWidth = [lunarString sizeWithAttributes:self.textAttributes].width;
    CGFloat lunarHeight = [lunarString sizeWithAttributes:self.textAttributes].height;
    
    CGFloat xOffset = [@"0" sizeWithAttributes:self.smallerAttributes].width / 2;
    
#ifdef __MAC_OS_X_VERSION_MAX_ALLOWED
    CGFloat gdY = ldY + STSmallTextStackOffsetY;
    CGFloat ssY = gdY + self.smallerTextSize.height + STSmallTextOffsetY;
    CGFloat fcY = ssY + self.smallerTextSize.height + STSmallTextOffsetY;
    CGFloat mdY = fcY + self.smallerTextSize.height + STSmallTextOffsetY;
    ldY += self.dayHeight - self.textSize.height;
    CGFloat circleOffsetX = self.lineWidth;
    CGFloat circleOffsetY = - ( self.lineWidth );
    CGFloat lunarOffsetX = [lunarString length] == 1 ? lunarWidth + STLunarDayOffsetX : lunarWidth / STLunarDayScalarX;
    CGFloat lunarOffsetY = - ( lunarHeight / STLunarDayScalarY );
#else
    CGFloat gdY = ldY + self.dayHeight - self.smallerTextSize.height - STSmallTextOffsetY;
    CGFloat ssY = gdY - self.smallerTextSize.height - STSmallTextOffsetY;
    CGFloat fcY = ssY - self.smallerTextSize.height - STSmallTextOffsetY;
    CGFloat mdY = fcY - self.smallerTextSize.height - STSmallTextOffsetY;
    CGFloat circleOffsetX = self.lineWidth * 2;
    CGFloat circleOffsetY = self.lineWidth;
    CGFloat lunarOffsetX = [lunarString length] == 1 ? lunarWidth + STLunarDayScalarX : lunarWidth / STLunarDayScalarX;
    CGFloat lunarOffsetY = ( lunarHeight / STLunarDayScalarY );
#endif
    
#warning it's off by one, this is location/api dependent and needs to be fixed
    NSDate *tomorrow = [STCalendar date:date byAddingDays:1 hours:0 minutes:0 seconds:0];
    NSDate *sunset = [DP lastSunsetForDate:tomorrow momentAfter:NO];
    
    if ( asToday ) {
        [self _drawTodayCircleAtPoint:CGPointMake(oneX + circleOffsetX, ldY + circleOffsetY) withLineWidth:self.lineWidth textAttributes:self.textAttributes context:context];
    }
    
    NSDictionary *thisAttributes = self.textAttributes;
    if ( ( lunarDay - 1 ) % 7 == 0 )
        thisAttributes = self.redAttributes;
    [lunarString drawAtPoint:CGPointMake(oneX + lunarOffsetX,ldY + lunarOffsetY) withAttributes:thisAttributes];
    NSString *sunsetHourMinute = [NSString stringWithFormat:@"SS %@",[sunset localHourMinuteString]];
    [sunsetHourMinute drawAtPoint:CGPointMake(oneX + xOffset, ssY) withAttributes:self.smallerAttributes];

    BOOL waning = NO;
    double fracillum = [DP moonFracillumForDate:date :&waning];
    NSString *fracillumString = [NSString stringWithFormat:@"%0.0f%%",fracillum * 100];
    [fracillumString drawAtPoint:CGPointMake(oneX + xOffset, fcY) withAttributes:self.smallerAttributes];
    
    NSString *moedString = [STCalendar moedStringForLunarDay:lunarDay - 1 ofLunarMonth:lunarMonth];
    if ( moedString ) {
        [moedString drawAtPoint:CGPointMake(oneX + xOffset, mdY) withAttributes:self.smallerAttributes];
    }
    
    // draw attributed gregorian date
    NSString *gregorianString = nil;
    NSAttributedString *attrString = nil;
    // account for lunar day start on dynamic days
    NSDate *gregorianDay = nil;
    if ( lunarDay > 1 )
        gregorianDay = [STCalendar date:date byAddingDays:1 hours:0 minutes:0 seconds:0];
    else
        gregorianDay = date;
    
    if ( asToday ) {
        
        if ( *foundToday ) {
            NSLog(@"BUG: multiple todays on %@",[NSDate myNow]);
            //abort();
        }
        *foundToday = YES;
        
        gregorianString = [STCalendar localGregorianPreviousAndCurrentDayFromDate:gregorianDay delimiter:self.delimiter];
        attrString = [[NSMutableAttributedString alloc] initWithString:gregorianString];
        NSRange delimiterRange = [gregorianString rangeOfString:self.delimiter];
        if ( delimiterRange.location != NSNotFound ) {
            BOOL betweenSunsetAndMidnight = [STCalendar isDateBetweenSunsetAndGregorianMidnight:[NSDate myNow]];
            [(NSMutableAttributedString *)attrString addAttributes:betweenSunsetAndMidnight ? self.smallAttributes : self.smallerAttributes range:NSMakeRange(0, delimiterRange.location + [self.delimiter length])];
            delimiterRange = [gregorianString rangeOfString:self.delimiter];
            NSUInteger thisStart = delimiterRange.location + delimiterRange.length;
            [(NSMutableAttributedString *)attrString addAttributes:betweenSunsetAndMidnight ? self.smallerAttributes : self.smallAttributes range:NSMakeRange(thisStart, [attrString length] - thisStart)];
        }
    } else {
        gregorianString = [STCalendar localGregorianDayOfTheMonthFromDate:gregorianDay];
        attrString = [[NSAttributedString alloc] initWithString:gregorianString attributes:self.smallerAttributes];
    }
    [attrString drawAtPoint:CGPointMake(oneX + xOffset,gdY)];
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
    CGContextSetFillColorWithColor(context, [STColorClass darkGrayColor].CGColor);
    CGContextAddArc(context,dateCenter.x,dateCenter.y,dateSize.width / 2 + lineWidth,0.0,M_PI*2,YES);
    CGContextFillPath(context);
    
    //[@"🌞" drawAtPoint:CGPointMake(columnX + dayWidth / 3,sY) withAttributes:textAttributes];
}

@end
