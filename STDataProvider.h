//
//  STDataProvider.h
//  Sabbatic
//
//  Created by david on 5/7/25.
//

#ifndef STDataProvider_h
#define STDataProvider_h

#import <Foundation/Foundation.h>

@protocol STDataProvider <NSObject>

- (double)syntheticMoonPhaseCurve:(double)zeroThruOne;
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
// as there is probably no meaningful authority on this, for purposes of delimiting lunar days, we chose to make the "moment" after sunset (currently 1 microsecond)
// the first that belongs to the new day, and as a convenience and reminder provide it in sunset-related functions
- (NSDate *)lastSunset:(BOOL)momentAfter;
- (NSDate *)nextSunset:(BOOL)momentAfter;
- (NSDate *)lastSunsetForDate:(NSDate *)date momentAfter:(BOOL)momentAfter;
- (NSDate *)nextSunsetForDate:(NSDate *)date momentAfter:(BOOL)momentAfter;

@end

// for shared relevant stuff regardless of model
@interface STDataProvider : NSObject <STDataProvider>
@end


#endif /* STDataProvider_h */
