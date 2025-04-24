//
//  AppDelegate.m
//  Sabbatic
//
//  Created by david on 3/20/25.
//

#import "AppDelegate.h"

#import <SceneKit/SceneKit.h>

#import "STCalendarView.h"

@interface AppDelegate ()

@property (strong) IBOutlet NSWindow *window;
@property (strong) SCNView *moonView;
@property (strong) NSView *calendarView;
@property (strong) SCNNode *lightNode;
@end

@implementation AppDelegate

#define idx_0 SCNVector3Make(0, 0, 5) // full moon (camera position)
#define idx_1 SCNVector3Make(-5, 0, 0)
#define idx_2 SCNVector3Make(0, 0, -5) // new moon
#define idx_3 SCNVector3Make(5, 0, 0)

- (void)animateTo:(NSInteger)idx
{
    [SCNTransaction begin];
    [SCNTransaction setAnimationDuration:1];
    [SCNTransaction setAnimationTimingFunction:[CAMediaTimingFunction functionWithName:@"linear"]];
    // does not work in a switch statement
    if ( idx == 0 )
        self.lightNode.position = idx_0;
    else if ( idx == 1 )
        self.lightNode.position = idx_1;
    else if ( idx == 2 )
        self.lightNode.position = idx_2;
    else if ( idx == 3 )
        self.lightNode.position = idx_3;
    [SCNTransaction setCompletionBlock:^{
        //NSLog(@"an animation to %ld completed! %@", idx, [NSThread currentThread]);
        [self animateTo:idx == 3 ? 0 : idx + 1];
    }];
    [SCNTransaction commit];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
    
    self.calendarView = [[STCalendarView alloc] initWithFrame:CGRectInset([self.window.contentView frame], 50, 50)];
    [self.window.contentView addSubview:self.calendarView];
    self.calendarView.layer.opaque = 0.5;
    
    self.moonView = [[SCNView alloc] initWithFrame:CGRectInset([self.window.contentView frame], 10, 10) options:NULL];
    self.moonView.layer.opacity = 0.5;
    [self.window.contentView addSubview:self.moonView];
    
    //view.scene = [SCNScene sceneNamed:@"moon.dae"];
    self.moonView.scene = [SCNScene sceneNamed:@"MoonScene.scn"];
    
    SCNLight *light = [SCNLight new];
    light.type = SCNLightTypeOmni;
    light.intensity = 2000;
    light.color = [NSColor redColor];
    
    self.lightNode = [SCNNode new];
    self.lightNode.position = idx_2;
    self.lightNode.light = light;
    
    [self.moonView.scene.rootNode addChildNode:self.lightNode];
    
    self.moonView.rendersContinuously = YES;
    //view.allowsCameraControl = YES;
    //view.autoenablesDefaultLighting = YES;
    //[self.window.contentView setNeedsDisplay:YES];
    
    [self animateTo:3];
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}


- (BOOL)applicationSupportsSecureRestorableState:(NSApplication *)app {
    return YES;
}


@end
