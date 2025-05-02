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
@property CGFloat calendarBoxOrigin;
@property (strong) NSDictionary *textAttributes;
@property (strong) NSDictionary *smallAttributes;
@property (strong) NSDictionary *smallerAttributes;
@property CGSize textSize;
@property CGSize smallTextSize;
@property CGSize smallerTextSize;
@property (strong) NSString *delimiter;
@end

@implementation STCalendarView

- (void)_initMyNowStuff
{    
//#define MyNow
#ifdef MyNow
    
    // yesterday 5 seconds to midnight
    //NSDate *myNow =   [STCalendar date:[[STState state] normalizeDate:[STCalendar date:[NSDate date] byAddingDays:-1 hours:0 minutes:0 seconds:0]]
    //                      byAddingDays:0 hours:23 minutes:59 seconds:55];
    
    // today at x x x
    //NSDate *myNow =   [STCalendar date:[[STState state] normalizeDate:[NSDate date]]
    //                      byAddingDays:0 hours:19 minutes:53 seconds:55];
    
    // 5 secs before last sunset
    //NSDate *myNow = [[STState state] lastSunsetForDate:[NSDate myNow] momentAfter:YES];
    //myNow = [STCalendar date:myNow byAddingDays:0 hours:0 minutes:0 seconds:-5];
    
    // plain old now
    //NSDate *myNow = [NSDate myNow];
    
    // 15 days ago
    NSDate *myNow = [STCalendar date:[NSDate date] byAddingDays:-15 hours:0 minutes:0 seconds:0];
    
    NSInteger fast = 0;
    [NSDate setMyNow:myNow realSecondsPerDay:fast];
#else
    [NSDate enqueueRealSunsetNotifications];
#endif
}

