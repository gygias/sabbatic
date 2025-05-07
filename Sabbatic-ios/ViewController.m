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
#import "STCalendar.h"

@interface ViewController ()
@property (strong) STMoonController *moonController;
@property (strong) STCalendarView *calendarView;
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

- (void)_replaceCurrentCalendarWithDate:(NSDate *)date
{
    NSTimeInterval duration = 0;
    
    STCalendarView *oldCalendar = self.calendarView;
    CABasicAnimation *a = [CABasicAnimation animationWithKeyPath:@"opacity"];
    a.toValue = @0;
    a.duration = duration;
    a.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
    [oldCalendar.layer addAnimation:a forKey:@"opacity"];
    oldCalendar.layer.opacity = 0;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(duration * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [oldCalendar removeFromSuperview];
    });
    
    
    self.calendarView = [[STCalendarView alloc] initWithFrame:CGRectInset([self.view frame], STCalendarViewInsetX, STCalendarViewInsetY)];
    self.calendarView.effectiveNewMoonStart = date;
    self.calendarView.backgroundColor = [STColorClass clearColor];
    //self.calendarView.layer.opaque = 0.5;
    [self.view addSubview:self.calendarView];
    
    /*[CATransaction begin];
    [CATransaction setAnimationDuration:1];
    [CATransaction setCompletionBlock:^{
        NSLog(@"fade out completed");
    }];
    self.calendarView.layer.opacity = 0;
    [CATransaction commit];*/
}

- (void)handleGesture:(UIGestureRecognizer *)gestureRecognizer
{
    if ( [gestureRecognizer isKindOfClass:[UISwipeGestureRecognizer class]] ) {
        UISwipeGestureRecognizer *swipe = (UISwipeGestureRecognizer *)gestureRecognizer;
        if ( swipe.direction == UISwipeGestureRecognizerDirectionDown ) {
            
            NSDate *currentNewMoon = self.calendarView.effectiveNewMoonStart;
            NSDate *lastConj = [[STState state] conjunctionPriorToDate:currentNewMoon];
            NSDate *lastLastConj = [[STState state] conjunctionPriorToDate:lastConj];
            NSDate *previousNewMoonStart = [STCalendar newMoonStartTimeForConjunction:lastLastConj :NULL];
            
            NSLog(@"swipe down, switching from %@ to %@",currentNewMoon,previousNewMoonStart);
            [self _replaceCurrentCalendarWithDate:previousNewMoonStart];
        } else if ( swipe.direction == UISwipeGestureRecognizerDirectionUp ) {
            
            NSDate *currentNewMoon = self.calendarView.effectiveNewMoonStart;
            NSDate *nextConj = [[STState state] conjunctionAfterDate:currentNewMoon];
            NSDate *nextNewMoonStart = [STCalendar newMoonStartTimeForConjunction:nextConj :NULL];
            
            NSLog(@"swipe up, switching from %@ to %@",currentNewMoon,nextNewMoonStart);
            [self _replaceCurrentCalendarWithDate:nextNewMoonStart];
        }
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    UISwipeGestureRecognizer *up = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleGesture:)];
    up.direction = UISwipeGestureRecognizerDirectionUp;
    UISwipeGestureRecognizer *down = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleGesture:)];
    down.direction = UISwipeGestureRecognizerDirectionDown;
    self.view.gestureRecognizers = @[ up, down ];
    
    SCNView *moonView = [[SCNView alloc] initWithFrame:[self.view frame] options:NULL];
    self.moonController = [[STMoonController alloc] initWithView:moonView];
    [self.view addSubview:moonView];
    
    self.calendarView = [[STCalendarView alloc] initWithFrame:CGRectInset([self.view frame], STCalendarViewInsetX, STCalendarViewInsetY)];
    self.calendarView.effectiveNewMoonStart = [[STState state] lastNewMoonStart];
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
