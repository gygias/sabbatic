//
//  AppDelegate.m
//  Sabbatic
//
//  Created by david on 3/20/25.
//

#import "AppDelegate.h"

#import "STViewController.h"

@interface AppDelegate ()

@property (strong) IBOutlet NSWindow *window;
@property (strong) STViewController *vc;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    
    self.vc = [[STViewController alloc] init];
    self.vc.view = self.window.contentView;
    [self.vc viewDidLoad];
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}


- (BOOL)applicationSupportsSecureRestorableState:(NSApplication *)app {
    return YES;
}


@end
