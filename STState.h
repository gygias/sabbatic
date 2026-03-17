//
//  STState.h
//  Sabbatic
//
//  Created by david on 4/16/25.
//

#import <CoreLocation/CLLocationManagerDelegate.h>

#import "STDataProvider.h"
#import "STUSNODataProvider.h"
#import "STAstronomyProvider.h"

#ifndef STState_h
#define STState_h

#define ST [STState state]
#define DP [ST dataProvider]

NS_ASSUME_NONNULL_BEGIN

@interface STState : NSObject <CLLocationManagerDelegate>
{
    id<STDataProvider> _dataProvider;
}

+ (STState *)state;
- (void)save;

@property BOOL locationPreferenceGathered;
@property BOOL useManualLocation;
@property double manualLatitude;
@property double manualLongitude;
@property double lastLSLatitude;
@property double lastLSLongitude;

- (void)requestLocationAuthorization:(void (^)(BOOL))callback;
- (CLLocation *)effectiveLocation;
- (void)_clearLocationPreferences;

- (void)requestNotificationApprovalWithDelay:(NSTimeInterval)delay;
- (void)sendSabbathNotificationWithDelay:(NSTimeInterval)delay;

- (void)setDataProvider:(id<STDataProvider>)dataProvider;
- (id<STDataProvider>)dataProvider;

@end

NS_ASSUME_NONNULL_END

#endif /* STState_h */
