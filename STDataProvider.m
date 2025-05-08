//
//  STDataProvider.m
//  Sabbatic
//
//  Created by david on 5/7/25.
//

#import "STDataProvider.h"
#import "NSDate+MyNow.h"
#import "STCalendar.h"
#import "STDefines.h"

NS_ASSUME_NONNULL_BEGIN

@implementation STDataProvider

// usno only exposes fracillum for noon (or midnight, though seemingly not via api) on a particular day
- (double)syntheticMoonPhaseCurve:(double)zeroThruOne {
    if ( zeroThruOne < 0 || zeroThruOne > 1 ) {
        NSLog(@"uh-oh!");
        abort();
    }
    double pi = 3.14159;
    double centered = 2 * pi * zeroThruOne - pi;
    double y = sin(centered + ( pi / 2 ) ) + 1;
    double synthetic = y / 2;
    NSLog(@"%0.2f: sin(%0.2f + ( %0.2f / 2 )) => %0.2f",zeroThruOne,centered,pi,synthetic);
    return synthetic;
}

- (double)currentMoonFracillum:(BOOL *)waning
{
    NSDate *now = [NSDate myNow];
    NSDate *last = [self lastConjunction];
    NSTimeInterval timeSinceLast = [now timeIntervalSinceDate:last];
    if ( timeSinceLast < 0 ) {
        NSLog(@"uh-oh!");
        abort();
    }
    double monthCompleted = timeSinceLast / STSecondsPerLunarDay;
    
    double usno = [self moonFracillumForDate:now :waning];
    double synthetic = [self syntheticMoonPhaseCurve:monthCompleted];
    NSLog(@"%0.2f vs %0.2f",synthetic,usno);
    
    return synthetic;
}

- (NSDate *)lastConjunction
{
    return [self conjunctionPriorToDate:[NSDate myNow]];
}

- (NSDate *)lastNewYear
{
    return [self lastNewYearForDate:[NSDate myNow]];
}


#warning this does NOT work!
- (NSDate *)nextSabbath:(BOOL)momentAfter
{
    NSDate *lastNewMoon = [self lastNewMoonDay];
    NSDate *now = [NSDate myNow];
    NSDate *next = nil;
    int i = 1;
    for( ; i < 5; i++ ) {
        NSInteger days = i * 7;
        NSDate *aSabbath = [STCalendar date:lastNewMoon byAddingDays:days hours:0 minutes:0 seconds:0];
        if ( [now timeIntervalSinceDate:aSabbath] <= 0 ) {
            next = aSabbath;
            break;
        }
    }
    
    if ( ! next ) {
        next = [self nextNewMoonDay];
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            NSLog(@"WARNING: the next sabbath from %@ is the next new moon %@!",now,next);
        });
    } else {
        next = [self lastSunsetForDate:next momentAfter:momentAfter];
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            NSLog(@"The next sabbath from %@ is the %dth, %@",now,i,next);
        });
    }
    
    return next;
}

- (NSDate *)lastSunset:(BOOL)momentAfter
{
    NSDate *origDate = [NSDate myNow];
    NSDate *date = origDate;
    NSDate *sunsetDate = nil;
    date = [STCalendar date:date byAddingDays:1 hours:0 minutes:0 seconds:0];
    while ( ( sunsetDate = [self lastSunsetForDate:date momentAfter:momentAfter] ) ) {
        if ( [origDate timeIntervalSinceDate:sunsetDate] >= 0 ) {
            if ( momentAfter )
                sunsetDate = [sunsetDate dateByAddingTimeInterval:STMomentAfterInterval];
            return sunsetDate;
        }
        date = [STCalendar date:date byAddingDays:-1 hours:0 minutes:0 seconds:0];
    }
    
    return nil;
}

- (NSDate *)nextSunset:(BOOL)momentAfter
{
    NSDate *origDate = [NSDate myNow];
    NSDate *date = origDate;
    NSDate *sunsetDate = nil;
    while ( ( sunsetDate = [self lastSunsetForDate:date momentAfter:momentAfter] ) ) {
        if ( [origDate timeIntervalSinceDate:sunsetDate] < 0 ) {
            if ( momentAfter )
                sunsetDate = [sunsetDate dateByAddingTimeInterval:STMomentAfterInterval];
            return sunsetDate;
        }
        date = [STCalendar date:date byAddingDays:1 hours:0 minutes:0 seconds:0];
    }
    
    return nil;
}

- (NSDate *)lastSunsetForDate:(NSDate *)date momentAfter:(BOOL)momentAfter
{
    NSDate *origDate = date;
    NSDate *sunsetDate = nil;
    date = [STCalendar date:date byAddingDays:1 hours:0 minutes:0 seconds:0];
    while ( ( sunsetDate = [self _fetchSunsetTimeOnDate:date] ) ) {
        if ( [origDate timeIntervalSinceDate:sunsetDate] >= 0 ) {
            if ( momentAfter )
                sunsetDate = [sunsetDate dateByAddingTimeInterval:STMomentAfterInterval];
            return sunsetDate;
        }
        date = [STCalendar date:date byAddingDays:-1 hours:0 minutes:0 seconds:0];
    }
    
    return nil;
}

