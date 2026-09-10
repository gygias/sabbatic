//
//  STGreetingView.m
//  Sabbatic
//
//  Created by david on 3/17/26.
//

#import "STGreetingView.h"

NS_ASSUME_NONNULL_BEGIN

@implementation STGreetingView

- (NSInteger)_fontSizeForViewWidth:(CGFloat)width
{
    return 30 + ( width / STFontSizeScalar );
}

- (void)drawRect:(CGRect)rect
{
    NSMutableParagraphStyle *paragraphStyle = NSMutableParagraphStyle.new;
    paragraphStyle.alignment                = NSTextAlignmentCenter;
    
    NSDictionary *attrs = @{ NSForegroundColorAttributeName : [STColorClass redColor],
                             NSFontAttributeName : [STFontClass systemFontOfSize:[self _fontSizeForViewWidth:rect.size.width]],
                             NSParagraphStyleAttributeName : paragraphStyle };
    
    [@"שַׁבָּתשָׁלוֹם" drawInRect:rect withAttributes:attrs];
}

@end

NS_ASSUME_NONNULL_END
