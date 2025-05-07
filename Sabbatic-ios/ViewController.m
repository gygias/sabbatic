//
//  ViewController.m
//  Sabbatic-ios
//
//  Created by david on 3/20/25.
//

#import "ViewController.h"

#import <SceneKit/SceneKit.h>

#import "STCalendarView.h"
#import "STMoonController.h"
#import "STDefines.h"
#import "STState.h"

@interface ViewController ()
@property (strong) STMoonController *moonController;
@property (strong) UIView *calendarView;
@end

@implementation ViewController

- (void)_updatePhase
{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(STMoonRedrawInterval * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.moonController animateToCurrentPhaseWithCompletionHandler:^{
            [self _updatePhase];
        }];
    });
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    SCNView *moonView = [[SCNView alloc] initWithFrame:[self.view frame] options:NULL];
    self.moonController = [[STMoonController alloc] initWithView:moonView];
    [self.view addSubview:moonView];
    
    self.calendarView = [[STCalendarView alloc] initWithFrame:CGRectInset([self.view frame], STCalendarViewInsetX, STCalendarViewInsetY)];
    self.calendarView.backgroundColor = [STColorClass clearColor];
    //self.calendarView.layer.opaque = 0.5;
    [self.view addSubview:self.calendarView];
    
    [self.moonController doIntroAnimationWithCompletionHandler:^{
        NSLog(@"did intro animation");
        [self.moonController animateToCurrentPhaseWithCompletionHandler:^{
            NSLog(@"animated to current phase on app launch");
            [self _updatePhase];
        }];
    }];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:NSCalendarDayChangedNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull notification) {
        [self.calendarView setNeedsDisplay];
        [self.moonController animateToCurrentPhaseWithCompletionHandler:^{
            NSLog(@"animated to current phase on day change");
        }];
        
        [[STState state] sendSabbathNotificationWithDelay:STSecondsPerGregorianDay / 2.];
    }];
    [[NSNotificationCenter defaultCenter] addObserverForName:NSSystemClockDidChangeNotification object:nil queue:[NSOperationQueue mainQueue]  usingBlock:^(NSNotification * _Nonnull notification) {
        NSLog(@"NSSystemClockDidChangeNotification!");
        [self.calendarView setNeedsDisplay];
        [self.moonController animateToCurrentPhaseWithCompletionHandler:^{
            NSLog(@"animated to current phase on clock change");
        }];
        
        [[STState state] sendSabbathNotificationWithDelay:0];
    }];
    
    [[STState state] requestNotificationApprovalWithDelay:STNotificationRequestDelay];
}


@end
