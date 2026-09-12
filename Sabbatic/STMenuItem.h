//
//  STMenuItem.h
//  Sabbatic
//
//  Created by david on 9/12/26.
//

#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^STMenuItemHandler)(NSMenuItem *item);

@interface STMenuItem : NSMenuItem

+ (id)itemWithTitle:(NSString *)title image:(NSImage *)image handler:(STMenuItemHandler)handler;

@end

NS_ASSUME_NONNULL_END
