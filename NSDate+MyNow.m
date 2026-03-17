//
//  NSDate+MyNow.m
//  Sabbatic
//
//  Created by david on 4/23/25.
//

#import "NSDate+MyNow.h"
#import "STCalendar.h"
#import "STState.h"
#import "STDefines.h"

@implementation NSDate (NSDate_MyNow)

+ (void)enqueueRealSunsetNotifications
{
    NSDate *time = [DP nextSunset:YES];
    NSTimeInterval inSecs = [time timeIntervalSinceDate:[NSDate myNow]];
    NSLog(@"enqueueing REAL sunset notification on %@ (%0.1f hours)",time,inSecs/60./60.);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(inSecs * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:NSCalendarDayChangedNotification object:self];
        [self enqueueRealSunsetNotifications];
    });
}

+ (void)_enqueueDayChangedNotesForDate:(NSDate *)date
{
    if ( sNSDateMyNowFast ) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(sNSDateMyNowSecsPerDay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:NSCalendarDayChangedNotification object:self];
            [self _enqueueDayChangedNotesForDate:nil];
        });
    } else {
        [self _enqueueGregorianDayChangedNoteAfter:date];
        [self _enqueueLunarDayChangedNoteForDate:date];
    }
}

+ (void)_enqueueGregorianDayChangedNoteAfter:(NSDate *)date
{
    NSDate *startOfMyNow = [[NSCalendar currentCalendar] startOfDayForDate:date];
    NSDate *startOfMyTomorrow = [STCalendar date:startOfMyNow byAddingDays:1 hours:0 minutes:0 seconds:0];
    NSTimeInterval timeToTomorrow = [startOfMyTomorrow timeIntervalSince1970] - [NSDate myNow].timeIntervalSince1970;
    NSLog(@"enqueueing fake gregorian NSCalendarDayChangedNotification for %@! (in %0.1f seconds)",startOfMyTomorrow,timeToTomorrow);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeToTomorrow * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSLog(@"posting fake gregorian NSCalendarDayChangedNotification...");
        [[NSNotificationCenter defaultCenter] postNotificationName:NSCalendarDayChangedNotification object:self];
        
        [self _enqueueGregorianDayChangedNoteAfter:startOfMyTomorrow];
    });
}

+ (void)_enqueueLunarDayChangedNoteForDate:(NSDate *)date
{
    NSDate *nextSunset = [DP nextSunset:YES];
    NSLog(@"nextSunset for %@ is at %@",date,nextSunset);
    NSTimeInterval timeToNextStart = [nextSunset timeIntervalSince1970] - [NSDate myNow].timeIntervalSince1970;
    if ( timeToNextStart < 0 ) {
        NSLog(@"something is wrong, nextSunset is in the past!");
        abort();
    }
    NSLog(@"enqueueing fake lunar NSCalendarDayChangedNotification for %@! (in %0.1f seconds)",nextSunset,timeToNextStart);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeToNextStart * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSLog(@"posting fake lunar NSCalendarDayChangedNotification...");
        [[NSNotificationCenter defaultCenter] postNotificationName:NSCalendarDayChangedNotification object:self];
        
        [self _enqueueLunarDayChangedNoteForDate:[NSDate myNow]];
    });
}

static NSTimeInterval sNSDateMyNowOffset = 0;
static BOOL sNSDateMyNowFast = NO;
static NSInteger sNSDateMyNowSecsPerDay = 0;
static NSDate *sNSDateMyNowStart = nil;

+ (void)setMyNow:(NSDate *)date realSecondsPerDay:(NSInteger)real
{
    NSDate *realNow = [NSDate date];
    // allow use of 'fast' for unchanged 'now'
    if ( date && ( [date timeIntervalSinceDate:realNow] == 0 ) )
        sNSDateMyNowOffset = .000001;
    else
        sNSDateMyNowOffset = realNow.timeIntervalSince1970 - [date timeIntervalSince1970];
    
    if ( real > 0 ) {
        sNSDateMyNowFast = YES;
        sNSDateMyNowSecsPerDay = real;
        sNSDateMyNowStart = [NSDate date];
    }
    
    NSDate *myNow = [NSDate myNow];
    NSLog(@"MyNow: The time is now %@ (%0.1f seconds in the %@)",myNow,sNSDateMyNowOffset<0?-sNSDateMyNowOffset:sNSDateMyNowOffset,sNSDateMyNowOffset>0?@"past":@"future");
    [self _enqueueDayChangedNotesForDate:date];
}

+ (NSDate *)myNow
{
    if ( sNSDateMyNowOffset ) {
        NSTimeInterval offset = sNSDateMyNowOffset;
        if ( sNSDateMyNowFast ) {
            NSTimeInterval fastInterval = [sNSDateMyNowStart timeIntervalSinceDate:[NSDate date]];
            offset += (int)(fastInterval) * STSecondsPerGregorianDay / sNSDateMyNowSecsPerDay - 0.000001;
        }
        return [NSDate dateWithTimeIntervalSince1970:[[NSDate date] timeIntervalSince1970] - offset];
    }
    return [NSDate date];
}

