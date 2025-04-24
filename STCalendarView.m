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

#ifdef __MAC_OS_X_VERSION_MAX_ALLOWED
#define STCalendarViewRect NSRect
#define STCalendarViewContext [NSGraphicsContext currentContext].CGContext
#define STCalendarViewColorClass NSColor
#define STCalendarViewFontClass NSFont
#define STCalendarViewLocalGregorianFontSize 8
#else
#define STCalendarViewRect CGRect
#define STCalendarViewContext UIGraphicsGetCurrentContext()
#define STCalendarViewColorClass UIColor
#define STCalendarViewFontClass UIFont
#define STCalendarViewLocalGregorianFontSize 7
#endif

#ifdef __MAC_OS_X_VERSION_MAX_ALLOWED
CGRect gMyInitRect;
#endif

@implementation STCalendarView

- (void)_initMyNowStuff
{    
#define MyNow
#ifdef MyNow
    NSDate *lastConjunction = [[STState state] lastConjunction];
    NSDate *lastNewMoonDay = [STCalendar newMoonDayForConjunction:lastConjunction];
    NSDate *fiveTil = [STCalendar date:lastNewMoonDay byAddingDays:7 hours:23 minutes:59 seconds:55];
    [NSDate setMyNow:fiveTil];
#endif
}

#ifdef __MAC_OS_X_VERSION_MAX_ALLOWED
- (id)initWithFrame:(NSRect)frameRect
{
    if ( self = [super initWithFrame:frameRect] ) {
        gMyInitRect = frameRect;
        if ( CGRectEqualToRect(frameRect, [self frame]) ) {
            NSLog(@"WTF");
            //abort();
            [[NSNotificationCenter defaultCenter] addObserverForName:NSCalendarDayChangedNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull notification) {
                NSLog(@"NSCalendarDayChangedNotification!");
                [self setNeedsDisplay:YES];
            }];
            [[NSNotificationCenter defaultCenter] addObserverForName:NSSystemClockDidChangeNotification object:nil queue:[NSOperationQueue mainQueue]  usingBlock:^(NSNotification * _Nonnull notification) {
                NSLog(@"NSSystemClockDidChangeNotification!");
                [self setNeedsDisplay:YES];
            }];
        }
        
        [self _initMyNowStuff];
    }
    return self;
}
#else
- (id)initWithFrame:(CGRect)frameRect
{
    if ( self = [super initWithFrame:frameRect] ) {
        [[NSNotificationCenter defaultCenter] addObserverForName:NSCalendarDayChangedNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull notification) {
            NSLog(@"NSCalendarDayChangedNotification!");
            [self setNeedsDisplay];
        }];
        [[NSNotificationCenter defaultCenter] addObserverForName:NSSystemClockDidChangeNotification object:nil queue:[NSOperationQueue mainQueue]  usingBlock:^(NSNotification * _Nonnull notification) {
            NSLog(@"NSSystemClockDidChangeNotification!");
            [self setNeedsDisplay];
        }];
        
        [self _initMyNowStuff];
    }
    return self;
}
#endif

