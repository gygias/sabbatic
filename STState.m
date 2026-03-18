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

@interface STState ()
@property CLLocationManager *locationManager;
@property NSDate *lastLocationServicesRequested;
@property NSInteger lastLocationServicesStatus;
@property (copy) void (^locationAuthCallback)(BOOL);
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

- (id)init
{
    if ( self = [super init] ) {
        NSUserDefaults *df = [NSUserDefaults standardUserDefaults];
        self.locationPreferenceGathered = [df boolForKey:LocationPreferenceGathered];
        self.useManualLocation = [df boolForKey:UseManualLocation];
        self.manualLatitude = [df doubleForKey:ManualLatitude];
        self.manualLongitude = [df doubleForKey:ManualLongitude];
        self.lastLSLatitude = [df doubleForKey:LastLSLatitude];
        self.lastLSLongitude = [df doubleForKey:LastLSLongitude];
        self.lastLocationServicesRequested = [NSDate dateWithTimeIntervalSince1970:[df doubleForKey:LastLocationServicesRequested]];
        self.lastLocationServicesStatus = [df integerForKey:LastLocationServicesStatus];
        
        if ( self.manualLatitude < -66 || self.manualLatitude > 66 ) {
            NSLog(@"clearing location prefs on manual latitude within ant/arctic circles: %0.2f",self.manualLatitude);
            [self _clearLocationPreferences];
        }
    }
    
    return self;
}

