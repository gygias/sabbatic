//
//  NSDate+MyNow.h
//  Sabbatic
//
//  Created by david on 4/23/25.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSDate (NSDate_MyNow)

+ (void)setMyNow:(NSDate *)date;
+ (NSDate *)myNow;

- (BOOL)isWithinAbsoluteTimeInterval:(NSTimeInterval)interval ofDate:(NSDate *)date;

- (NSString *)localYearMonthDayString;
- (NSString *)localYearMonthDayHourMinuteString;

@end

NS_ASSUME_NONNULL_END
