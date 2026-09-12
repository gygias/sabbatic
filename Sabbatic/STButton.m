//
//  STButton.m
//  Sabbatic
//
//  Created by david on 9/12/26.
//

#import "STButton.h"

NS_ASSUME_NONNULL_BEGIN

@interface STButton ()
@property (copy) STButtonHandler handler;
@end

@implementation STButton

+ (id)buttonWithImage:(NSImage *)image handler:(STButtonHandler)handler
{
    STButton *button;
    if ( ( button = [STButton buttonWithImage:image target:self action:@selector(action:)] ) )
    {
        button.handler = handler;
    }
    return button;
}

+ (id)buttonWithTitle:(NSString *)title handler:(STButtonHandler)handler
{
    STButton *button;    
    if ( ( button = [STButton buttonWithTitle:title target:self action:@selector(action:)] ) )
    {
        button.handler = handler;
    }
    return button;
}

+ (void)action:(NSButton *)button
{
    STButton *stButton = (STButton *)button;
    if ( stButton.handler )
        stButton.handler(stButton);
}

@end

NS_ASSUME_NONNULL_END
