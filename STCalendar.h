//
//  STCalendar.h
//  Sabbatic
//
//  Created by david on 3/20/25.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface STCalendar : NSObject

+ (BOOL)isDateBetweenSunsetAndGregorianMidnight:(NSDate *)date;
+ (BOOL)isDateInGregorianToday:(NSDate *)date;
+ (BOOL)isDateInLunarToday:(NSDate *)date;
+ (BOOL)isDateInLunarYesterday:(NSDate *)date;

+ (NSDate *)newMoonDayForConjunction:(NSDate *)date; // gregorian midnight on new moon day
+ (NSDate *)newMoonStartTimeForConjunction:(NSDate *)date; // sunset on previous day

+ (NSDate *)lastNewMoonForDate:(NSDate *)date;

+ (NSDate *)date:(NSDate *)date byAddingDays:(NSInteger)days hours:(NSInteger)hours minutes:(NSInteger)minutes seconds:(NSInteger)seconds;
+ (NSString *)localGregorianDayOfTheMonthFromDate:(NSDate *)date;
+ (NSString *)localGregorianPreviousAndCurrentDayFromDate:(NSDate *)date delimiter:(NSString *)delimiter;

+ (NSString *)hebrewStringMonthForMonth:(NSInteger)month;
+ (NSString *)moedStringForLunarDay:(NSInteger)day ofLunarMonth:(NSInteger)month;

@end

NS_ASSUME_NONNULL_END
