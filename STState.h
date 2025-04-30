//
//  STState.h
//  Sabbatic
//
//  Created by david on 4/16/25.
//

#import <CoreLocation/CLLocationManagerDelegate.h>

#ifndef STState_h
#define STState_h

NS_ASSUME_NONNULL_BEGIN

@interface STState : NSObject <CLLocationManagerDelegate>
{
    CLLocation *_location;
}

+ (id)state;

- (double)currentMoonFracillum:(BOOL *)waning;

- (NSDate *)lastConjunction;
- (NSDate *)nextConjunction;
- (NSDate *)lastNewMoonStart; // sunset on previous solar day
- (NSDate *)nextNewMoonStart; // sunset on previous solar day
- (NSDate *)lastNewMoonDay; // midnight on new moon day
- (NSDate *)nextNewMoonDay; // midnight on new moon day
- (NSDate *)lastNewYear;
- (NSInteger)currentLunarMonth;
- (NSDate *)lastSabbath;
- (NSDate *)nextSabbath;
- (NSDate *)lastSunset;
- (NSDate *)nextSunset;
- (NSDate *)sunsetOnDate:(NSDate *)date;

- (NSDate *)normalizeDate:(NSDate *)date; // returns midnight on same calendar date
- (NSDate *)normalizeDate:(NSDate *)date hour:(NSInteger)hour minute:(NSInteger)minute; // returns midnight on same calendar date

- (void)requestNotificationApproval;

@end

NS_ASSUME_NONNULL_END

#endif /* STState_h */
