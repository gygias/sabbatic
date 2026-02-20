//
//  STCalendarView.h
//  Sabbatic
//
//  Created by david on 3/20/25.
//

#import "STDefines.h"

NS_ASSUME_NONNULL_BEGIN

@interface STCalendarView : STViewSuper

@property (strong) NSDate *effectiveNewMoonStart;
@property void (^moveUpHandler)(void);
@property void (^moveDownHandler)(void);

- (void)preload;

@end

NS_ASSUME_NONNULL_END
