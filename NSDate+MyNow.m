//
//  NSDate+MyNow.m
//  Sabbatic
//
//  Created by david on 4/23/25.
//

#import "NSDate+MyNow.h"
#import "STCalendar.h"
#import "STState.h"

@implementation NSDate (NSDate_MyNow)

static NSTimeInterval sNSDateMyNowOffset = 0;

+ (void)_enqueueDayChangedNoteForDayAfter:(NSDate *)date
{
#ifdef gregorian_note
    NSDate *startOfMyNow = [[NSCalendar currentCalendar] startOfDayForDate:date];
    NSDate *startOfMyTomorrow = [STCalendar date:startOfMyNow byAddingDays:1 hours:0 minutes:0 seconds:0];
    NSTimeInterval timeToTomorrow = [startOfMyTomorrow timeIntervalSince1970] - [NSDate myNow].timeIntervalSince1970;
    NSLog(@"enqueueing NSCalendarDayChangedNotification for %@! (in %0.1f seconds)",startOfMyTomorrow,timeToTomorrow);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeToTomorrow * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSLog(@"posting fake NSCalendarDayChangedNotification...");
        [[NSNotificationCenter defaultCenter] postNotificationName:NSCalendarDayChangedNotification object:self];
        
        [self _enqueueDayChangedNoteForDayAfter:[[NSDate myNow] dateByAddingTimeInterval:60]];
    });
#endif
    NSDate *nextSunset = [[STState state] nextSunset];
    NSDate *nextStart = [[STState state] nextNewMoonStart];
    NSLog(@"[[%@ vs %@]]",nextSunset,nextStart);
    NSTimeInterval timeToNextStart = [nextStart timeIntervalSince1970] - [NSDate myNow].timeIntervalSince1970;
    if ( timeToNextStart < 0 ) {
        NSLog(@"something is wrong, nextNewMoonStart is in the past!");
        return;
    }
    NSLog(@"enqueueing NSCalendarDayChangedNotification for %@! (in %0.1f seconds)",nextSunset,timeToNextStart);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeToNextStart * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSLog(@"posting fake NSCalendarDayChangedNotification...");
        [[NSNotificationCenter defaultCenter] postNotificationName:NSCalendarDayChangedNotification object:self];
        
        [self _enqueueDayChangedNoteForDayAfter:[[NSDate myNow] dateByAddingTimeInterval:60]];
    });
}

+ (void)setMyNow:(NSDate *)date
{
    sNSDateMyNowOffset = [NSDate date].timeIntervalSince1970 - [date timeIntervalSince1970];
    NSLog(@"MYNOW: The time is now %@ (%0.1f seconds in the %@)",[NSDate myNow],sNSDateMyNowOffset,sNSDateMyNowOffset>0?@"past":@"future");
    [self _enqueueDayChangedNoteForDayAfter:date];
}

+ (NSDate *)myNow
{
    if ( sNSDateMyNowOffset )
        return [NSDate dateWithTimeIntervalSince1970:[[NSDate date] timeIntervalSince1970] - sNSDateMyNowOffset];
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
    NSLog(@"local time zone: %@",tz);
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

@end

@implementation STCalendar

+ (BOOL)isDateInLunarToday:(NSDate *)date
{
    NSDate *lastSunset = [[STState state] lastSunset];
    NSDate *nextSunset = [[STState state] nextSunset];
    
    return ( [date timeIntervalSinceDate:lastSunset] >= 0 )
            && ( [date timeIntervalSinceDate:nextSunset] <= 0 );
}

+ (BOOL)isDateInToday:(NSDate *)date
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

+ (NSDate *)newMoonDayForConjunction:(NSDate *)date
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
    if ( comps.hour >= 16 )
        days = 2;

    return [[STState state] normalizeDate:[self date:date byAddingDays:days hours:0 minutes:0 seconds:0]];
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

+ (NSString *)localGregorianDayOfTheMonthFromDate:(NSDate *)date
{
    NSString * deviceLanguage = [[NSLocale preferredLanguages] objectAtIndex:0];
    NSDateFormatter * dateFormatter = [NSDateFormatter new];
    NSLocale * locale = [[NSLocale alloc] initWithLocaleIdentifier:deviceLanguage];

    [dateFormatter setDateFormat:@"EE dd MMM"];
    [dateFormatter setLocale:locale];

    NSString * dateString = [dateFormatter stringFromDate:date];

    //NSLog(@"%@", dateString);
    
    return dateString;
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
