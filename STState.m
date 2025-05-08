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
#import "NSDate+MyNow.h"
#import "STDefines.h"

static STState *sState = nil;

@implementation STState

+ (id)state
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sState = [STState new];
    });
    return sState;
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
    NSDate *nextSabbath = [_dataProvider nextSabbath:NO];
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

- (CLLocation *)effectiveLocation
{
    if ( _location )
        return _location;
    return [[CLLocation alloc] initWithLatitude:38.63 longitude:-90.20];
}

- (void)setDataProvider:(id<STDataProvider>)dataProvider
{
    _dataProvider = dataProvider;
}

- (id<STDataProvider>)dataProvider
{
    return _dataProvider;
}

@end
