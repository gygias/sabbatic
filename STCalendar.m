//
//  STCalendar.m
//  Sabbatic
//
//  Created by david on 3/20/25.
//

#import "STCalendar.h"
#import "STState.h"
#import "NSDate+MyNow.h"

@implementation STCalendar

// as a convention, we take the second after sunset to be the first belonging to the new day
+ (BOOL)isDateInLunarToday:(NSDate *)date
{
    NSDate *lastSunset = [DP lastSunset:YES];
    NSDate *nextSunset = [DP nextSunset:NO];
    
    BOOL lunarToday = ( [date timeIntervalSinceDate:lastSunset] >= 0 )
        && ( [date timeIntervalSinceDate:nextSunset] <= 0 );
    
    if ( lunarToday )
        NSLog(@"LUNAR TODAY is %@ < <%@> < %@",lastSunset,date,nextSunset);
    
    return lunarToday;
}

+ (BOOL)isDateInLunarYesterday:(NSDate *)date
{
    NSDate *lastSunset = [DP lastSunset:NO];
    NSDate *lunarDayBeforeYesterday = [STCalendar date:lastSunset byAddingDays:-1 hours:-1 minutes:0 seconds:0];
    NSDate *lastLastSunset = [DP lastSunsetForDate:lunarDayBeforeYesterday momentAfter:YES];
    
    return ( [date timeIntervalSinceDate:lastLastSunset] >= 0 )
            && ( [date timeIntervalSinceDate:lastSunset] <= 0 );
    
}

+ (BOOL)isDateInGregorianToday:(NSDate *)date
{
    if ( [NSDate myNowIsNow] )
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
    NSDate *lastSunset = [DP lastSunset:YES];
    NSDate *approxNextSunset = [STCalendar date:lastSunset byAddingDays:1 hours:0 minutes:0 seconds:0];
    NSDate *midnightAfterLastSunset = [approxNextSunset normalizedDate];
        
    return ( [date timeIntervalSinceDate:lastSunset] >= 0 )
            && ( [date timeIntervalSinceDate:midnightAfterLastSunset] < 0 );
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
    
    return [[self date:date byAddingDays:days hours:0 minutes:0 seconds:0] normalizedDate];
}

+ (NSDate *)newMoonStartTimeForConjunction:(NSDate *)date
{
    NSDate *newMoonDay = [self newMoonDayForConjunction:date];
    //NSDate *previousDay = [STCalendar date:newMoonDay byAddingDays:-1 hours:0 minutes:0 seconds:0];
    return [DP lastSunsetForDate:newMoonDay momentAfter:YES];
}

+ (NSDate *)lastNewMoonForDate:(NSDate *)date
{
    NSDate *lastConjunction = [DP conjunctionPriorToDate:date];
    return [STCalendar newMoonStartTimeForConjunction:lastConjunction];
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
    NSString * dateString = [[self _formatter:@"EE d MMM"] stringFromDate:date];
    return dateString;
}

+ (NSString *)localGregorianPreviousAndCurrentDayFromDate:(NSDate *)date delimiter:(NSString *)delimiter
{
    NSDate *previousDay = [STCalendar date:date byAddingDays:-1 hours:0 minutes:0 seconds:0];
    NSString *previousString = [[self _formatter:@"d"] stringFromDate:previousDay];
    NSString *thisString = [self localGregorianDayOfTheMonthFromDate:date];
    NSString *compositeString = [NSString stringWithFormat:@"%@%@%@",previousString,delimiter,thisString];
    return compositeString;
}

+ (NSString *)hebrewStringMonthForMonth:(NSInteger)month
{
    NSString *base = nil;
    switch (month) {
        case 0:
            base = @"Abib";
            break;
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
        case 12:
            base = [NSString stringWithFormat:@"Month %ld",month + 1];
            break;
        default:
            base = @"Unknown";
    }
    
    return base;
}

#define PentecostTemplate "Pentecost %d"

+ (NSString *)moedStringForLunarDay:(NSInteger)day ofLunarMonth:(NSInteger)month
{
    if ( month == 0 ) {
        if ( day == 0 ) {
            return @"New Year";
        } else if ( day == 12 ) {
            return @"Lord's Supper";
        } else if ( day == 13 ) {
            return @"Passover";
        } else if ( day >= 14 && day <= 20 ) {
            return [NSString stringWithFormat:@"Unl'd Bread %ld",day - 13];
        } else if ( day == 21 ) {
            return [NSString stringWithFormat:@PentecostTemplate,1];
        } else if ( day == 28 ) {
            return [NSString stringWithFormat:@PentecostTemplate,2];
        }
    } else if ( month == 1 ) {
        if ( day && ( day % 7 == 0 ) )
            return [NSString stringWithFormat:@PentecostTemplate,(int)day / 7 + 2];
    } else if ( month == 2 ) {
        if ( day == 7 )
            return [NSString stringWithFormat:@PentecostTemplate,7];
        else if ( day == 8 )
            return [NSString stringWithFormat:@"50d to P'cost"];
//#define ShowPentecostWeeks
#ifdef ShowPentecostWeeks
        else if ( day == 16 )
            return [NSString stringWithFormat:@"43d to P'cost"];
        else if ( day == 23 )
            return [NSString stringWithFormat:@"36d to P'cost"];
#endif
    } else if ( month == 3 ) {
        if ( day == 0 )
            return [NSString stringWithFormat:@"29d to P'cost"];
        if ( day == 7 )
            return [NSString stringWithFormat:@"22d to P'cost"];
        if ( day == 14 )
            return [NSString stringWithFormat:@"15d to P'cost"];
        if ( day == 21 )
            return [NSString stringWithFormat:@"8d to P'cost"];
        if ( day == 28 )
            return [NSString stringWithFormat:@"1d to P'cost"];
    } else if ( month == 4 ) {
        if ( day == 0 )
            return @"Pentecost";
    } else if ( month == 6 ) {
        if ( day == 0 )
            return @"Trumpets";
        else if ( day == 9 )
            return @"Atonement";
        else if ( day >= 14 && day <= 20 ) {
            return @"Tabernacles";
        }
    }
    
    return nil;
}

+ (TypeOfDay)typeOfDayForDayOfMonth:(NSInteger)dom
{
    TypeOfDay type = 0;
    
    // NOTE
    dom++;
    
    if ( dom == 1 )
        type |= NewMoonDay;
    else if ( dom == 8 || dom == 15 || dom == 22 || dom == 29 )
        type |= SabbathDay;
    else
        type |= WorkDay;
    
    if ( dom == 7 || dom == 14 || dom == 21 || dom == 28 )
        type |= PreparationDay;
    else if ( dom == 9 || dom == 16 || dom == 23 )
        type |= StartOfWeek;
    else if ( dom == 30 )
        type |= IntercalaryDay;
    
    return type;
}

@end