+ (BOOL)myNowIsNow
{
    return ! sNSDateMyNowOffset;
}

- (BOOL)isWithinAbsoluteTimeInterval:(NSTimeInterval)interval ofDate:(NSDate *)date
{
    NSTimeInterval sinceDate = [self timeIntervalSinceDate:date];
    return ( sinceDate <= interval )
        && ( sinceDate >= -interval );
}

- (NSString *)_string:(NSString *)format withTimeZone:(NSTimeZone *)tz
{
    NSDateFormatter * df = [[NSDateFormatter alloc] init];
    [df setTimeZone:tz];
    [df setDateFormat:format];
    return [df stringFromDate:self];
}

- (NSString *)utcYearMonthDayString
{
    return [self _string:@"y-MM-dd" withTimeZone:[NSTimeZone timeZoneWithName:@"UTC"]];
}

- (NSString *)localYearMonthDayString
{
    return [self _string:@"y-MM-dd" withTimeZone:[NSTimeZone localTimeZone]];
}

- (NSString *)localYearMonthDayHourMinuteString
{
    return [self _string:@"EEE MMM dd HH:mm:ss y" withTimeZone:[NSTimeZone localTimeZone]];
}

- (NSString *)localHourMinuteString
{
    return [self _string:@"HH:mm" withTimeZone:[NSTimeZone localTimeZone]];
}

- (NSString *)localYearString
{
    return [self _string:@"y G" withTimeZone:[NSTimeZone localTimeZone]];
}

- (NSString *)localYearStringThruDate:(NSDate *)date
{
    NSCalendarUnit flags = NSCalendarUnitEra | NSCalendarUnitYear;
    NSDateComponents *comp1 = [[NSCalendar currentCalendar] components:flags fromDate:self];
    NSDateComponents *comp2 = [[NSCalendar currentCalendar] components:flags fromDate:date];
    
    if ( ( [comp1 year] == [comp2 year] ) && ( [comp1 era] == [comp2 era] ) )
        return [self localYearString];
    
    NSString *s1 = nil;
    
    if ( [comp1 era] != [comp2 era] ) {
        s1 = [self _string:@"y G" withTimeZone:[NSTimeZone localTimeZone]];
    } else {
        s1 = [self _string:@"y" withTimeZone:[NSTimeZone localTimeZone]];
    }
    
    NSString *s2 = [date _string:@"y G" withTimeZone:[NSTimeZone localTimeZone]];
    return [NSString stringWithFormat:@"%@-%@",s1,s2];
}

- (NSInteger)absoluteYear
{
    NSCalendarUnit flags = ( NSCalendarUnitEra | NSCalendarUnitYear );
    NSDateComponents *comps = [[NSCalendar currentCalendar] components:flags fromDate:self];
    int year = ( comps.era == 0 ) ? ( -((int)comps.year) + 1 ) : (int)comps.year;
    return year;
}

- (NSString *)notificationPresentationString
{
    NSString *first = [self _string:@"EEEE" withTimeZone:[NSTimeZone localTimeZone]];
    NSString *second = [self _string:@"HH:mm" withTimeZone:[NSTimeZone localTimeZone]];
    return [NSString stringWithFormat:@"%@ at %@",first,second];
}

- (NSDate *)normalizedDate
{
    NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    NSDateComponents *dateComponents = [gregorian components:(NSCalendarUnitEra | NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay) fromDate:self];
    NSDate *normalizedDate = [gregorian dateFromComponents:dateComponents];
#ifdef debugDateStuff
    NSLog(@"%@ normalized to %@",date,normalizedDate);
#endif
    return normalizedDate;
}

- (NSDate *)normalizedDatePlusHour:(NSInteger)hour minute:(NSInteger)minute second:(NSInteger)second
{
    NSDate *normalizedDate = [STCalendar date:[self normalizedDate] byAddingDays:0 hours:hour minutes:minute seconds:second];
#ifdef debugDateStuff
    NSLog(@"%@ normalized to %@",date,normalizedDate);
#endif
    return normalizedDate;
}

- (NSUInteger)daysSinceDate:(NSDate *)date
{
    NSDate *param, *SELF;
    
    NSCalendar *calendar = [NSCalendar currentCalendar];

    [calendar rangeOfUnit:NSCalendarUnitDay startDate:&param
        interval:NULL forDate:date];
    [calendar rangeOfUnit:NSCalendarUnitDay startDate:&SELF
        interval:NULL forDate:self];

    NSDateComponents *difference = [calendar components:NSCalendarUnitDay
        fromDate:param toDate:SELF options:0];

    return [difference day];
}

@end
