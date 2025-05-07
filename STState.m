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
#import "STDefines.h"

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

#warning usno only gives fracillum for noon on a particular day
- (double)_syntheticMoonPhaseCurve:(double)zeroThruOne {
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
    double synthetic = [self _syntheticMoonPhaseCurve:monthCompleted];
    NSLog(@"%0.2f vs %0.2f",synthetic,usno);
    
    return synthetic;
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

- (NSDate *)conjunctionPriorToDate:(NSDate *)date
{
    __block NSDate *last = nil;
    NSArray *phases = [self _lunarPhasesFromUSNavyForYear:[[date yearString] intValue] :YES];
    
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
    NSArray *phases = [self _lunarPhasesFromUSNavyForYear:[[date yearString] intValue] + 1 :YES];
    
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

- (NSDate *)lastConjunction
{
    return [self conjunctionPriorToDate:[NSDate myNow]];
}

- (NSDate *)nextConjunction
{
    __block NSDate *next = nil;
    NSArray *phases = [self _lunarPhasesFromUSNavyForYear:[[[NSDate myNow] yearString] intValue] :YES];
    
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

- (NSDate *)lastNewYear
{
    return [self lastNewYearForDate:[NSDate myNow]];
}

- (NSDate *)lastNewYearForDate:(NSDate *)date
{
    NSArray *solarEvents = [self _solarEventsFromUSNavyForYear:[[date yearString] integerValue] :YES];
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
    
    NSArray *phases = [self _lunarPhasesFromUSNavyForYear:[[date yearString] intValue] :YES];
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
    NSArray *phases = [self _lunarPhasesFromUSNavyForYear:[[date yearString] intValue] :YES];
    __block NSInteger months = 0;
    __block BOOL found = NO;
    
    NSDate *lastNewYear = [self lastNewYearForDate:date];
    [phases enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        
        if ( [[obj objectForKey:@"phase"] isEqualToString:@"New Moon"] ) {
            NSString *aThenString = nil;
            
            // find the lunar day delineation based on this conjunction time
            NSDate *aThen = [self _dateFromUSNODictionary:obj :&aThenString];
            NSDate *day = [STCalendar newMoonDayForConjunction:aThen :NULL];
            NSDate *sunset = [[STState state] lastSunsetForDate:day momentAfter:YES];
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

/*- (NSDate *)lastSunset:(BOOL)momentAfter
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
}*/

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


- (BOOL)_shouldSendNoteBasedOnTimeKey:(NSString *)key andMinimumInterval:(NSTimeInterval)notMoreFrequentThan
{
    NSUserDefaults *df = [NSUserDefaults standardUserDefaults];
    NSTimeInterval last = [df doubleForKey:key];
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:last];
    NSTimeInterval interval = [[NSDate myNow] timeIntervalSinceDate:date];
    
    if ( ! interval )
        return YES;
    else if ( interval < 0 ) {
        NSLog(@"are you time travelling?");
        return NO;
    }
    
    if ( interval < notMoreFrequentThan )
        return NO;
    
    return YES;
}

- (BOOL)_shouldSendGeneralSabbathNote
{
    return [self _shouldSendNoteBasedOnTimeKey:LastGeneralNoteDate andMinimumInterval:STSecondsPerGregorianDay];
}

- (BOOL)_shouldSendUrgentSabbathNote
{
    return [self _shouldSendNoteBasedOnTimeKey:LastUrgentNoteDate andMinimumInterval:( STSecondsPerGregorianDay * 6 )];
}

- (void)sendSabbathNotificationWithDelay:(NSTimeInterval)delay
{
    NSDate *now = [NSDate myNow];
    NSDate *nextSabbath = [self nextSabbath:NO];
    NSTimeInterval interval = [now timeIntervalSinceDate:nextSabbath];
    
    NSString *prefsKey = LastGeneralNoteDate;

#define note_debug
#ifdef note_debug
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:LastGeneralNoteDate];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:LastUrgentNoteDate];
    NSLog(@"notification prefs cleared");
#endif
    
    if ( ! [self _shouldSendGeneralSabbathNote] ) {
        if ( -(interval) <= STSecondsPerGregorianDay ) {
            if ( ! [self _shouldSendUrgentSabbathNote] ) {
                NSLog(@"urgent sabbath note sequestered on basis of time (%0.2f)",interval);
                return;
            } else
                prefsKey = LastUrgentNoteDate;
        } else {
            NSLog(@"general sabbath note sequestered on basis of time");
            return;
        }
    }
    
    NSString *myId = @"com.combobulated.Sabbatic";
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    UNMutableNotificationContent *content = [UNMutableNotificationContent new];
    
    
    int formatValue = 0;
    NSString *formatUnit = nil;
    
    if ( ! nextSabbath ) {
        NSLog(@"BUG: couldn't get next sabbath");
        return;
    } else if ( interval >= 0 ) {
        NSLog(@"BUG: next sabbath is in the past! (%@ vs %@)",now,nextSabbath);
        return;
    } else {
        double daysUntilSabbath = -(interval) / STSecondsPerGregorianDay;
        if ( daysUntilSabbath < 1 ) {
            int hoursUntilSabbath = -(interval) / 60.0 / 60.;
            if ( hoursUntilSabbath < 0 ) {
                int minutesUntilSabbath = -(interval) / 60.;
                if ( minutesUntilSabbath < 1 ) {
                    NSLog(@"BUG: couldn't format time to sabbath from %0.2f",interval);
                    return;
                }
                formatValue = minutesUntilSabbath;
                formatUnit = minutesUntilSabbath > 1 ? @"minutes" : @"minute";
            } else {
                formatValue = hoursUntilSabbath;
                formatUnit = hoursUntilSabbath > 1 ? @"hours" : @"hour";
            }
        } else if ( daysUntilSabbath > 3 ) {
            NSLog(@"only notifying of sabbath within 3 days");
            return;
        } else {
            double fraction = daysUntilSabbath - ((long)daysUntilSabbath);
            int wholeUntilSabbath = (int)daysUntilSabbath;
            if ( fraction >= .5 )
                wholeUntilSabbath++;
            formatValue = wholeUntilSabbath;
            formatUnit = daysUntilSabbath > 1 ? @"days" : @"day";
        }
    }
    
    content.title = [NSString stringWithFormat:@"Sabbath in %d %@!",formatValue,formatUnit];
    content.body = [NSString stringWithFormat:@"Starts %@.",[nextSabbath notificationPresentationString]];
    if ( ! delay ) delay = 0.01;
    UNNotificationTrigger *trigger = [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:delay repeats:NO];
    UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:myId content:content trigger:trigger];
    [center addNotificationRequest:request withCompletionHandler:^(NSError * _Nullable error) {
        NSLog(@"notification completed with result: %@",error);
    }];
    
    NSTimeInterval prefsInterval = [[NSDate date] timeIntervalSince1970];
    [[NSUserDefaults standardUserDefaults] setDouble:prefsInterval forKey:prefsKey];
    NSLog(@"%@ => %0.2f",prefsKey,prefsInterval);
    
    NSLog(@"submitted notification request");
}

- (void)requestNotificationApprovalWithDelay:(NSTimeInterval)delay
{
    NSString *key = LastNotificationRequestDate;
    NSString *resultKey = LastNotificationRequestResult;
    NSString *domainKey = LastNotificationRequestResultDomain;
    NSString *codeKey = LastNotificationRequestResultCode;
    NSUserDefaults *df = [NSUserDefaults standardUserDefaults];
    double lnr = [df doubleForKey:key];
    if ( ! lnr ) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
            [center requestAuthorizationWithOptions:UNAuthorizationOptionAlert|UNAuthorizationOptionProvisional completionHandler:^(BOOL granted, NSError * _Nullable error) {
                NSLog(@"user %@ notifications: %@",granted?@"granted":@"declined",error);
                if ( granted ) {
                    [self sendSabbathNotificationWithDelay:STSabbathNotificationDelay];
                }
                [df setBool:granted forKey:resultKey];
                [df setObject:[error domain] forKey:domainKey];
                [df setInteger:[error code] forKey:codeKey];
            }];
            [df setDouble:[[NSDate date] timeIntervalSince1970] forKey:key];
        });
    } else {
        NSDate *date = [NSDate dateWithTimeIntervalSince1970:lnr];
        NSString *domain = [df objectForKey:domainKey];
        NSInteger code = [df integerForKey:codeKey];
        NSLog(@"last asked for notification approval on %@\nlast time, we got '%ld: %@,' shall we ask again?",date,code,domain);
        
        if ( code == 0 )
            [self sendSabbathNotificationWithDelay:STSabbathNotificationDelay];
    }
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
    NSString *dateString = [self _yearMonthDayStringWithDate:lookupDate];
    NSDictionary *dict = [self _usnoOnedayForDateString:dateString location:[self _effectiveLocation]];
    
    for ( NSDictionary *sunEvent in dict[@"properties"][@"data"][@"sundata"] ) {
        if ( [sunEvent[@"phen"] isEqualToString:@"Set"] ) {
            NSArray *components = [sunEvent[@"time"] componentsSeparatedByString:@":"];
            NSDate *sunset = [lookupDate normalizedDatePlusHour:[components[0] integerValue] minute:[components[1] integerValue] second:tzOffset];
            return sunset;
        }
    }
    
    return nil;
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
