//
//  STUSNODataProvider.m
//  Sabbatic
//
//  Created by david on 5/7/25.
//

#import "STUSNODataProvider.h"
#import "NSDate+MyNow.h"
#import "STCalendar.h"
#import "STState.h"
#import "STDefines.h"

#import <CoreLocation/CoreLocation.h>

@implementation STUSNODataProvider

- (double)moonFracillumForDate:(NSDate *)date :(BOOL *)waning
{
    NSString *dateString = [date utcYearMonthDayString];
    NSDictionary *dict = [self _usnoOnedayForDateString:dateString location:[ST effectiveLocation]];
    
    NSString *phase = dict[@"properties"][@"data"][@"curphase"];
    NSString *fracillum = dict[@"properties"][@"data"][@"fracillum"];
    
    if ( waning )
        *waning = [phase rangeOfString:@"Waning" options:NSCaseInsensitiveSearch].location != NSNotFound
                    || [phase rangeOfString:@"Third Quarter" options:NSCaseInsensitiveSearch].location != NSNotFound;
    
    if ( [phase hasSuffix:@"%"] )
        phase = [phase substringToIndex:[phase length] - 1];
    
    return [fracillum doubleValue] / 100.;
}

- (BOOL)onedayKey:(NSString *)key isInRangeOfLocation:(CLLocation *)location
{
    NSArray *components = [key componentsSeparatedByString:@","];
    if ( [components count] != 2 ) {
        NSLog(@"bad oneday prefs key %@",key);
        return NO;
    }
    
    CLLocationDegrees lat = [components[0] doubleValue];
    CLLocationDegrees lon = [components[1] doubleValue];
    
    if ( ! lat || ! lon ) {
        NSLog(@"bad oneday prefs key %@",key);
        return NO;
    }
    
    CLLocation *prefsLoc = [[CLLocation alloc] initWithLatitude:lat longitude:lon];
    CLLocationDistance distance = [prefsLoc distanceFromLocation:location];
    
    BOOL within = ( distance <= ( STMileRadius * STMeterPerMile ) );
    
    return within;
}

- (NSDictionary *)_usnoOnedayForDateString:(NSString *)dateString location:(CLLocation *)location
{
    NSDictionary *usnoDict = [[NSUserDefaults standardUserDefaults] objectForKey:USNODataKey];
    NSDictionary *onedays = [usnoDict objectForKey:USNOOneDayKey];
    NSDictionary *locDict = nil;
    for ( NSString *aKey in onedays ) {
        if ( [self onedayKey:aKey isInRangeOfLocation:location] ) {
            locDict = [onedays objectForKey:aKey];
            break;
        }
    }
    
    NSDictionary *dict = [locDict objectForKey:dateString];
    
    if ( ! dict ) {
        NSString *key = [NSString stringWithFormat:@"%0.2f,%0.2f",location.coordinate.latitude,location.coordinate.longitude];
        dict = [self _fetchInfoFromUSNavy:[NSString stringWithFormat:@"https://aa.usno.navy.mil/api/rstt/oneday?date=%@&coords=%@",dateString,key]];
        if ( ! dict ) {
            NSLog(@"very bad: failed to fetch oneday on %@ from usno!",dateString);
            return nil;
        } else
            NSLog(@"fetched oneday on %@ from usno",dateString);
        
        dict = [self _sanitizedJSON:dict];
        NSLog(@"SANITIZED JSON: %@",dict);
        NSMutableDictionary *usnoM = [usnoDict mutableCopy];
        NSMutableDictionary *onedaysM = [onedays mutableCopy];
        NSMutableDictionary *locDictM = locDict ? [locDict mutableCopy] : [NSMutableDictionary dictionary];
        [locDictM setObject:dict forKey:dateString];
        [onedaysM setObject:locDictM forKey:key];
        [usnoM setObject:onedaysM forKey:USNOOneDayKey];
        [[NSUserDefaults standardUserDefaults] setObject:usnoM forKey:USNODataKey];
    }
    
    return dict;
}

