//
//  STState.m
//  Sabbatic
//
//  Created by david on 4/16/25.
//

#import <Foundation/Foundation.h>
#import <UserNotifications/UserNotifications.h>
#import <CoreLocation/CoreLocation.h>

#import "STState.h"
#import "STCalendar.h"
#import "NSDate+MyNow.h"

//#define debugDateStuff

static STState *sState = nil;

@interface STState (Private)
- (CLLocation *)_effectiveLocation;
- (NSArray *)_lunarPhasesFromUSNavyForYear:(NSInteger)year;
- (id)_fetchLunarPhasesFromUSNavyForYear:(NSInteger)year;
- (NSDate *)_fetchSunsetTimeOnDate:(NSDate *)date;
@end

@implementation STState

+ (id)state
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sState = [STState new];
    });
    return sState;
}

- (double)currentMoonFracillum:(BOOL *)waning
{
    return [self moonFracillumForDate:[NSDate myNow] :waning];
}

- (double)moonFracillumForDate:(NSDate *)date :(BOOL *)waning
{
    NSString *dateString = [self _yearMonthDayStringWithDate:date];
    NSDictionary *dict = [self _usnoOnedayForDateString:dateString location:[self _effectiveLocation]];
    
    NSString *phase = dict[@"properties"][@"data"][@"curphase"];
    NSString *fracillum = dict[@"properties"][@"data"][@"fracillum"];
    
    if ( waning )
        *waning = [phase rangeOfString:@"Waning" options:NSCaseInsensitiveSearch].location != NSNotFound
                    || [phase rangeOfString:@"Third Quarter" options:NSCaseInsensitiveSearch].location != NSNotFound;
    
    if ( [phase hasSuffix:@"%"] )
        phase = [phase substringToIndex:[phase length] - 1];
    
    return [fracillum doubleValue] / 100.;
}

- (NSDate *)_conjunctionPriorToDate:(NSDate *)date
{
    __block NSDate *last = nil;
    NSArray *phases = [self _lunarPhasesFromUSNavyForYear:-1];
    
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

- (NSDate *)lastConjunction
{
    return [self _conjunctionPriorToDate:[NSDate myNow]];
}

- (NSDate *)nextConjunction
{
    __block NSDate *next = nil;
    NSArray *phases = [self _lunarPhasesFromUSNavyForYear:-1];
    
    // search forwards to the first one in the future
    [phases enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        
        if ( [[obj objectForKey:@"phase"] isEqualToString:@"New Moon"] ) {
            NSString *aThenString = nil;
            NSDate *aThen = [self _dateFromUSNODictionary:obj :&aThenString];
            
            NSDate *myNow = [NSDate myNow];
            NSTimeInterval interval = [myNow timeIntervalSinceDate:aThen];
            if ( [myNow timeIntervalSinceDate:aThen] < 0 ) {
                next = aThen;
                *stop = YES;
            }
        }
    }];
    
    return next;
}

- (NSDate *)lastNewYear
{
    NSArray *solarEvents = [self _solarEventsFromUSNavyForYear:-1];
    __block NSDate *springEquinoxDate = nil;
    __block NSString *springEquinoxDateString = nil;
    [solarEvents enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSDictionary *dict = obj;
        if ( [dict[@"phenom"] isEqualToString:@"Equinox"] && [dict[@"month"] integerValue] < 6 ) {
            NSString *aString = nil;
            NSDate *aDate = [self _dateFromUSNODictionary:obj :&aString];
            if ( [[NSDate myNow] timeIntervalSinceDate:aDate] > 0 ) {
                springEquinoxDate = aDate;
                springEquinoxDateString = aString;
                *stop = YES;
            }
        }
    }];
    
    __block NSDate *last = nil;
    __block NSString *lastString = nil;
    __block NSTimeInterval lastDelta;
    
    NSArray *phases = [self _lunarPhasesFromUSNavyForYear:-1];
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

