//
//  STMoonController.m
//  Sabbatic
//
//  Created by david on 4/25/25.
//

#import "STMoonController.h"
#import "STDefines.h"
#import "STState.h"

typedef enum
{
    None = 0,
    IntroAnimation = 1,
    AnimateTo = 2
} STMoonAnimationType;

@interface STMoonController ()
@property (strong) SCNView *moonView;
@property (strong) SCNNode *lightNode;
@property SCNVector3 originalCameraPosition;

@property NSInteger currentPhase;

@property STMoonAnimationType currentAnimationType;
@property double toFracillum;
@property BOOL waning;
@property (strong) void (^completionHandler)(void);
@end

@implementation STMoonController

#define introStartIdx 0

#define radius 5
#define librationScalar .3
#define halfLibrationScalar (librationScalar/2)
#define idx_0 SCNVector3Make(radius/2, 0, -radius) // new moon
#define idx_0_1 SCNVector3Make(-radius/2, 0, -radius)
#define cam_0 SCNVector3Make(0, 0, radius)
#define idx_1 SCNVector3Make(radius, 0, 0) // waxing half
#define cam_1 SCNVector3Make(librationScalar, -halfLibrationScalar, radius - librationScalar)
#define idx_2 SCNVector3Make(0, 0, radius) // full moon (camera position)
#define cam_2 SCNVector3Make(0, -librationScalar, radius - librationScalar*2)
#define idx_3 SCNVector3Make(-radius, 0, 0) // waning half
#define cam_3 SCNVector3Make(-librationScalar, -halfLibrationScalar, radius - librationScalar)

- (id)initWithView:(SCNView *)view
{
    if ( self = [super init] ) {
        
        self.moonView = view;
        self.moonView.layer.opacity = 0.5;
        
        //view.scene = [SCNScene sceneNamed:@"moon.dae"];
        self.moonView.scene = [SCNScene sceneNamed:@"MoonScene.scn"];
        
        SCNLight *light = [SCNLight new];
        light.type = SCNLightTypeOmni;
        light.intensity = 3000;
        light.color = [STColorClass whiteColor];
        
        self.lightNode = [SCNNode new];
        self.lightNode.position = idx_0;
        self.lightNode.light = light;
        
        [self.moonView.scene.rootNode addChildNode:self.lightNode];
        
        SCNCamera *camera = self.moonView.scene.rootNode.camera;
        self.originalCameraPosition = SCNVector3Make(self.moonView.pointOfView.position.x, self.moonView.pointOfView.position.y, self.moonView.pointOfView.position.z);
        NSLog(@"original camera position [%0.1fx,%0.1fy,%0.1fz]",self.originalCameraPosition.x,self.originalCameraPosition.y,self.originalCameraPosition.z);
        
        //self.moonView.rendersContinuously = YES;
        //view.allowsCameraControl = YES;
        //view.autoenablesDefaultLighting = YES;
        //[self.window.contentView setNeedsDisplay:YES];
        
    }

    return self;
}

- (void)_completeAndReset
{
    void (^myHandler)(void) = self.completionHandler;
    self.currentAnimationType = None;
    self.completionHandler = nil;
    myHandler();
}

- (void)_animateToPhase:(NSInteger)idx start:(BOOL)start
{
    if ( idx == 1 ) {
        self.lightNode.position = idx_0;
    }
    
    [SCNTransaction begin];
    [SCNTransaction setAnimationDuration:1];
    [SCNTransaction setAnimationTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear]];
    // does not work in a switch statement
    if ( idx == 0 ) {
        self.lightNode.position = idx_0_1;
        self.moonView.pointOfView.position = cam_0;
    } else if ( idx == 1 ) {
        self.lightNode.position = idx_1;
        self.moonView.pointOfView.position = cam_1;
    } else if ( idx == 2 ) {
        self.lightNode.position = idx_2;
        self.moonView.pointOfView.position = cam_2;
    } else if ( idx == 3 ) {
        self.lightNode.position = idx_3;
        self.moonView.pointOfView.position = cam_3;
    }
    [SCNTransaction setCompletionBlock:^{
        //NSLog(@"an animation to %ld completed!", idx);
        self.currentPhase = idx;
        
        if ( ! start ) {
            if ( ( self.currentAnimationType == IntroAnimation ) && ( idx == introStartIdx ) ) {
                [self _completeAndReset];
                //NSLog(@"intro animation ended at phase %ld",self.currentPhase);
                return;
            }
        }
        
        if ( self.currentAnimationType == AnimateTo )
            [self _updateCurrentPhaseAnimation];
        else
            [self _animateToPhase:idx == 3 ? 0 : idx + 1 start:NO];
    }];
    [SCNTransaction commit];
}

- (double)_shiftFracillum:(double)fracillum
{
    if ( fracillum < .03 )
        return fracillum;
    else if ( fracillum < .25 ) // using scene kit as we are, this seems to be the border of visibility
        fracillum = .25 + fracillum / 4;
    else if ( fracillum < .35 )
        fracillum = .35;
    return fracillum;
}

#define ScaleTwoVectors(s,e,p) SCNVector3Make(e.x*p + s.x*(1-p),e.y*p + s.y*(1-p),e.z*p + s.z*(1-p))

