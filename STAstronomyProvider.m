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
    NSCalendarUnit flags = ( NSCalendarUnitEra | NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay
                            | NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond );
    NSDateComponents *comps = [[NSCalendar currentCalendar] components:flags fromDate:self];
    
    int year = comps.era == 0 ? -((int)comps.year - 1) : (int)comps.year;
    astro_utc_t utc = { year, (int)comps.month, (int)comps.day, (int)comps.hour, (int)comps.minute, comps.second };

    return Astronomy_TimeFromUtc(utc);
}

+ (NSDate *)dateWithAstroTime:(astro_time_t)astroTime
{
    astro_utc_t astroUtc = Astronomy_UtcFromTime(astroTime);
    int epoch = 1, year = astroUtc.year;
    if ( astroUtc.year <= 0 ) {
        epoch = 0;
        year = -(astroUtc.year) + 1;
    }
    
    NSDate *date = [[NSCalendar currentCalendar] dateWithEra:epoch year:year month:astroUtc.month day:astroUtc.day hour:astroUtc.hour minute:astroUtc.minute second:astroUtc.second nanosecond:0];
    date = [date dateByAddingTimeInterval:[[NSTimeZone localTimeZone] secondsFromGMTForDate:date]];
    return date;
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
    
    if ( waning ) {
        NSDate *last = [self lastConjunction];
        NSDate *next = [self nextConjunction];
        NSDate *mid = [last dateByAddingTimeInterval:( [next timeIntervalSince1970] - [last timeIntervalSince1970] ) / 2];
        if ( [date timeIntervalSinceDate:mid] >= 0 )
            *waning = YES;
        else
            *waning = NO;
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
    NSDate *lunarMonthAgo = [date dateByAddingTimeInterval:-( STSecondsPerLunarMonth + STSecondsPerGregorianDay )];
    NSDate *aConj = [self conjunctionAfterDate:lunarMonthAgo];
    NSDate *anotherConj = [self conjunctionAfterDate:[aConj dateByAddingTimeInterval:STSecondsPerGregorianDay]];
    NSTimeInterval interval = [anotherConj timeIntervalSinceDate:aConj];
    
    if ( [date timeIntervalSinceDate:aConj] < 0 || interval < 0 ) {
        NSLog(@"something is wrong");
        abort();
    }
    
    if ( [date timeIntervalSinceDate:anotherConj] > 0 )
        return anotherConj;
    
    return aConj;
}

- (NSDate *)conjunctionAfterDate:(NSDate *)date
{
    astro_moon_quarter_t mq = {0};
    
    NSDate *startDate = date;
    
    for ( int j = 0; j < 2; j++ ) {
        for ( int i = 0; i < 4; i++ ) {
            if ( i == 0 )
                mq = Astronomy_SearchMoonQuarter([startDate astroTime]);
            else
                mq = Astronomy_NextMoonQuarter(mq);
            
            if ( mq.quarter == 0 ) {
                NSDate *aDate = [NSDate dateWithAstroTime:mq.time];
                if ( [date timeIntervalSinceDate:aDate] < 0 )
                    return aDate;
                else
                    startDate = [aDate dateByAddingTimeInterval:STSecondsPerGregorianDay];
            }
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
    NSCalendarUnit flags = ( NSCalendarUnitEra | NSCalendarUnitYear );
    NSDateComponents *comps = [[NSCalendar currentCalendar] components:flags fromDate:date];
    int searchYear = (int)comps.year;
    if ( comps.era == 0 ) {
        searchYear = -((int)comps.year) + 1;
    }
    
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
    
    NSLog(@"couldn't find spring equinox for %@!",date);
    abort();
    return nil;
}

- (NSDate *)_nextSpringEquinoxForDate:(NSDate *)date
{
    int searchYear = (int)[date absoluteYear];
    
    for ( int i = 0; i < 2; i++ ) {
        astro_seasons_t seasons = Astronomy_Seasons(searchYear + i);
        
        if (seasons.status != ASTRO_SUCCESS) {
            NSLog(@"ERROR: Astronomy_Seasons() returned %d\n", seasons.status);
            abort();
        }
        
        NSDate *equinox = [NSDate dateWithAstroTime:seasons.mar_equinox];
        if ( [date timeIntervalSinceDate:equinox] < 0 ) {
            return equinox;
        }
    }
    
    NSLog(@"couldn't find spring equinox for %@!",date);
    abort();
    return nil;
}

- (NSDate *)lastNewYearForDate:(NSDate *)date
{
    NSDate *origDate = date;
    for ( int i = 0 ; i > -2; i-- ) {
        NSDate *lastEquinox = [self _lastSpringEquinoxForDate:date];
        
        // see motnc 2026 reckoning, spring equinox falls 2 days after conjunction
        // we're using their understanding that the closest new moon to equinox wins new year
        NSDate *nextEquinox = [self _nextSpringEquinoxForDate:date];
        NSDate *nextPriorConjunction = [self conjunctionPriorToDate:nextEquinox];
        NSDate *nextPriorNewStart = [STCalendar newMoonStartTimeForConjunction:nextPriorConjunction];
        if ( [date timeIntervalSinceDate:nextPriorNewStart] >= 0 ) {
            NSDate *nextNextPriorConjunction = [self conjunctionAfterDate:nextEquinox];
            NSDate *nextNextPriorNewStart = [STCalendar newMoonStartTimeForConjunction:nextNextPriorConjunction];
            if ( [nextEquinox timeIntervalSinceDate:nextPriorNewStart] < [nextNextPriorNewStart timeIntervalSinceDate:nextEquinox] ) {
                NSLog(@"last new year for %@, (%@) %@ -> %@ -> %@",date,lastEquinox,nextEquinox,nextPriorConjunction,nextPriorNewStart);
                return nextPriorNewStart;
            }
        }
        
        NSDate *aPriorConjunction = [self conjunctionPriorToDate:lastEquinox];
        NSDate *aNextConjunction = [self conjunctionAfterDate:lastEquinox];
        NSTimeInterval priorToEquinox = [lastEquinox timeIntervalSinceDate:aPriorConjunction];
        NSTimeInterval equinoxToNext = [aNextConjunction timeIntervalSinceDate:lastEquinox];
        if ( priorToEquinox < 0 || equinoxToNext < 0 ) {
            NSLog(@"something is wrong");
            abort();
        }
        
        NSDate *aClosestConjunction = priorToEquinox > equinoxToNext ? aNextConjunction : aPriorConjunction;
        NSDate *aNewYear = [STCalendar newMoonStartTimeForConjunction:aClosestConjunction];
        if ( [date timeIntervalSinceDate:aNewYear] >= 0 ) {
            NSLog(@"last new year for %@\n\t%@\n\tlastEquinox %@\n\tpriorC %@\n\tnextC %@",origDate,aNewYear,lastEquinox,aPriorConjunction,aNextConjunction);
            return aNewYear;
        }
        
        date = [date dateByAddingTimeInterval:i];
    }
    
    NSLog(@"couldn't find last new year for %@!",origDate);
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