- (NSInteger)currentLunarMonth
{
    NSArray *phases = [self _lunarPhasesFromUSNavyForYear:-1];
    __block NSInteger months = 0;
    __block BOOL found = NO;
    
    NSDate *lastNewYear = [self lastNewYear];
    [phases enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        
        if ( [[obj objectForKey:@"phase"] isEqualToString:@"New Moon"] ) {
            NSString *aThenString = nil;
            
            // find the lunar day delineation based on this conjunction time
            NSDate *aThen = [self _dateFromUSNODictionary:obj :&aThenString];
            NSDate *day = [STCalendar newMoonDayForConjunction:aThen];
            NSDate *sunset = [[STState state] lastSunsetForDate:day momentAfter:YES];
            if ( ! found ) {
                if ( [lastNewYear compare:sunset] == NSOrderedAscending ) {
                    found = YES;
                    return;
                }
            } else {
                if ( [[NSDate myNow] timeIntervalSinceDate:sunset] < 0 )
                    *stop = YES;
                else
                    months++;
            }
        }
    }];
    
    NSLog(@"it has been %lu months since the new year",months);
    return months;
}

- (NSDate *)lastNewMoonStart
{
    NSDate *last = [self lastConjunction];
    NSDate *day = [STCalendar newMoonDayForConjunction:last];
    NSDate *sunsetPreviousDay = [self lastSunsetForDate:day momentAfter:YES];
    
    // called after conjunction but before new moon start
    if ( [[NSDate myNow] timeIntervalSinceDate:sunsetPreviousDay] < 0 ) {
        NSDate *lastLast = [self _conjunctionPriorToDate:last];
        NSDate *lastLastDay = [STCalendar newMoonDayForConjunction:lastLast];
        sunsetPreviousDay = [self lastSunsetForDate:lastLastDay momentAfter:YES];
    }
    
    return sunsetPreviousDay;
}

- (NSDate *)nextNewMoonStart
{
    NSDate *next = [self nextConjunction];
    NSDate *day = [STCalendar newMoonDayForConjunction:next];
    NSLog(@"next conjunction for determining nextNewMoonStart: %@, gregorian midnight: %@",next,day);
    NSDate *start = [STCalendar date:day byAddingDays:-1 hours:0 minutes:0 seconds:0];
    NSDate *sunsetPreviousDay = [self _fetchSunsetTimeOnDate:start];
    if ( [[NSDate myNow] timeIntervalSinceDate:sunsetPreviousDay] > 0 ) {
        NSLog(@"uh-oh! newNewMoonStart is in the future!");
        abort();
    }
    return sunsetPreviousDay;
}

- (NSDate *)lastSunset:(BOOL)momentAfter
{
    NSDate *myNow = [NSDate myNow];
    NSDate *sunsetToday = [self lastSunsetForDate:myNow momentAfter:momentAfter];
    NSTimeInterval timeSince = [myNow timeIntervalSinceDate:sunsetToday];
    static dispatch_once_t onceToken;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        onceToken = 0;
    });
    if ( timeSince >= 0 ) {
        dispatch_once(&onceToken, ^{
            NSLog(@"the sun set %0.2f hours ago at %@ (%@)",timeSince / 60. / 60.,sunsetToday,myNow);
        });
        return sunsetToday;
    }
    NSDate *dayBefore = [STCalendar date:myNow byAddingDays:-1 hours:+1 minutes:0 seconds:0];
    NSDate *sunsetDayBefore = [self lastSunsetForDate:dayBefore momentAfter:momentAfter];
    timeSince = [myNow timeIntervalSinceDate:sunsetDayBefore];
    dispatch_once(&onceToken, ^{
        NSLog(@"the sun set %0.2f hours ago at %@ (%@)",timeSince / 60. / 60.,sunsetDayBefore,myNow);
    });
    return sunsetDayBefore;
}

- (NSDate *)nextSunset:(BOOL)momentAfter
{
    NSDate *origDate = [NSDate myNow];
    NSDate *date = origDate;
    NSDate *sunsetDate = nil;
    date = [STCalendar date:date byAddingDays:-1 hours:0 minutes:0 seconds:0];
    while ( ( sunsetDate = [self lastSunsetForDate:date momentAfter:YES] ) ) {
        if ( [origDate timeIntervalSinceDate:sunsetDate] <= 0 ) {
            if ( momentAfter )
                sunsetDate = [STCalendar date:sunsetDate byAddingDays:0 hours:0 minutes:0 seconds:1];
            return sunsetDate;
        }
        date = [STCalendar date:date byAddingDays:1 hours:1 minutes:0 seconds:0];
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
                sunsetDate = [STCalendar date:sunsetDate byAddingDays:0 hours:0 minutes:0 seconds:1];
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
                sunsetDate = [STCalendar date:sunsetDate byAddingDays:0 hours:0 minutes:0 seconds:1];
            return sunsetDate;
        }
        date = [STCalendar date:date byAddingDays:1 hours:0 minutes:0 seconds:0];
    }
    
    return nil;
}

