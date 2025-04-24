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

- (NSDate *)lastConjunction;
- (NSDate *)nextConjunction;
- (NSDate *)lastNewMoonStart; // sunset on previous solar day
- (NSDate *)nextNewMoonStart; // sunset on previous solar day
- (NSDate *)lastNewMoon; // midnight on new moon day
- (NSDate *)nextNewMoon; // midnight on new moon day
- (NSDate *)lastNewYear;
- (NSInteger)lunarMonthsSinceDate:(NSDate *)date;
- (NSDate *)lastSabbath;
- (NSDate *)nextSabbath;
- (NSDate *)sunsetOnDate:(NSDate *)date;

- (NSDate *)normalizeDate:(NSDate *)date; // returns midnight on same calendar date
- (NSDate *)normalizeDate:(NSDate *)date hour:(NSInteger)hour minute:(NSInteger)minute; // returns midnight on same calendar date

- (void)requestNotificationApproval;

@end

NS_ASSUME_NONNULL_END

#endif /* STState_h */