- (void)_animateBy:(double)fraction
{
    SCNVector3 byVector;
    SCNVector3 camVector;
    
    fraction = [self _shiftFracillum:fraction];
    if ( self.currentPhase == 0 ) {
        CGFloat twoFraction = fraction * 2;
        //byVector = SCNVector3Make( idx_1.x * twoFraction + idx_0.x * ( 1 - twoFraction ), 0, idx_0.z * ( 1 - twoFraction ) );
        //camVector = SCNVector3Make( cam_1.x * twoFraction + cam_0.x * ( 1 - twoFraction ), cam_1.y * twoFraction + cam_0.y * ( 1 - twoFraction ), cam_1.z * twoFraction + cam_0.z * ( 1 - twoFraction ));
        byVector = ScaleTwoVectors(idx_0, idx_1, twoFraction);
        camVector = ScaleTwoVectors(cam_0, cam_1, twoFraction);
    } else if ( self.currentPhase == 1 ) {
        CGFloat oneFraction = ( fraction - .5 ) / .5;
        //byVector = SCNVector3Make( idx_1.x * ( 1 - oneFraction ), 0, idx_2.z * oneFraction );
        //camVector = SCNVector3Make( cam_2.x * oneFraction + cam_1.x * ( 1 - oneFraction ), cam_2.y * oneFraction + cam_1.y * ( 1 - oneFraction ), cam_2.z * oneFraction + cam_1.x * ( 1 - oneFraction ) );
        byVector = ScaleTwoVectors(idx_1, idx_2, oneFraction);
        camVector = ScaleTwoVectors(cam_1, cam_2, oneFraction);
    } else if ( self.currentPhase == 2 ) {
        CGFloat oneFraction = ( fraction - .5 ) / .5;
        //byVector = SCNVector3Make( idx_3.x * ( 1 - oneFraction ), 0, idx_2.z * oneFraction );
        //NSLog(@"%0.2f * %0.2f = %0.2f",cam_3.z,oneFraction,cam_3.z*oneFraction);
        //camVector = SCNVector3Make( cam_3.x * oneFraction + cam_2.x * ( 1 - oneFraction ), cam_3.y * oneFraction + cam_2.y * ( 1 - oneFraction ), cam_3.z * oneFraction + cam_2.z * ( 1 - oneFraction ) );
        byVector = ScaleTwoVectors(idx_2, idx_3, oneFraction);
        camVector = ScaleTwoVectors(cam_2, cam_3, oneFraction);
    } else if ( self.currentPhase == 3 ) {
        CGFloat twoFraction = fraction * 2;
        //byVector = SCNVector3Make( idx_3.x * twoFraction + idx_0_1.x * ( 1 - twoFraction ), 0, idx_0_1.z * ( 1 - twoFraction ));
        //camVector = SCNVector3Make( cam_0.x * twoFraction + cam_3.x * ( 1 - twoFraction ), cam_0.y * twoFraction + cam_3.y * ( 1 - twoFraction ), cam_0.z * twoFraction + cam_3.z * ( 1 - twoFraction ) );
        byVector = ScaleTwoVectors(idx_0_1, idx_3, twoFraction);
        camVector = ScaleTwoVectors(cam_0, cam_3, twoFraction);
    } else
        return;
    
    NSLog(@"animating phase %ld to %0.2f [%0.2fx,%0.2fy,%0.2fz] camera [%0.2fx,%0.2fy,%0.2fz]",self.currentPhase,fraction,byVector.x,byVector.y,byVector.z,camVector.x,camVector.y,camVector.z);
    
    [SCNTransaction begin];
    [SCNTransaction setAnimationDuration:3];
    [SCNTransaction setAnimationTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut]];
    self.lightNode.position = byVector;
    self.moonView.pointOfView.position = camVector;
    [SCNTransaction setCompletionBlock:^{
        [self _completeAndReset];
    }];
    [SCNTransaction commit];
}

- (void)doIntroAnimationWithCompletionHandler:(void (^)(void))completionHandler
{
    if ( self.currentAnimationType != None ) {
        NSLog(@"bug: asked to doIntroAnimation while already animating, dropping.");
        return;
    }
    
    self.currentAnimationType = IntroAnimation;
    self.completionHandler = completionHandler;
    [self _animateToPhase:introStartIdx start:YES];
}

- (void)animateToCurrentPhaseWithCompletionHandler:(void (^)(void))completionHandler
{
    if ( self.currentAnimationType != None ) {
        NSLog(@"bug: asked to animateToCurrentPhase while already animating, dropping.");
        return;
    }
    
    BOOL waning = NO;
    double fracillum = [[STState state] currentMoonFracillum:&waning];
    NSLog(@"Now I would like to animate to %0.2f %@",fracillum,waning?@"waning":@"waxing");
    
    if ( self.currentPhase == 0 && fracillum == 0 ) {
        NSLog(@"already at new moon");
        return;
    } else if ( self.currentPhase == 3 && fracillum == .5 ) {
        NSLog(@"already at waning half");
        return;
    } else if ( self.currentPhase == 2 && fracillum == 1 ) {
        NSLog(@"already at full moon");
        return;
    }
    
    self.currentAnimationType = AnimateTo;
    self.completionHandler = completionHandler;
    self.toFracillum = fracillum;
    self.waning = waning;
    
    [self _updateCurrentPhaseAnimation];
}

- (void)_updateCurrentPhaseAnimation
{
    NSInteger baseIdx; // determine the phase this fracillum is 'after'
    if ( self.waning && self.toFracillum > .5 )
        baseIdx = 2;
    else if ( self.waning )
        baseIdx = 3;
    else if ( self.toFracillum < .5 )
        baseIdx = 0;
    else
        baseIdx = 1;
    
    if ( baseIdx == self.currentPhase )
        [self _animateBy:self.toFracillum];
    else
        [self _animateToPhase:( self.currentPhase + 1 ) % 4 start:YES];
}

#warning usno only gives fracillum for noon on a particular day
- (void)syntheticMoonPhaseCurve { }

@end
