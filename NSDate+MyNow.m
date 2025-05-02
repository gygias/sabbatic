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
    NSDate *time = [[STState state] nextSunset:YES];
    NSTimeInterval inSecs = [time timeIntervalSinceDate:[NSDate myNow]];
    NSLog(@"enqueueing REAL sunset notification on %@ (%0.1f hours)",time,inSecs/60./60.);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(inSecs * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:NSCalendarDayChangedNotification object:self];
        [self enqueueRealSunsetNotifications];
    });
}

+ (void)_enqueueDayChangedNotesForDayAfter:(NSDate *)date
{
    if ( sNSDateMyNowFast ) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(sNSDateMyNowSecsPerDay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:NSCalendarDayChangedNotification object:self];
            [self _enqueueDayChangedNotesForDayAfter:nil];
        });
    } else {
        [self _enqueueGregorianDayChangedNoteAfter:date];
        [self _enqueueLunarDayChangedNoteForDayAfter:date];
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
        
        [self _enqueueGregorianDayChangedNoteAfter:[[NSDate myNow] dateByAddingTimeInterval:60]];
    });
}

+ (void)_enqueueLunarDayChangedNoteForDayAfter:(NSDate *)date
{
    NSDate *nextSunset = [[STState state] nextSunset:YES];
    NSTimeInterval timeToNextStart = [nextSunset timeIntervalSince1970] - [NSDate myNow].timeIntervalSince1970;
    if ( timeToNextStart < 0 ) {
        NSLog(@"something is wrong, nextNewMoonStart is in the past!");
        return;
    }
    NSLog(@"enqueueing fake lunar NSCalendarDayChangedNotification for %@! (in %0.1f seconds)",nextSunset,timeToNextStart);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeToNextStart * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSLog(@"posting fake lunar NSCalendarDayChangedNotification...");
        [[NSNotificationCenter defaultCenter] postNotificationName:NSCalendarDayChangedNotification object:self];
        
        [self _enqueueLunarDayChangedNoteForDayAfter:[[NSDate myNow] dateByAddingTimeInterval:60]];
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
    NSLog(@"MyNow: The time is now %@ (%0.1f seconds in the %@)",myNow,sNSDateMyNowOffset,sNSDateMyNowOffset>0?@"past":@"future");
    [self _enqueueDayChangedNotesForDayAfter:date];
}

+ (NSDate *)myNow
{
    if ( sNSDateMyNowOffset ) {
        NSTimeInterval offset = sNSDateMyNowOffset;
        if ( sNSDateMyNowFast ) {
            NSTimeInterval fastInterval = [sNSDateMyNowStart timeIntervalSinceDate:[NSDate date]];
            offset += (int)(fastInterval) * STSecondsPerGregorianDay / sNSDateMyNowSecsPerDay;
        }
        return [NSDate dateWithTimeIntervalSince1970:[[NSDate date] timeIntervalSince1970] - offset];
    }
    return [NSDate date];
}

- (BOOL)isWithinAbsoluteTimeInterval:(NSTimeInterval)interval ofDate:(NSDate *)date
{
    NSTimeInterval sinceDate = [self timeIntervalSinceDate:date];
    return ( sinceDate <= interval )
        && ( sinceDate >= -interval );
}

- (NSString *)_localString:(NSString *)format
{
    NSDateFormatter * df = [[NSDateFormatter alloc] init];
    NSTimeZone *tz = [NSTimeZone localTimeZone];
    [df setTimeZone:tz];
    [df setDateFormat:format];
    return [df stringFromDate:self];
}

- (NSString *)localYearMonthDayString
{
    return [self _localString:@"yyyy-MM-dd"];
}

- (NSString *)localYearMonthDayHourMinuteString
{
    return [self _localString:@"EEE MMM dd HH:mm:ss yyyy"];
}

- (NSString *)localHourMinuteString
{
    return [self _localString:@"HH:mm"];
}

@end

@implementation STCalendar

// as a convention, we take the second after sunset to be the first belonging to the new day
+ (BOOL)isDateInLunarToday:(NSDate *)date
{
    NSDate *lastSunset = [[STState state] lastSunset:YES];
    NSDate *nextSunset = [[STState state] nextSunset:NO];
    
    BOOL lunarToday = ( [date timeIntervalSinceDate:lastSunset] >= 0 )
        && ( [date timeIntervalSinceDate:nextSunset] <= 0 );
    
    if ( lunarToday )
        NSLog(@"LUNAR TODAY is %@ < <%@> < %@",lastSunset,date,nextSunset);
    
    return lunarToday;
}

+ (BOOL)isDateInLunarYesterday:(NSDate *)date
{
    NSDate *lastSunset = [[STState state] lastSunset:NO];
    NSDate *lunarDayBeforeYesterday = [STCalendar date:lastSunset byAddingDays:-1 hours:-1 minutes:0 seconds:0];
    NSDate *lastLastSunset = [[STState state] lastSunsetForDate:lunarDayBeforeYesterday momentAfter:YES];
    
    return ( [date timeIntervalSinceDate:lastLastSunset] >= 0 )
            && ( [date timeIntervalSinceDate:lastSunset] <= 0 );
    
}