- (NSDate *)lastNewMoonDay
{
    NSDate *last = [self lastConjunction];
    NSDate *day = [self normalizeDate:[STCalendar newMoonDayForConjunction:last]];
    return day;
}

- (NSDate *)nextNewMoonDay
{
    NSDate *next = [self nextConjunction];
    return [self normalizeDate:[STCalendar newMoonDayForConjunction:next]];
}

- (NSDate *)lastSabbath
{
    NSDate *lastNewMoon = [self lastNewMoonDay];
    NSDate *now = [NSDate myNow];
    NSDate *last = nil;
    int i = 3;
    for( ; i > 0; i-- ) {
        NSInteger days = i * 7 + 1 + 1;
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
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            NSLog(@"The last sabbath from %@ is the %dth, %@, based on last new moon %@",now,i,last,lastNewMoon);
        });
    }
    
    return last;
}

- (NSDate *)nextSabbath
{
    NSDate *lastNewMoon = [self lastNewMoonDay];
    NSDate *now = [NSDate myNow];
    NSDate *next = nil;
    int i = 0;
    for( ; i < 4; i++ ) {
        NSInteger days = i * 7 + 2;
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
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            NSLog(@"The next sabbath from %@ is the %dth, %@",now,i,next);
        });
    }
    
    return next;
}

- (NSDate *)normalizeDate:(NSDate *)date
{
    NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    NSDateComponents *dateComponents = [gregorian components:(NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay) fromDate:date];    
    NSDate *normalizedDate = [gregorian dateFromComponents:dateComponents];
#ifdef debugDateStuff
    NSLog(@"%@ normalized to %@",date,normalizedDate);
#endif
    //normalizedDate = [normalizedDate dateByAddingTimeInterval:[[NSTimeZone localTimeZone] secondsFromGMTForDate:normalizedDate]];
    return normalizedDate;
}

- (NSDate *)normalizeDate:(NSDate *)date hour:(NSInteger)hour minute:(NSInteger)minute second:(NSInteger)second
{
    date = [self normalizeDate:date];
    NSDate *normalizedDate = [STCalendar date:date byAddingDays:0 hours:hour minutes:minute seconds:second];
#ifdef debugDateStuff
    NSLog(@"%@ normalized to %@",date,normalizedDate);
#endif
    return normalizedDate;
}

- (void)requestNotificationApproval
{
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    [center requestAuthorizationWithOptions:UNAuthorizationOptionAlert|UNAuthorizationOptionProvisional completionHandler:^(BOOL granted, NSError * _Nullable error) {
        NSLog(@"user %@ notifications: %@",granted?@"granted":@"declined",error);
    }];
}

- (void)requestLocationAuthorization
{
    CLLocationManager *manager = [CLLocationManager new];
    manager.delegate = self;
    [manager requestWhenInUseAuthorization];
}

- (void)locationManagerDidChangeAuthorization:(CLLocationManager *)manager
{
    if ( manager.authorizationStatus == kCLAuthorizationStatusAuthorizedAlways
#ifndef __MAC_OS_X_VERSION_MAX_ALLOWED
        || manager.authorizationStatus == kCLAuthorizationStatusAuthorizedWhenInUse
#endif
        ) {
        NSLog(@"location stored");
        _location = manager.location;
    } else
        NSLog(@"location not authorized: %d",manager.authorizationStatus);
}

- (CLLocation *)_effectiveLocation
{
    if ( _location )
        return _location;
    return [[CLLocation alloc] initWithLatitude:38.63 longitude:-90.20];
}

- (NSArray *)_lunarPhasesFromUSNavyForYear:(NSInteger)year
{
    BOOL includePreviousYear = NO;
    if ( year < 0 ) {
        year = [self _theCurrentYear] - 1;
        includePreviousYear = YES;
    }
    
    NSMutableArray *retArray = [NSMutableArray array];
    
    do {
        NSString *key = [NSString stringWithFormat:@"com.combobulated.Sabbatic.usno.%ld",year];
        NSDictionary *dict = [[NSUserDefaults standardUserDefaults] objectForKey:key];
        
        if ( ! dict ) {
            dict = [self _fetchLunarPhasesFromUSNavyForYear:year];
            if ( ! dict ) {
                NSLog(@"very bad: failed to fetch lunar phases from usno!");
                return nil;
            } else
                NSLog(@"fetched usno lunar phases");
            
            [[NSUserDefaults standardUserDefaults] setObject:dict forKey:key];
        }
        
        [retArray addObjectsFromArray:[dict objectForKey:@"phasedata"]];
        
        year++;
    } while ( ( includePreviousYear ) && ! ( includePreviousYear = NO ) );
    
    return retArray;
}