// NSJSONSerialization creates NSNulls from "<null>", which cfprefs doesn't allow
- (id)_sanitizedJSON:(id)obj
{
    id ret = nil;
    if ( [obj isKindOfClass:[NSDictionary class]] ) {
        ret = [NSMutableDictionary dictionary];
        //NSLog(@"NSDictionary: {");
        for ( id key in [obj allKeys] ) {
            id objobj = [obj objectForKey:key];
            if ( [objobj isKindOfClass:[NSNull class]] ) {
                NSLog(@"replaced %@->NSNull",key);
                [ret setObject:@"((null))" forKey:key];
            } else
                [ret setObject:[self _sanitizedJSON:objobj] forKey:key];
        }
        //NSLog(@"}");
    } else if ( [obj isKindOfClass:[NSArray class]] ) {
        //NSLog(@"NSArray: [");
        ret = [NSMutableArray array];
        for ( int i = 0; i < [obj count]; i++ ) {
            id objobj = [obj objectAtIndex:i];
            if ( [objobj isKindOfClass:[NSNull class]] ) {
                NSLog(@"replaced [%d]NSNull",i);
                [ret addObject:@"((null))"];
            } else
                [ret addObject:[self _sanitizedJSON:objobj]];
        }
        //NSLog(@"]");
    } else
        ret = obj;
    
    return ret;
}

- (NSDate *)_fetchSunsetTimeOnDate:(NSDate *)date
{
    NSInteger tzOffset = [[NSTimeZone localTimeZone] secondsFromGMTForDate:date];
    NSDate *lookupDate = [date normalizedDatePlusHour:0 minute:0 second:0];
    NSString *dateString = [lookupDate utcYearMonthDayString];
    NSDictionary *dict = [self _usnoOnedayForDateString:dateString location:[ST effectiveLocation]];
    
    for ( NSDictionary *sunEvent in dict[@"properties"][@"data"][@"sundata"] ) {
        if ( [sunEvent[@"phen"] isEqualToString:@"Set"] ) {
            NSArray *components = [sunEvent[@"time"] componentsSeparatedByString:@":"];
            NSDate *sunset = [lookupDate normalizedDatePlusHour:[components[0] integerValue] minute:[components[1] integerValue] second:tzOffset];
            return sunset;
        }
    }
    
    return nil;
}

- (NSDate *)conjunctionPriorToDate:(NSDate *)date
{
    __block NSDate *last = nil;
    NSArray *phases = [self _lunarPhasesFromUSNavyForYear:[[date localYearString] intValue] :YES];
    
    // search backwards to the first one in the past
    [phases enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        
        if ( [[obj objectForKey:@"phase"] isEqualToString:@"New Moon"] ) {
            NSString *aThenString = nil;
            NSDate *aThen = [self _dateFromUSNODictionary:obj :&aThenString];
            
            if ( [date timeIntervalSinceDate:aThen] > 0 ) {
                last = aThen;
                *stop = YES;
            }
        }
    }];
    
    return last;
}

- (NSDate *)conjunctionAfterDate:(NSDate *)date
{
    __block NSDate *next = nil;
    NSArray *phases = [self _lunarPhasesFromUSNavyForYear:[[date localYearString] intValue] + 1 :YES];
    
    // search backwards to the first one in the past
    [phases enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        
        if ( [[obj objectForKey:@"phase"] isEqualToString:@"New Moon"] ) {
            NSString *aThenString = nil;
            NSDate *aThen = [self _dateFromUSNODictionary:obj :&aThenString];
            
            if ( [date timeIntervalSinceDate:aThen] < 0 ) {
                next = aThen;
                *stop = YES;
            }
        }
    }];
    
    return next;
}

- (NSDate *)nextConjunction
{
    __block NSDate *next = nil;
    NSArray *phases = [self _lunarPhasesFromUSNavyForYear:[[[NSDate myNow] localYearString] intValue] :YES];
    
    // search forwards to the first one in the future
    [phases enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        
        if ( [[obj objectForKey:@"phase"] isEqualToString:@"New Moon"] ) {
            NSString *aThenString = nil;
            NSDate *aThen = [self _dateFromUSNODictionary:obj :&aThenString];
            
            NSDate *myNow = [NSDate myNow];
            if ( [myNow timeIntervalSinceDate:aThen] < 0 ) {
                next = aThen;
                *stop = YES;
            }
        }
    }];
    
    return next;
}

