//
//  STAstronomyProvider.m
//  Sabbatic
//
//  Created by david on 5/7/25.
//

#import "STAstronomyProvider.h"

#import "astronomy.h"

#import "STState.h"
#import "NSDate+MyNow.h"
#import "STDefines.h"
#import "STCalendar.h"

NS_ASSUME_NONNULL_BEGIN

@implementation NSDate (Astronomy)

- (astro_time_t)astroTime
{
    NSCalendarUnit flags = ( NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay
                            | NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond );
    NSDateComponents *comps = [[NSCalendar currentCalendar] components:flags fromDate:self];
    
    astro_utc_t utc = { (int)comps.year, (int)comps.month, (int)comps.day, (int)comps.hour, (int)comps.minute, comps.second };

    return Astronomy_TimeFromUtc(utc);
}

+ (NSDate *)dateWithAstroTime:(astro_time_t)astroTime
{
    astro_utc_t astroUtc = Astronomy_UtcFromTime(astroTime);
    NSDate *date = [[NSCalendar currentCalendar] dateWithEra:1 year:astroUtc.year month:astroUtc.month day:astroUtc.day hour:astroUtc.hour minute:astroUtc.minute second:astroUtc.second nanosecond:0];
    return [date dateByAddingTimeInterval:[[NSTimeZone localTimeZone] secondsFromGMTForDate:date]];
}

@end

@implementation STAstronomyProvider

- (double)moonFracillumForDate:(NSDate *)date :(BOOL *)waning
{
    astro_illum_t illum;
    
    illum = Astronomy_Illumination(BODY_MOON, [date astroTime]);
    if (illum.status != ASTRO_SUCCESS) {
        NSLog(@"Astronomy_Illumination error %d", illum.status);
        abort();
    }
    
    return illum.phase_fraction;
}

- (NSDate *)_fetchSunsetTimeOnDate:(NSDate *)date
{
    astro_observer_t observer;
    observer.height = 0;
    observer.latitude = [ST effectiveLocation].coordinate.latitude;
    observer.longitude = [ST effectiveLocation].coordinate.longitude;
    
    astro_search_result_t sunset;

    sunset   = Astronomy_SearchRiseSet(BODY_SUN,  observer, DIRECTION_SET,  [date astroTime], 300.0);
    if ( sunset.status != ASTRO_SUCCESS ) {
        NSLog(@"Astronomy_SearchRiseSet error %d",sunset.status);
        abort();
    }
    
    NSDate *aDate = [NSDate dateWithAstroTime:sunset.time];
    return aDate;
}

- (NSDate *)conjunctionPriorToDate:(NSDate *)date
{
#warning fix this
    NSDate *lunarMonthAgo = [date dateByAddingTimeInterval:-STSecondsPerLunarDay];
    return [self conjunctionAfterDate:lunarMonthAgo];
}

- (NSDate *)conjunctionAfterDate:(NSDate *)date
{
    astro_moon_quarter_t mq = {0};
    
    for ( int i = 0; i < 4; i++ ) {
        if ( i == 0 )
            mq = Astronomy_SearchMoonQuarter([date astroTime]);
        else
            mq = Astronomy_NextMoonQuarter(mq);
        
        if ( mq.quarter == 0 ) {
            return [NSDate dateWithAstroTime:mq.time];
        }
    }
    
    NSLog(@"couldn't find conjunction after %@!",date);
    abort();
    return nil;
}

- (NSDate *)nextConjunction
{
    return [self conjunctionAfterDate:[NSDate myNow]];
}

- (NSDate *)_lastSpringEquinoxForDate:(NSDate *)date
{
    int searchYear = [[date localYearString] intValue];
    
    for ( int i = 0; i > -2; i-- ) {
        astro_seasons_t seasons = Astronomy_Seasons(searchYear + i);
        
        if (seasons.status != ASTRO_SUCCESS) {
            NSLog(@"ERROR: Astronomy_Seasons() returned %d\n", seasons.status);
            abort();
        }
        
        NSDate *equinox = [NSDate dateWithAstroTime:seasons.mar_equinox];
        if ( [date timeIntervalSinceDate:equinox] >= 0 ) {
            return equinox;
        }
    }
    
    NSLog(@"couldn't find last new year for %@!",date);
    abort();
    return nil;
}

- (NSDate *)lastNewYearForDate:(NSDate *)date
{
    for ( int i = 0 ; i > -2; i-- ) {
        NSDate *lastEquinox = [self _lastSpringEquinoxForDate:date];
        NSDate *aPriorConjunction = [self conjunctionPriorToDate:lastEquinox];
        NSDate *aNextConjunction = [self conjunctionAfterDate:lastEquinox];
        NSTimeInterval priorToEquinox = [lastEquinox timeIntervalSinceDate:aPriorConjunction];
        NSTimeInterval equinoxToNext = [aNextConjunction timeIntervalSinceDate:lastEquinox];
        if ( priorToEquinox < 0 || equinoxToNext < 0 ) {
            NSLog(@"something is wrong");
            abort();
        }
        
        NSDate *aClosestConjunction = priorToEquinox > equinoxToNext ? aNextConjunction : aPriorConjunction;
        NSDate *aNewYear = [STCalendar newMoonStartTimeForConjunction:aClosestConjunction :NULL];
        if ( [date timeIntervalSinceDate:aNewYear] >= 0 )
            return aNewYear;
        
        date = [date dateByAddingTimeInterval:i];
    }
    
    NSLog(@"couldn't find last new year for %@!",date);
    abort();
    return nil;
}

- (NSInteger)lunarMonthForDate:(NSDate *)date
{
    NSDate *lastNewYear = [self lastNewYearForDate:date];
    NSDate *aDate = lastNewYear;
    
    int i = 0;
    do {
        aDate = [self conjunctionAfterDate:[aDate dateByAddingTimeInterval:( i == 0 ) ? 0 : STSecondsPerGregorianDay]];
        if ( [date timeIntervalSinceDate:aDate] < 0 )
            break;
        i++;
    } while ( i < 13 );
    
    if ( i == 13 ) {
        NSLog(@"couldn't find lunar month for %@!",date);
        abort();
    }
    
    return i;
}

@end

NS_ASSUME_NONNULL_END
