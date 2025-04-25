//
//  STMoonController.m
//  Sabbatic
//
//  Created by david on 4/25/25.
//

#import "STMoonController.h"
#import "STDefines.h"
#import "STState.h"

@interface STMoonController ()
@property (strong) SCNView *moonView;
@property (strong) SCNNode *lightNode;
@end

@implementation STMoonController

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
    else if ( idx == 2 ) {
        BOOL waning = NO;
        double fracillum = [[STState state] currentMoonFracillum:&waning];
        NSLog(@"Now I would like to animate to %0.2f %@",fracillum,waning?@"waning":@"waxing");
        self.lightNode.position = idx_2;
    } else if ( idx == 3 )
        self.lightNode.position = idx_3;
    [SCNTransaction setCompletionBlock:^{
        //NSLog(@"an animation to %ld completed! %@", idx, [NSThread currentThread]);
        [self animateTo:idx == 3 ? 0 : idx + 1];
    }];
    [SCNTransaction commit];
}

- (id)initWithView:(SCNView *)view
{
    if ( self = [super init] ) {
        
        self.moonView = view;
        self.moonView.layer.opacity = 0.5;
        
        //view.scene = [SCNScene sceneNamed:@"moon.dae"];
        self.moonView.scene = [SCNScene sceneNamed:@"MoonScene.scn"];
        
        SCNLight *light = [SCNLight new];
        light.type = SCNLightTypeOmni;
        light.intensity = 2000;
        light.color = [STColorClass redColor];
        
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

    return self;
}

@end