- (NSDate *)lastNewYearForDate:(NSDate *)date
{
    NSArray *solarEvents = [self _solarEventsFromUSNavyForYear:[[date localYearString] integerValue] :YES];
    __block NSDate *springEquinoxDate = nil;
    __block NSString *springEquinoxDateString = nil;
    [solarEvents enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSDictionary *dict = obj;
        if ( [dict[@"phenom"] isEqualToString:@"Equinox"] && [dict[@"month"] integerValue] < 6 ) {
            NSString *aString = nil;
            NSDate *aDate = [self _dateFromUSNODictionary:obj :&aString];
            if ( [date timeIntervalSinceDate:aDate] > 0 ) {
                springEquinoxDate = aDate;
                springEquinoxDateString = aString;
                *stop = YES;
            }
        }
    }];
    
    __block NSDate *last = nil;
    __block NSString *lastString = nil;
    __block NSTimeInterval lastDelta;
    
    NSArray *phases = [self _lunarPhasesFromUSNavyForYear:[[date localYearString] intValue] :YES];
    [phases enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        
        if ( [[obj objectForKey:@"phase"] isEqualToString:@"New Moon"] ) {
            NSString *aThenString = nil;
            NSDate *aThen = [self _dateFromUSNODictionary:obj :&aThenString];
            
            if ( ! last ) {
                last = aThen;
                lastString = aThenString;
                lastDelta = [aThen timeIntervalSinceDate:springEquinoxDate];
                if ( lastDelta < 0 )
                    lastDelta = -lastDelta;
#ifdef debugDateStuff
                NSLog(@"new year search, some new moon was %@",last);
#endif
            } else {
                NSTimeInterval aDelta = [aThen timeIntervalSinceDate:springEquinoxDate];
                if ( aDelta < 0 )
                    aDelta = -aDelta;
                if ( aDelta < lastDelta ) {
#ifdef debugDateStuff
                    NSLog(@"new year search, %@ is closer to sequinox than %@",aThen,last);
#endif
                    last = aThen;
                    lastString = aThenString;
                    lastDelta = aDelta;
                }
#ifdef debugDateStuff
                else
                    NSLog(@"new year search, %@ is NOT closer to sequinox than %@",aThen,last);
#endif
            }
        }
    }];
    
    NSTimeInterval daysDelta = lastDelta / 60. / 60. / 24.;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSLog(@"the last new year %@ was %0.0f days removed from the spring equinox",lastString,daysDelta);
    });
    
    return last;
}

- (NSInteger)lunarMonthForDate:(NSDate *)date
{
    NSArray *phases = [self _lunarPhasesFromUSNavyForYear:[[date localYearString] intValue] :YES];
    __block NSInteger months = 0;
    __block BOOL found = NO;
    
    NSDate *lastNewYear = [self lastNewYearForDate:date];
    [phases enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        
        if ( [[obj objectForKey:@"phase"] isEqualToString:@"New Moon"] ) {
            NSString *aThenString = nil;
            
            // find the lunar day delineation based on this conjunction time
            NSDate *aThen = [self _dateFromUSNODictionary:obj :&aThenString];
            NSDate *day = [STCalendar newMoonDayForConjunction:aThen :NULL];
            NSDate *sunset = [DP lastSunsetForDate:day momentAfter:YES];
            if ( ! found ) {
                if ( [lastNewYear compare:sunset] == NSOrderedAscending ) {
                    found = YES;
                    return;
                }
            } else {
                if ( [date timeIntervalSinceDate:sunset] < 0 )
                    *stop = YES;
                else
                    months++;
            }
        }
    }];
    
    NSLog(@"it has been %lu months since the new year",months);
    return months;
}

- (NSArray *)_lunarPhasesFromUSNavyForYear:(NSInteger)year :(BOOL)includePreviousYear
{
    NSMutableArray *retArray = [NSMutableArray array];
    
    if ( includePreviousYear )
        year--;
    
    do {
        NSDictionary *usnoDict = [[NSUserDefaults standardUserDefaults] objectForKey:USNODataKey];
        NSDictionary *lunarDict = [usnoDict objectForKey:USNOLunarPhasesKey];
        NSString *key = [NSString stringWithFormat:@"%ld",year];
        NSDictionary *dict = [lunarDict objectForKey:key];
        
        if ( ! dict ) {
            dict = [self _fetchLunarPhasesFromUSNavyForYear:year];
            if ( ! dict ) {
                NSLog(@"very bad: failed to fetch lunar phases from usno!");
                return nil;
            } else
                NSLog(@"fetched usno lunar phases");
            
            NSMutableDictionary *usnoM = [usnoDict mutableCopy];
            NSMutableDictionary *lunarM = [lunarDict mutableCopy];
            [lunarM setObject:dict forKey:key];
            [usnoM setObject:lunarM forKey:USNOLunarPhasesKey];
            [[NSUserDefaults standardUserDefaults] setObject:usnoM forKey:USNODataKey];
        }
        
        [retArray addObjectsFromArray:[dict objectForKey:@"phasedata"]];
        
        year++;
    } while ( ( includePreviousYear ) && ! ( includePreviousYear = NO ) );
    
    return retArray;
}