- (NSArray *)_solarEventsFromUSNavyForYear:(NSInteger)year
{
    BOOL includePreviousYear = NO;
    if ( year < 0 ) {
        year = [self _theCurrentYear] - 1;
        includePreviousYear = YES;
    }
    
    NSMutableArray *retArray = [NSMutableArray array];
    
    do {
        NSString *key = [NSString stringWithFormat:@"com.combobulated.Sabbatic.usno.solar.%ld",year];
        NSDictionary *dict = [[NSUserDefaults standardUserDefaults] objectForKey:key];
        
        if ( ! dict ) {
            dict = [self _fetchSolarEventsFromUSNavyForYear:year];
            if ( ! dict ) {
                NSLog(@"very bad: failed to fetch solar events from usno!");
                return nil;
            } else
                NSLog(@"fetched usno solar events");
            
            [[NSUserDefaults standardUserDefaults] setObject:dict forKey:key];
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

- (NSInteger)_theCurrentYear
{
    NSDate *date = [NSDate myNow];
    NSDateFormatter * df = [[NSDateFormatter alloc] init];
    NSTimeZone *tz = [NSTimeZone timeZoneWithName:@"UTC"];
    [df setTimeZone:tz];
    [df setDateFormat:@"yyyy"];
    return [[df stringFromDate:date] integerValue];
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
                [ret addObject:@"((null)))"];
            } else
                [ret addObject:[self _sanitizedJSON:objobj]];
        }
        //NSLog(@"]");
    } else
        ret = obj;
    
    return ret;
}

#warning detect significant location change (or user tz change) and discard all preferences
- (NSDate *)_fetchSunsetTimeOnDate:(NSDate *)date
{
    NSInteger tzOffset = [[NSTimeZone localTimeZone] secondsFromGMTForDate:date];
    NSDate *lookupDate = [STCalendar date:date byAddingDays:0 hours:0 minutes:0 seconds:0];
    NSString *dateString = [self _yearMonthDayStringWithDate:lookupDate];
    NSDictionary *dict = [self _usnoOnedayForDateString:dateString location:[self _effectiveLocation]];
    
    //NSLog(@"%@ lookup %@ (%@)",date,lookupDate,dateString);
    for ( NSDictionary *sunEvent in dict[@"properties"][@"data"][@"sundata"] ) {
        if ( [sunEvent[@"phen"] isEqualToString:@"Set"] ) {
            NSArray *components = [sunEvent[@"time"] componentsSeparatedByString:@":"];
            NSDate *sunset = [self normalizeDate:lookupDate hour:[components[0] integerValue] minute:[components[1] integerValue] second:tzOffset];
            return sunset;
        }
    }
    
    return nil;
}

- (NSDictionary *)_usnoOnedayForDateString:(NSString *)dateString location:(CLLocation *)location
{
    NSString *key = [NSString stringWithFormat:@"com.combobulated.Sabbatic.usno.oneday.%@",dateString];
    NSDictionary *dict = [[NSUserDefaults standardUserDefaults] objectForKey:key];
    
    if ( ! dict ) {
        dict = [self _fetchInfoFromUSNavy:[NSString stringWithFormat:@"https://aa.usno.navy.mil/api/rstt/oneday?date=%@&coords=%0.2f,%0.2f",dateString,location.coordinate.latitude,location.coordinate.longitude]];
        if ( ! dict ) {
            NSLog(@"very bad: failed to fetch oneday on %@ from usno!",dateString);
            return nil;
        } else
            NSLog(@"fetched oneday on %@ from usno",dateString);
        
        NSDictionary *sanitized = [self _sanitizedJSON:dict];
        NSLog(@"SANITIZED JSON: %@",sanitized);
        [[NSUserDefaults standardUserDefaults] setObject:sanitized forKey:key];
    }
    
    return dict;
}

- (NSString *)_yearMonthDayStringWithDate:(NSDate *)date
{
    NSDateFormatter * df = [[NSDateFormatter alloc] init];
    NSTimeZone *tz = [NSTimeZone timeZoneWithName:@"UTC"];
    [df setTimeZone:tz];
    [df setDateFormat:@"yyyy-MM-dd"];
    return [df stringFromDate:date];
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
