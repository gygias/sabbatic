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

@interface AppDelegate ()

@property (strong) IBOutlet NSWindow *window;
@property (strong) STMoonController *moonController;
@property (strong) NSView *calendarView;
@property (strong) SCNNode *lightNode;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
    
    self.calendarView = [[STCalendarView alloc] initWithFrame:CGRectInset([self.window.contentView frame], 50, 50)];
    [self.window.contentView addSubview:self.calendarView];
    self.calendarView.layer.opaque = 0.5;
    
    SCNView *moonView = [[SCNView alloc] initWithFrame:CGRectInset([self.window.contentView frame], 10, 10) options:NULL];
    self.moonController = [[STMoonController alloc] initWithView:moonView];
    [self.window.contentView addSubview:moonView];
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}


- (BOOL)applicationSupportsSecureRestorableState:(NSApplication *)app {
    return YES;
}


@end