- (void)drawRect:(STCalendarViewRect)dirtyRect {
#ifdef __MAC_OS_X_VERSION_MAX_ALLOWED
    [super drawRect:dirtyRect];
    if ( ! CGRectEqualToRect(dirtyRect, gMyInitRect) ) {
        NSLog(@"WTF");
        dirtyRect = CGRectInset(dirtyRect, 50, 50);
    }
#endif
    
    // Drawing code here.
    CGFloat dayWidth = dirtyRect.size.width / 7;
    CGFloat dayHeight = dayWidth;
    
    CGContextRef context = STCalendarViewContext;
    
    CGFloat lineWidth = 1;
    CGContextSetLineWidth(context, lineWidth);
    
    // draw calendar frame
    CGRect monthRect = CGRectMake(dirtyRect.origin.x,dirtyRect.origin.y,dirtyRect.size.width,dirtyRect.size.height);
    CGContextAddRect(context, monthRect);
    CGContextSetFillColorWithColor(context, [STCalendarViewColorClass blackColor].CGColor);
    CGContextFillPath(context);
    CGContextSetStrokeColorWithColor(context, [STCalendarViewColorClass redColor].CGColor);
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
    NSDate *lastConjunction = [[STState state] lastConjunction];
    NSDate *lastNewMoonDay = [STCalendar newMoonDayForConjunction:lastConjunction];
    NSDictionary *textAttributes = @{ NSForegroundColorAttributeName : [STCalendarViewColorClass redColor] };
    NSDictionary *smallAttributes = @{ NSForegroundColorAttributeName : [STCalendarViewColorClass grayColor],
                                       NSFontAttributeName : [STCalendarViewFontClass systemFontOfSize:STCalendarViewLocalGregorianFontSize] };
    CGSize textSize = [@"foo" sizeWithAttributes:textAttributes];
    CGFloat singleDigitDateXOffset = [@"0" sizeWithAttributes:textAttributes].width / 2;
    //CGSize smallSize = [@"foo" sizeWithAttributes:smallAttributes];
    
    // draw lunation #
    NSDate *lastNewYear = [[STState state] lastNewYear];
    NSInteger monthsSinceNewYear = [[STState state] lunarMonthsSinceDate:lastNewYear];
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
        CGFloat gdY = ldY;
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
            
            NSDate *thisDate = [STCalendar date:lastNewMoonDay byAddingDays:day - 1 hours:0 minutes:0 seconds:0];
            if ( [STCalendar isDateInToday:thisDate] ) {
                [self _drawTodayCircleAtPoint:CGPointMake(columnX + columnXOffset, ldY)  withLineWidth:lineWidth textAttributes:textAttributes context:context];
            }
            
            CGFloat yOffset = 0;
#ifndef __MAC_OS_X_VERSION_MAX_ALLOWED
            yOffset = 1;
#endif
            if ( day < 10 )
                columnXOffset += singleDigitDateXOffset;
            [[NSString stringWithFormat:@"%d",day] drawAtPoint:CGPointMake(columnX + columnXOffset + lineWidth,ldY + yOffset) withAttributes:textAttributes];
            NSString *gregorianMonthDay = [STCalendar localGregorianDayOfTheMonthFromDate:thisDate];
            [gregorianMonthDay drawAtPoint:CGPointMake(columnX + columnXOffset,gdY) withAttributes:smallAttributes];
            
            // sabbath
            if ( j == 6 ) {
                NSDate *sunset = [[STState state] sunsetOnDate:[NSDate myNow]];
                NSDate *nextSabbath = [[STState state] nextSabbath];
                NSDate *lastSabbath = [[STState state] lastSabbath];
                NSDate *nextNewMoonStart = [[STState state] nextNewMoonStart];
                NSLog(@"next new moon start: %@",nextNewMoonStart);
                NSDate *lastNewMoonStart = [[STState state] lastNewMoonStart];
                NSLog(@"last new moon start: %@",lastNewMoonStart);
            }
        }
    }
#ifdef __MAC_OS_X_VERSION_MAX_ALLOWED
    CGFloat ldY = dirtyRect.origin.y + ( 4 * dayHeight );
    CGFloat gdY = ldY;
    ldY += dayHeight - textSize.height;
#else
    CGFloat ldY = dirtyRect.origin.y;
    CGFloat gdY = ldY + dayHeight - textSize.height;
#endif
    CGFloat oneX = dirtyRect.origin.x + ( 6 * dayWidth );
    if ( [STCalendar isDateInToday:lastNewMoonDay] ) {
        [self _drawTodayCircleAtPoint:CGPointMake(oneX + lineWidth, ldY) withLineWidth:lineWidth textAttributes:textAttributes context:context];
    }
    oneX += singleDigitDateXOffset;
    [@"1" drawAtPoint:CGPointMake(oneX,ldY) withAttributes:textAttributes];
    NSString *gregorianMonthDay = [STCalendar localGregorianDayOfTheMonthFromDate:lastNewMoonDay];
    [gregorianMonthDay drawAtPoint:CGPointMake(oneX,gdY) withAttributes:smallAttributes];
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
    CGContextSetFillColorWithColor(context, [STCalendarViewColorClass grayColor].CGColor);
    CGContextAddArc(context,dateCenter.x,dateCenter.y,dateSize.width / 2 + lineWidth,0.0,M_PI*2,YES);
    CGContextFillPath(context);
    
    //[@"🌞" drawAtPoint:CGPointMake(columnX + dayWidth / 3,sY) withAttributes:textAttributes];
}

@end