- (NSDate *)nextSunsetForDate:(NSDate *)date momentAfter:(BOOL)momentAfter
{
    NSDate *origDate = date;
    NSDate *sunsetDate = nil;
    date = [STCalendar date:date byAddingDays:-1 hours:0 minutes:0 seconds:0];
    while ( ( sunsetDate = [self _fetchSunsetTimeOnDate:date] ) ) {
        if ( [origDate timeIntervalSinceDate:sunsetDate] < 0 ) {
            if ( momentAfter )
                sunsetDate = [sunsetDate dateByAddingTimeInterval:STMomentAfterInterval];
            return sunsetDate;
        }
        date = [STCalendar date:date byAddingDays:1 hours:0 minutes:0 seconds:0];
    }
    
    return nil;
}

- (NSDate *)lastNewMoonDay
{
    NSDate *last = [self lastConjunction];
    NSDate *day = [[STCalendar newMoonDayForConjunction:last :NULL] normalizedDate];
    return day;
}

- (NSDate *)nextNewMoonDay
{
    NSDate *next = [self nextConjunction];
    return [[STCalendar newMoonDayForConjunction:next :NULL] normalizedDate];
}

#warning presumably this doesn't either \
    "The next sabbath from Fri May  2 07:01:08 2025 is the 1th, Wed May  7 00:00:00 2025" \
    untested changes to match those to -nextSabbath
- (NSDate *)lastSabbath:(BOOL)momentAfter
{
    NSDate *lastNewMoon = [self lastNewMoonDay];
    NSDate *now = [NSDate myNow];
    NSDate *last = nil;
    int i = 4;
    for( ; i > 0; i-- ) {
        NSInteger days = i * 7;
        NSDate *aSabbath = [STCalendar date:lastNewMoon byAddingDays:days hours:0 minutes:0 seconds:0];
        if ( [now timeIntervalSinceDate:aSabbath] > 0 ) {
            last = aSabbath;
            break;
        }
    }
    
    if ( ! last ) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            NSLog(@"WARNING: the last sabbath from %@ is the last new moon %@!",now,lastNewMoon);
        });
        last = lastNewMoon;
    } else {
        last = [self lastSunsetForDate:last momentAfter:momentAfter];
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            NSLog(@"The last sabbath from %@ is the %dth, %@, based on last new moon %@",now,i,last,lastNewMoon);
        });
    }
    
    return last;
}

- (NSInteger)currentLunarMonth
{
    return [self lunarMonthForDate:[NSDate myNow]];
}

- (NSDate *)lastNewMoonStart
{
    NSDate *now = [NSDate myNow];
    NSDate *last = [self lastConjunction];
    NSDate *next = [self nextConjunction];
    if ( [next timeIntervalSinceDate:now] > STSecondsPerLunarDay )
        last = [self conjunctionPriorToDate:last];
    NSDate *day = [STCalendar newMoonDayForConjunction:last :NULL];
    NSDate *sunsetPreviousDay = [self lastSunsetForDate:day momentAfter:YES];
    
    // called after conjunction but before new moon start
    if ( [now timeIntervalSinceDate:sunsetPreviousDay] < 0 ) {
        NSDate *lastLast = [self conjunctionPriorToDate:last];
        NSDate *lastLastDay = [STCalendar newMoonDayForConjunction:lastLast :NULL];
        sunsetPreviousDay = [self lastSunsetForDate:lastLastDay momentAfter:YES];
    }
    
    return sunsetPreviousDay;
}

- (NSDate *)nextNewMoonStart
{
    NSDate *next = [self nextConjunction];
    NSDate *day = [STCalendar newMoonDayForConjunction:next :NULL];
    NSLog(@"next conjunction for determining nextNewMoonStart: %@, gregorian midnight: %@",next,day);
    NSDate *start = [STCalendar date:day byAddingDays:-1 hours:0 minutes:0 seconds:0];
    NSDate *sunsetPreviousDay = [self _fetchSunsetTimeOnDate:start];
    if ( [[NSDate myNow] timeIntervalSinceDate:sunsetPreviousDay] > 0 ) {
        NSLog(@"uh-oh! newNewMoonStart is in the future!");
        abort();
    }
    return sunsetPreviousDay;
}

- (NSDate *)conjunctionAfterDate:(NSDate *)date {
    NSLog(@"STDataProvider does not provide shared implementation for %s!",__FUNCTION__);
    abort();
}


- (NSDate *)conjunctionPriorToDate:(NSDate *)date {
    NSLog(@"STDataProvider does not provide shared implementation for %s!",__FUNCTION__);
    abort();
}


- (NSDate *)lastNewYearForDate:(NSDate *)date {
    NSLog(@"STDataProvider does not provide shared implementation for %s!",__FUNCTION__);
    abort();
}


- (NSInteger)lunarMonthForDate:(NSDate *)date {
    NSLog(@"STDataProvider does not provide shared implementation for %s!",__FUNCTION__);
    abort();
}


- (double)moonFracillumForDate:(NSDate *)date :(BOOL *)waning {
    NSLog(@"STDataProvider does not provide shared implementation for %s!",__FUNCTION__);
    abort();
}


- (NSDate *)nextConjunction {
    NSLog(@"STDataProvider does not provide shared implementation for %s!",__FUNCTION__);
    abort();
}

- (NSDate *)_fetchSunsetTimeOnDate:(NSDate *)date {
    NSLog(@"STDataProvider does not provide shared implementation for %s!",__FUNCTION__);
    abort();
}


@end

NS_ASSUME_NONNULL_END
