//
//  STCalendar.h
//  Sabbatic
//
//  Created by david on 3/20/25.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface STCalendar : NSCalendar // for isDateInToday override

+ (BOOL)isDateInToday:(NSDate *)date;
+ (BOOL)isDateInLunarToday:(NSDate *)date;

+ (NSDate *)newMoonDayForConjunction:(NSDate *)date; // gregorian midnight on new moon day
+ (NSDate *)newMoonStartTimeForConjunction:(NSDate *)date; // sunset on previous day

+ (NSDate *)date:(NSDate *)date byAddingDays:(NSInteger)days hours:(NSInteger)hours minutes:(NSInteger)minutes seconds:(NSInteger)seconds;
//+ (NSDate *)date:(NSDate *)date bySubtractingDays:(NSInteger) days;
+ (NSString *)localGregorianDayOfTheMonthFromDate:(NSDate *)date;

+ (NSString *)hebrewMonthForMonth:(NSInteger)month;

@end

NS_ASSUME_NONNULL_END