- (void)save
{
    NSUserDefaults *df = [NSUserDefaults standardUserDefaults];
    [df setBool:self.locationPreferenceGathered forKey:LocationPreferenceGathered];
    [df setBool:self.useManualLocation forKey:UseManualLocation];
    [df setDouble:self.manualLatitude forKey:ManualLatitude];
    [df setDouble:self.manualLongitude forKey:ManualLongitude];
    [df setDouble:self.lastLSLatitude forKey:LastLSLatitude];
    [df setDouble:self.lastLSLongitude forKey:LastLSLongitude];
    [df setDouble:[self.lastLocationServicesRequested timeIntervalSince1970] forKey:LastLocationServicesRequested];
    [df setInteger:self.lastLocationServicesStatus forKey:LastLocationServicesStatus];
    
    [df synchronize];
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
            formatUnit = wholeUntilSabbath > 1 ? @"days" : @"day";
        }
    }
    
    content.title = [NSString stringWithFormat:@"Sabbath in %d %@!",formatValue,formatUnit];
    content.body = [NSString stringWithFormat:@"Begins %@.",[nextSabbath notificationPresentationString]];
    if ( ! delay ) delay = 0.01;
    UNNotificationTrigger *trigger = [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:delay repeats:NO];
    UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:myId content:content trigger:trigger];
    [center addNotificationRequest:request withCompletionHandler:^(NSError * _Nullable error) {
        NSLog(@"notification '%@ / %@' completed with result: %@",content.title,content.body,error);
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

- (void)requestLocationAuthorization:(void (^)(BOOL))callback
{
    if ( ! self.locationManager )
        self.locationManager = [CLLocationManager new];
    
    NSLog(@"manager auth status: %d",self.locationManager.authorizationStatus);
    
    // kCLAuthorizationStatusRestricted ls can't be used, user cannot change
#warning this should factor into alert construction
    // kCLAuthorizationStatusDenied user denied this application, or ls is disabled
    if ( self.locationManager.authorizationStatus == kCLAuthorizationStatusDenied || self.locationManager.authorizationStatus == kCLAuthorizationStatusRestricted ) {
        NSLog(@"location services DENIED!");
        callback(NO);
        return;
    }
    
    else if ( self.locationManager.authorizationStatus == kCLAuthorizationStatusAuthorizedAlways || self.locationManager.authorizationStatus == kCLAuthorizationStatusAuthorizedWhenInUse
#ifdef __MAC_OS_X_VERSION_MAX_ALLOWED
        || self.locationManager.authorizationStatus == kCLAuthorizationStatusAuthorized
#endif
        ) {
        NSLog(@"short-circuiting loc auth request (%d, %@)",self.locationManager.authorizationStatus,self.locationManager.location);
        ST.lastLSLatitude = [self.locationManager location].coordinate.latitude;
        ST.lastLSLongitude = [self.locationManager location].coordinate.longitude;
        [ST save];
        callback(YES);
        return;
    }
    
    else if ( self.locationManager.authorizationStatus == kCLAuthorizationStatusNotDetermined ) {
        self.locationAuthCallback = callback;
        
        NSUserDefaults *df = [NSUserDefaults standardUserDefaults];
        NSLog(@"requesting location authorization, current %d last: %ld",self.locationManager.authorizationStatus,[df integerForKey:LastLocationServicesStatus]);
        [df setDouble:[[NSDate date] timeIntervalSince1970] forKey:LastLocationServicesRequested];
        [df synchronize];
        
        self.locationManager.delegate = self;
        //-requestTemporaryFullAccuracyAuthorizationWithPurposeKey:completion:
        [self.locationManager requestWhenInUseAuthorization];
    }
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(nonnull NSError *)error
{
    NSLog(@"location manager failed with error! %@",error);
}

- (void)locationManager:(CLLocationManager *)manager
     didUpdateLocations:(NSArray<CLLocation *> *)locations
{
    NSLog(@"location manager did update locations! %@",locations);
    [self _locationCallback:manager];
}

- (void)locationManagerDidChangeAuthorization:(CLLocationManager *)manager
{
    NSLog(@"location manager did change authorization! %d",manager.authorizationStatus);
    [self _locationCallback:manager];
}

static dispatch_once_t elOnce = 0;

- (void)_locationCallback:(CLLocationManager *)manager
{
    NSUserDefaults *df = [NSUserDefaults standardUserDefaults];
    [df setInteger:manager.authorizationStatus forKey:LastLocationServicesStatus];
    [df synchronize];
    
    BOOL okay = NO;
    elOnce = 0;
    
    if ( manager.authorizationStatus == kCLAuthorizationStatusAuthorizedAlways
#ifndef __MAC_OS_X_VERSION_MAX_ALLOWED
        || manager.authorizationStatus == kCLAuthorizationStatusAuthorizedWhenInUse
#endif
        ) {
        NSLog(@"location authorized: %@",manager.location);
        ST.lastLSLatitude = [manager location].coordinate.latitude;
        ST.lastLSLongitude = [manager location].coordinate.longitude;
        [ST save];
        okay = YES;
    } else
        NSLog(@"location not authorized: %d (%@)",manager.authorizationStatus,manager.location);
    
    if ( manager.authorizationStatus != kCLAuthorizationStatusNotDetermined ) {
        if ( self.locationAuthCallback )
            self.locationAuthCallback(okay);
    }
}

- (CLLocation *)effectiveLocation
{
    CLLocation *effectiveLocation = nil;
    if ( self.useManualLocation ) {
        effectiveLocation = [[CLLocation alloc] initWithLatitude:self.manualLatitude longitude:self.manualLongitude];
        dispatch_once(&elOnce, ^{
            NSLog(@"effectiveLocation (manual) %@",effectiveLocation);
        });
        return effectiveLocation;
    }
    
    effectiveLocation = [[CLLocation alloc] initWithLatitude:ST.lastLSLatitude longitude:ST.lastLSLongitude];
    dispatch_once(&elOnce, ^{
        NSLog(@"effectiveLocation (ls) %@",effectiveLocation);
    });
    return effectiveLocation;
    //return [[CLLocation alloc] initWithLatitude:38.63 longitude:-90.20];
}

- (void)_clearLocationPreferences
{
    NSUserDefaults *dp = [NSUserDefaults standardUserDefaults];
    [dp removeObjectForKey:LocationPreferenceGathered];
    self.locationPreferenceGathered = NO;
    [dp removeObjectForKey:UseManualLocation];
    self.useManualLocation = NO;
    [dp removeObjectForKey:ManualLatitude];
    self.manualLatitude = NAN;
    [dp removeObjectForKey:ManualLongitude];
    self.manualLongitude = NAN;
    [dp removeObjectForKey:LastLSLatitude];
    self.lastLSLatitude = NAN;
    [dp removeObjectForKey:LastLSLongitude];
    self.lastLSLongitude = NAN;
    [dp removeObjectForKey:LastLocationServicesStatus];
    self.lastLocationServicesStatus = 0;
    [dp removeObjectForKey:LastLocationServicesRequested];
    self.lastLocationServicesRequested = 0;
    
    elOnce = 0;
    
    [dp synchronize];
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
