//
//  STView.m
//  Sabbatic
//
//  Created by david on 2/20/26.
//

#import "STView.h"

NS_ASSUME_NONNULL_BEGIN

@implementation STView

- (void)iNeedDisplay
{
#ifdef STMacOS
    [self setNeedsDisplay:YES];
#else
    [self setNeedsDisplay];
#endif
}

@end

NS_ASSUME_NONNULL_END
