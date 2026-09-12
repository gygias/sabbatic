//
//  STButton.h
//  Sabbatic
//
//  Created by david on 9/12/26.
//

#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^STButtonHandler)(NSButton *button);

@interface STButton : NSButton

+ (id)buttonWithTitle:(NSString *)title handler:(STButtonHandler)handler;

@end

NS_ASSUME_NONNULL_END
