//
//  AppDelegate.m
//  Sabbatic
//
//  Created by david on 3/20/25.
//

#import "AppDelegate.h"

#import <SceneKit/SceneKit.h>

#import "STCalendarView.h"
#import "STState.h"
#import "STMoonController.h"
#import "STDefines.h"

@interface AppDelegate ()

@property (strong) IBOutlet NSWindow *window;
@property (strong) STMoonController *moonController;
@property (strong) NSView *calendarView;
@property (strong) SCNNode *lightNode;
@end

@implementation AppDelegate

- (void)_updatePhase
{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(STMoonRedrawInterval * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.moonController animateToCurrentPhaseWithCompletionHandler:^{
            [self _updatePhase];
        }];
    });
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
        
    SCNView *moonView = [[SCNView alloc] initWithFrame:CGRectInset([self.window.contentView frame], 10, 10) options:NULL];
    self.moonController = [[STMoonController alloc] initWithView:moonView];
    [self.window.contentView addSubview:moonView];
    
    self.calendarView = [[STCalendarView alloc] initWithFrame:CGRectInset([self.window.contentView frame], STCalendarViewInset, STCalendarViewInset)];
    [self.window.contentView addSubview:self.calendarView];
    //self.calendarView.layer.opaque = 0.75;
    //self.calendarView.layer.backgroundColor = [NSColor clearColor].CGColor;
    
    //dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.moonController doIntroAnimationWithCompletionHandler:^{
            NSLog(@"did intro animation");
            [self.moonController animateToCurrentPhaseWithCompletionHandler:^{
                NSLog(@"animated to current phase on app launch");
                [self _updatePhase];
            }];
        }];
    //});
    
    [[NSNotificationCenter defaultCenter] addObserverForName:NSCalendarDayChangedNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull notification) {
        [self.calendarView setNeedsDisplay:YES];
        [self.moonController animateToCurrentPhaseWithCompletionHandler:^{
            NSLog(@"animated to current phase on day change");
        }];
        
        [[STState state] sendSabbathNotificationWithDelay:STSecondsPerGregorianDay / 2.];
    }];
    [[NSNotificationCenter defaultCenter] addObserverForName:NSSystemClockDidChangeNotification object:nil queue:[NSOperationQueue mainQueue]  usingBlock:^(NSNotification * _Nonnull notification) {
        NSLog(@"NSSystemClockDidChangeNotification!");
        [self.calendarView setNeedsDisplay:YES];
        [self.moonController animateToCurrentPhaseWithCompletionHandler:^{
            NSLog(@"animated to current phase on clock change");
        }];
        
        [[STState state] sendSabbathNotificationWithDelay:0];
    }];
    
    [[STState state] requestNotificationApprovalWithDelay:STNotificationRequestDelay];
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}


- (BOOL)applicationSupportsSecureRestorableState:(NSApplication *)app {
    return YES;
}


@end
