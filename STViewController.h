//
//  STViewController.h
//  Sabbatic
//
//  Created by david on 3/20/25.
//

#if !__has_include(<UIKit/UIKit.h>)
#import <Cocoa/Cocoa.h>
#define STButton NSButton
#else
#import <UIKit/UIKit.h>
#define STButton UIButton
#endif

#import "STDefines.h"

@interface STViewController : STViewControllerClass
#if __has_include(<UIKit/UIKit.h>)
                                                    <UIGestureRecognizerDelegate>
#endif


@end