- (void)drawRect:(STRect)dirtyRect {
#ifdef __MAC_OS_X_VERSION_MAX_ALLOWED
    [super drawRect:dirtyRect];
    if ( ! CGRectEqualToRect(dirtyRect, gMyInitRect) ) {
        dirtyRect = CGRectInset(dirtyRect, STCalendarViewMacosInset, STCalendarViewMacosInset);
    }
#endif
    BOOL foundToday = NO;
    NSDate *lastNewMoonStart = [[STState state] lastNewMoonStart];
    NSDate *nextConjunction = [[STState state] nextConjunction];
    BOOL intercalary = NO;
    __unused NSDate *nextNewMoonStart = [STCalendar newMoonDayForConjunction:nextConjunction :&intercalary];
    NSLog(@"drawing %@month at myNow %@ with lastNewMoonStart %@",intercalary?@"intercalary ":@"",[NSDate myNow],lastNewMoonStart);
    
    CGContextRef context = STContext;
    
    CGContextSetFillColorWithColor(context, [STColorClass clearColor].CGColor);
    CGContextFillRect(context, dirtyRect);
    
    // Drawing code here.
    self.dirtyRect = dirtyRect;
    self.dayWidth = dirtyRect.size.width / 7;
#ifdef __MAC_OS_X_VERSION_MAX_ALLOWED
    self.dayHeight = intercalary ? self.dayWidth * .8 : self.dayWidth;
#else
    self.dayHeight = self.dayWidth * 1.5;
#endif
    
    self.lineWidth = 2;
    CGContextSetLineWidth(context, self.lineWidth);
    
    // draw calendar frame
#ifdef __MAC_OS_X_VERSION_MAX_ALLOWED
    self.calendarBoxOrigin = intercalary ? dirtyRect.origin.y + self.dayHeight : dirtyRect.origin.y;
#else
    self.calendarBoxOrigin = dirtyRect.origin.y;
#endif
    [self _drawCalendarFrame:intercalary];
    
    // draw day numbers
    self.textAttributes = @{ NSForegroundColorAttributeName : [STColorClass redColor],
                              NSFontAttributeName : [STFontClass systemFontOfSize:[self _fontSizeForViewWidth:dirtyRect.size.width]] };
    self.smallAttributes = @{ NSForegroundColorAttributeName : [STColorClass lightGrayColor],
                               NSFontAttributeName : [STFontClass systemFontOfSize:[self _smallFontSizeForViewWidth:dirtyRect.size.width]] };
    self.smallerAttributes = @{ NSForegroundColorAttributeName : [STColorClass grayColor],
                                   NSFontAttributeName : [STFontClass systemFontOfSize:[self _smallerFontSizeForViewWidth:dirtyRect.size.width]] };
    self.delimiter = @" - ";
    
    self.textSize = [@"foo" sizeWithAttributes:self.textAttributes];
    self.smallTextSize = [@"foo" sizeWithAttributes:self.smallAttributes];
    self.smallerTextSize = [@"foo" sizeWithAttributes:self.smallerAttributes];
    //CGFloat singleDigitDateXOffset = [@"0" sizeWithAttributes:self.textAttributes].width / 2;
    //CGSize smallSize = [@"foo" sizeWithAttributes:smallAttributes];
    
    // draw lunation #
    NSInteger monthsSinceNewYear = [[STState state] currentLunarMonth];
    NSString *hebrewMonthString = [STCalendar hebrewMonthForMonth:monthsSinceNewYear];
    CGPoint monthPoint;
#ifdef __MAC_OS_X_VERSION_MAX_ALLOWED
    monthPoint = CGPointMake([self frame].size.width / 2 - self.textSize.width / 2,[self frame].size.height - self.textSize.height);
#else
    monthPoint = CGPointMake([self frame].size.width / 2 - self.textSize.width / 2,self.dayHeight / 2 - self.textSize.height / 2);
#endif
    [hebrewMonthString drawAtPoint:monthPoint withAttributes:self.textAttributes];
    
#ifdef __MAC_OS_X_VERSION_MAX_ALLOWED
    for ( int i = 0; i < 4; i++ ) {
#else
    for ( int i = 1; i < 5; i++ ) {
#endif
        CGFloat ldY = self.calendarBoxOrigin + ( i * self.dayHeight );
        for ( int j = 0; j < 7; j++ ) {
            CGFloat columnX = dirtyRect.origin.x + ( j * self.dayWidth );
            //CGFloat columnXOffset = lineWidth;
#ifdef __MAC_OS_X_VERSION_MAX_ALLOWED
            int day = 7 * ( 3 - i ) + j + 1;
#else
            int day = 7 * ( i - 1 ) + j + 1;
#endif
            // +1 hour to handle shortening and lengthening days in one pass (hopefully)
            int effectiveDay = day;
            NSDate *thisDate = [STCalendar date:lastNewMoonStart byAddingDays:effectiveDay hours:1 minutes:0 seconds:0];
            BOOL isLunarToday = [STCalendar isDateInLunarToday:thisDate];
            [self drawDayAtPoint:CGPointMake(columnX,ldY) lunar:effectiveDay + 1 date:thisDate asToday:isLunarToday foundToday:&foundToday];
        }
    }
#ifdef __MAC_OS_X_VERSION_MAX_ALLOWED
    CGFloat ldY = self.calendarBoxOrigin + ( 4 * self.dayHeight );
#else
    CGFloat ldY = self.calendarBoxOrigin;
#endif
    CGFloat oneX = dirtyRect.origin.x + ( 6 * self.dayWidth );
        
    NSDate *lastNewMoonDayMidnight = [[STState state] lastNewMoonDay];
    //NSDate *sunsetOnNewMoonDay = [[STState state] lastSunsetForDate:lastNewMoonDayMidnight momentAfter:NO];
    BOOL isLunarToday = [STCalendar isDateInLunarToday:lastNewMoonDayMidnight];
    [self drawDayAtPoint:CGPointMake(oneX,ldY) lunar:1 date:lastNewMoonDayMidnight asToday:isLunarToday foundToday:&foundToday];

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
    
    //CGFloat calendarBoxHeight = intercalary ? self.dirtyRect.size.height - self.dayHeight : self.dirtyRect.size.height;
    CGRect monthRect = CGRectMake(self.dirtyRect.origin.x,self.dirtyRect.origin.y,self.dirtyRect.size.width,self.dirtyRect.size.height);
    CGContextAddRect(context, monthRect);
    CGContextSetFillColorWithColor(context, [STColorClass clearColor].CGColor);
    CGContextFillPath(context);
    CGContextSetStrokeColorWithColor(context, [STColorClass redColor].CGColor);
    CGContextStrokePath(context);
    
    for ( int i = 0; i < 8; i++ ) {
        CGFloat columnX = self.dirtyRect.origin.x + ( i * self.dayWidth );
        
        CGFloat endY;
        if ( intercalary && ( i == 0 || i == 1 ) ) {
#ifdef __MAC_OS_X_VERSION_MAX_ALLOWED
            endY = self.dayHeight * 4;
            CGFloat yOrigin = self.dirtyRect.origin.y;
#else
            CGFloat yOrigin = self.calendarBoxOrigin + self.dayHeight;
            endY = self.dayHeight * 6;
#endif
            CGContextMoveToPoint(context, columnX, yOrigin);
        } else if ( i >= 6 ) {
            endY = self.dayHeight * 5;
            CGContextMoveToPoint(context, columnX, self.calendarBoxOrigin);
        } else {
#ifdef __MAC_OS_X_VERSION_MAX_ALLOWED
            endY = self.dayHeight * 4;
            CGFloat yOff = 0;
#else
            endY = self.dayHeight * 5;
            CGFloat yOff = self.dayHeight;
#endif
            CGContextMoveToPoint(context, columnX, self.calendarBoxOrigin + yOff);
        }
        
        CGContextAddLineToPoint(context, columnX, self.calendarBoxOrigin + endY);
        //[[NSString stringWithFormat:@"%d",i] drawAtPoint:CGPointMake(columnX,dirtyRect.origin.y + endY) withAttributes:textAttributes];
    }
    
    // draw common lines to RHS
    for ( int i = 0; i < 6; i++ ) {
        CGFloat rowY = self.calendarBoxOrigin + ( i * self.dayHeight );
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
        CGFloat yOrigin = self.calendarBoxOrigin + self.dayHeight * 6;
#endif
        CGContextMoveToPoint(context, self.dirtyRect.origin.x, yOrigin);
        CGContextAddLineToPoint(context, self.dirtyRect.origin.x + self.dayWidth, yOrigin);
        CGContextStrokePath(context);
    }
}

- (void)drawDayAtPoint:(CGPoint)point lunar:(int)lunar date:(NSDate *)date asToday:(BOOL)asToday foundToday:(BOOL *)foundToday
{
    CGContextRef context = STContext;
    
    CGFloat oneX = point.x;
    CGFloat ldY = point.y;
    
    CGFloat singleDigitDateXOffset = [@"0" sizeWithAttributes:self.textAttributes].width / 2;
    
#ifdef __MAC_OS_X_VERSION_MAX_ALLOWED
    CGFloat ssY = ldY + self.textSize.height + 3;
    CGFloat gdY = ldY + STGregorianDayOffset;
    CGFloat fcY = ssY + self.smallerTextSize.height + 3;
    ldY += self.dayHeight - self.textSize.height;
#else
    CGFloat ssY = ldY + self.dayHeight - self.textSize.height - 3;
    CGFloat gdY = ssY - self.textSize.height;
    CGFloat fcY = gdY - self.smallerTextSize.height - 1;
#endif
    
    NSDate *sunset = [[STState state] lastSunsetForDate:date momentAfter:NO];
    
    if ( asToday ) {
        [self _drawTodayCircleAtPoint:CGPointMake(oneX + self.lineWidth, ldY) withLineWidth:self.lineWidth textAttributes:self.textAttributes context:context];
    }
    oneX += singleDigitDateXOffset;
    [[NSString stringWithFormat:@"%d",lunar] drawAtPoint:CGPointMake(oneX,ldY) withAttributes:self.textAttributes];
    NSString *sunsetHourMinute = [NSString stringWithFormat:@"SS %@",[sunset localHourMinuteString]];
    [sunsetHourMinute drawAtPoint:CGPointMake(oneX, ssY) withAttributes:self.smallerAttributes];

    BOOL waning = NO;
    double fracillum = [[STState state] moonFracillumForDate:date :&waning];
    NSString *fracillumString = [NSString stringWithFormat:@"%0.0f%%%@",fracillum * 100,waning?@" (waning)":@""];
    [fracillumString drawAtPoint:CGPointMake(oneX, fcY) withAttributes:self.smallerAttributes];
    
    // draw attributed gregorian date
    NSString *gregorianString = nil;
    NSAttributedString *attrString = nil;
    // account for lunar day start on dynamic days
    NSDate *gregorianDay = nil;
    if ( lunar > 1 && lunar < 29 )
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
    [attrString drawAtPoint:CGPointMake(oneX,gdY)];
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