- (NSArray *)_solarEventsFromUSNavyForYear:(NSInteger)year :(BOOL)includePreviousYear
{
    NSMutableArray *retArray = [NSMutableArray array];
    
    if ( includePreviousYear )
        year--;
    
    do {
        NSDictionary *usnoDict = [[NSUserDefaults standardUserDefaults] objectForKey:USNODataKey];
        NSDictionary *solarDict = [usnoDict objectForKey:USNOSolarEventsKey];
        NSString *key = [NSString stringWithFormat:@"%ld",year];
        NSDictionary *dict = [solarDict objectForKey:key];
        
        if ( ! dict ) {
            dict = [self _fetchSolarEventsFromUSNavyForYear:year];
            if ( ! dict ) {
                NSLog(@"very bad: failed to fetch solar events from usno!");
                return nil;
            } else
                NSLog(@"fetched usno solar events");
        
            NSMutableDictionary *usnoM = [usnoDict mutableCopy];
            NSMutableDictionary *solarM = [solarDict mutableCopy];
            [solarM setObject:dict forKey:key];
            [usnoM setObject:solarM forKey:USNOSolarEventsKey];
            [[NSUserDefaults standardUserDefaults] setObject:usnoM forKey:USNODataKey];
        }
        
        [retArray addObjectsFromArray:[dict objectForKey:@"data"]];
        
        year++;
    } while ( ( includePreviousYear ) && ! ( includePreviousYear = NO ) );
    
    return retArray;
}

- (NSDate *)_dateFromUSNODictionary:(NSDictionary *)dict :(NSString **)outString
{
    // yyyy-MM-dd'T'HH:mm:SS.SSS'Z'
    NSString *ds = [NSString stringWithFormat:@"%@-%@-%@T%@Z",dict[@"year"],dict[@"month"],dict[@"day"],dict[@"time"]];
    //NSLog(@"%@?",ds);
    NSDateFormatter * df = [[NSDateFormatter alloc] init];
    NSTimeZone *tz = [NSTimeZone timeZoneWithName:@"UTC"];
    [df setTimeZone:tz];
    [df setDateFormat:@"yyyy-MM-dd'T'HH:mm'Z'"];
    if ( outString )
        *outString = ds;
    return [df dateFromString:ds];
}

- (id)_fetchLunarPhasesFromUSNavyForYear:(NSInteger)year
{
    return [self _fetchInfoFromUSNavy:[NSString stringWithFormat:@"https://aa.usno.navy.mil/api/moon/phases/year?year=%ld",year]];
}

- (id)_fetchSolarEventsFromUSNavyForYear:(NSInteger)year
{
    return [self _fetchInfoFromUSNavy:[NSString stringWithFormat:@"https://aa.usno.navy.mil/api/seasons?year=%ld",year]];
}

- (id)_fetchInfoFromUSNavy:(NSString *)urlString
{
    __block id obj = nil;
    
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    
    NSURLSession *ses = [NSURLSession sharedSession];

    NSURL *u = [NSURL URLWithString:urlString];
    NSLog(@"fetching %@",u);
    NSURLSessionTask *task = [ses dataTaskWithURL:u completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        NSLog(@"%s: %@ %@ %@",__PRETTY_FUNCTION__,data,response,error);
        NSError *myError = nil;
        obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:&myError];
                                                    // -className fails to build for iOS
        NSLog(@"usno de-json %@: (%@) %@",myError,[obj performSelector:@selector(className)],obj);
        dispatch_semaphore_signal(sem);
    }];
    [task resume];
    
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    
    return obj;
}

@end
