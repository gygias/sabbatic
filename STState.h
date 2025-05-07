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
- (double)moonFracillumForDate:(NSDate *)date :(BOOL *)waning;

- (NSDate *)lastConjunction;
- (NSDate *)nextConjunction;
- (NSDate *)conjunctionPriorToDate:(NSDate *)date;
- (NSDate *)conjunctionAfterDate:(NSDate *)date;
- (NSDate *)lastNewMoonStart; // sunset on previous solar day
- (NSDate *)nextNewMoonStart; // sunset on previous solar day
- (NSDate *)lastNewMoonDay; // midnight on new moon day
- (NSDate *)nextNewMoonDay; // midnight on new moon day
- (NSDate *)lastNewYear;
- (NSDate *)lastNewYearForDate:(NSDate *)date;
- (NSInteger)currentLunarMonth;
- (NSInteger)lunarMonthForDate:(NSDate *)date;
- (NSDate *)lastSabbath:(BOOL)momentAfter;
- (NSDate *)nextSabbath:(BOOL)momentAfter;
// as there is probably no meaningful authority on this, for purposes of delimiting lunar days, we chose to make the "moment" after sunset (currently 1 second)
// the first that belongs to the new day, and as a convenience and reminder provide it in sunset-related functions
- (NSDate *)lastSunset:(BOOL)momentAfter;
- (NSDate *)nextSunset:(BOOL)momentAfter;
- (NSDate *)lastSunsetForDate:(NSDate *)date momentAfter:(BOOL)momentAfter;
- (NSDate *)nextSunsetForDate:(NSDate *)date momentAfter:(BOOL)momentAfter;

- (void)requestNotificationApprovalWithDelay:(NSTimeInterval)delay;

- (void)sendSabbathNotificationWithDelay:(NSTimeInterval)delay;

@end

NS_ASSUME_NONNULL_END

#endif /* STState_h */