+ (BOOL)isDateInGregorianToday:(NSDate *)date
{
    if ( ! sNSDateMyNowOffset )
        return [[NSCalendar currentCalendar] isDateInToday:date];
    
    NSDate *startTime = [[NSCalendar currentCalendar] startOfDayForDate:[NSDate myNow]];
    NSDate *nextDay = [STCalendar date:startTime byAddingDays:1 hours:0 minutes:0 seconds:0];
    if ( [startTime timeIntervalSince1970] <= [date timeIntervalSince1970]
        && [nextDay timeIntervalSince1970] > [date timeIntervalSince1970] )
        return YES;
    return NO;
}

+ (BOOL)isDateBetweenSunsetAndGregorianMidnight:(NSDate *)date
{
    NSDate *lastSunset = [[STState state] lastSunset:YES];
    NSDate *approxNextSunset = [STCalendar date:lastSunset byAddingDays:1 hours:0 minutes:0 seconds:0];
    NSDate *midnightAfterLastSunset = [[STState state] normalizeDate:approxNextSunset];
        
    return ( [date timeIntervalSinceDate:lastSunset] >= 0 )
            && ( [date timeIntervalSinceDate:midnightAfterLastSunset] < 0 );
}

+ (NSDate *)newMoonDayForConjunction:(NSDate *)date :(BOOL *)intercalary
{
    // motnc 2025-6 calendar suggests matthew puts new moon day off a day
    // if the conjunction happens around 4pm or later (3:54pm the latest conjunction with
    // new moon observed the following day, sept 21 2025)
    //
    
    // add a day
    // https://stackoverflow.com/questions/5067785/how-do-i-add-1-day-to-an-nsdate
    NSCalendar *theCalendar = [NSCalendar currentCalendar];
    
    // perhaps this should be made customizable
    // https://stackoverflow.com/questions/20492435/nsdate-past-4pm
    unsigned int flags = NSCalendarUnitHour;
    NSInteger days = 1;
    NSDateComponents *comps = [theCalendar components:flags fromDate:date];
    if ( comps.hour >= 16 ) {
        days = 2;
        if ( intercalary )
            *intercalary = YES;
    } else {
        if ( intercalary )
            *intercalary = NO;
    }

    return [[STState state] normalizeDate:[self date:date byAddingDays:days hours:0 minutes:0 seconds:0]];
}

+ (NSDate *)newMoonStartTimeForConjunction:(NSDate *)date :(BOOL *)intercalary
{
    NSDate *newMoonDay = [self newMoonDayForConjunction:date :intercalary];
    NSDate *previousDay = [STCalendar date:newMoonDay byAddingDays:-1 hours:0 minutes:0 seconds:0];
    return [[STState state] lastSunsetForDate:previousDay momentAfter:YES];
}

+ (NSDate *)date:(NSDate *)date byAddingDays:(NSInteger)days hours:(NSInteger)hours minutes:(NSInteger)minutes seconds:(NSInteger)seconds
{
    NSCalendar *theCalendar = [NSCalendar currentCalendar];
    NSDateComponents *dayComponent = [[NSDateComponents alloc] init];
    dayComponent.day = days;
    dayComponent.hour = hours;
    dayComponent.minute = minutes;
    dayComponent.second = seconds;
    NSDate *nextDate = [theCalendar dateByAddingComponents:dayComponent toDate:date options:0];
    return nextDate;
}

+ (NSDateFormatter *)_formatter:(NSString *)format
{
    NSString * deviceLanguage = [[NSLocale preferredLanguages] objectAtIndex:0];
    NSDateFormatter * dateFormatter = [NSDateFormatter new];
    NSLocale * locale = [[NSLocale alloc] initWithLocaleIdentifier:deviceLanguage];

    [dateFormatter setDateFormat:format];
    [dateFormatter setLocale:locale];
    return dateFormatter;
}

+ (NSString *)localGregorianDayOfTheMonthFromDate:(NSDate *)date
{
    NSString * dateString = [[self _formatter:@"EE dd MMM"] stringFromDate:date];
    return dateString;
}

+ (NSString *)localGregorianPreviousAndCurrentDayFromDate:(NSDate *)date delimiter:(NSString *)delimiter
{
    NSDate *previousDay = [STCalendar date:date byAddingDays:-1 hours:0 minutes:0 seconds:0];
    NSString *previousString = [[self _formatter:@"dd"] stringFromDate:previousDay];
    NSString *thisString = [self localGregorianDayOfTheMonthFromDate:date];
    NSString *compositeString = [NSString stringWithFormat:@"%@%@%@",previousString,delimiter,thisString];
    return compositeString;
}

+ (NSString *)hebrewMonthForMonth:(NSInteger)month
{
    switch (month) {
        case 0:
            return @"Abib";
        case 1:
        case 2:
        case 3:
        case 4:
        case 5:
        case 6:
        case 7:
        case 8:
        case 9:
        case 10:
        case 11:
#warning intercalary?
        case 12:
            return [NSString stringWithFormat:@"Month %ld",month + 1];
        default:
            return @"Unknown";
    }
    
    return @"Unknown";
}

@end
