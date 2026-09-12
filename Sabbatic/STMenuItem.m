//
//  STMenuItem.m
//  Sabbatic
//
//  Created by david on 9/12/26.
//

#import "STMenuItem.h"

NS_ASSUME_NONNULL_BEGIN

@interface STMenuItem ()
@property (copy) STMenuItemHandler handler;
@end

@implementation STMenuItem

- (id)initWithTitle:(NSString *)title image:(NSImage *)image handler:(STMenuItemHandler)handler
{
    if ( self = [super initWithTitle:title action:@selector(action:) keyEquivalent:@""] )
    {
        self.target = self;
        self.image = image;
        self.handler = handler;
    }
    return self;
}

+ (id)itemWithTitle:(NSString *)title image:(NSImage *)image handler:(STMenuItemHandler)handler
{
    return [[STMenuItem alloc] initWithTitle:title image:image handler:handler];
}

- (void)action:(NSMenuItem *)item
{
    if ( self == item && self.handler )
        self.handler(item);
}

@end

NS_ASSUME_NONNULL_END
