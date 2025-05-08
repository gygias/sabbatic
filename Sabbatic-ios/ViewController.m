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
@property (strong) UIActivityIndicatorView *progressView;
@property BOOL currentViewLoaded;
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

- (void)_addCalendarView
{
    [self _startProgressOnCalendarChange];
    self.currentViewLoaded = NO;
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [self.calendarView preload];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.currentViewLoaded = YES;
            [self.progressView stopAnimating];
            [self.view addSubview:self.calendarView];
        });
    });
}

- (void)_replaceCurrentCalendarWithDate:(NSDate *)date :(BOOL)up
{
    NSTimeInterval duration = STCalendarAnimationDuration;
    
    STCalendarView *oldCalendar = self.calendarView;
    
    [UIView animateWithDuration:duration delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        oldCalendar.frame = CGRectMake(oldCalendar.frame.origin.x,
                                       oldCalendar.frame.origin.y + ( up ? -1 : 1 ) * self.view.frame.size.height,
                                       oldCalendar.frame.size.width, oldCalendar.frame.size.height);
        oldCalendar.layer.opacity = 0;
    } completion:^(BOOL finished) {
        NSLog(@"old calendar animated out");
    }];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(duration * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [oldCalendar removeFromSuperview];
        
        self.calendarView = [[STCalendarView alloc] initWithFrame:CGRectInset([self.view frame], STCalendarViewInsetX, STCalendarViewInsetY)];
        self.calendarView.effectiveNewMoonStart = date;
        self.calendarView.backgroundColor = [STColorClass clearColor];
        //self.calendarView.layer.opaque = 0.0;
        [self _addCalendarView];
        
        [UIView animateWithDuration:duration delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            //self.calendarView.layer.opaque = 1.0;
        } completion:^(BOOL finished) {
            NSLog(@"new calendar animated in");
        }];
    });
}

- (void)handleGesture:(UIGestureRecognizer *)gestureRecognizer
{
    if ( [gestureRecognizer isKindOfClass:[UISwipeGestureRecognizer class]] ) {
        UISwipeGestureRecognizer *swipe = (UISwipeGestureRecognizer *)gestureRecognizer;
        if ( swipe.direction == UISwipeGestureRecognizerDirectionDown ) {
            
            NSDate *currentNewMoon = self.calendarView.effectiveNewMoonStart;
            NSDate *lastConj = [DP conjunctionPriorToDate:currentNewMoon];
            NSDate *lastLastConj = [DP conjunctionPriorToDate:[lastConj dateByAddingTimeInterval:-STSecondsPerGregorianDay]];
            NSDate *previousNewMoonStart = [STCalendar newMoonStartTimeForConjunction:lastLastConj :NULL];
            
            NSLog(@"swipe down, switching from %@ to %@",currentNewMoon,previousNewMoonStart);
            [self _replaceCurrentCalendarWithDate:previousNewMoonStart :NO];
        } else if ( swipe.direction == UISwipeGestureRecognizerDirectionUp ) {
            
            NSDate *currentNewMoon = self.calendarView.effectiveNewMoonStart;
            NSDate *nextConj = [DP conjunctionAfterDate:currentNewMoon];
            NSDate *nextNewMoonStart = [STCalendar newMoonStartTimeForConjunction:nextConj :NULL];
            
            NSLog(@"swipe up, switching from %@ to %@",currentNewMoon,nextNewMoonStart);
            [self _replaceCurrentCalendarWithDate:nextNewMoonStart :YES];
        }
    }
}

- (void)_startProgressOnCalendarChange
{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(STCalendarAnimationDuration * 4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if ( ! self.currentViewLoaded ) {
            [self.progressView startAnimating];
        }
    });
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [[STState state] setDataProvider:[[STDataProviderClass alloc] init]];
    
    UISwipeGestureRecognizer *up = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleGesture:)];
    up.direction = UISwipeGestureRecognizerDirectionUp;
    UISwipeGestureRecognizer *down = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleGesture:)];
    down.direction = UISwipeGestureRecognizerDirectionDown;
    self.view.gestureRecognizers = @[ up, down ];
    
    CGRect progressFrame = CGRectMake([self.view frame].origin.x + [self.view frame].size.width / 2 - STSpinnerWidth / 2,
                                      [self.view frame].origin.y + 4 * ( [self.view frame].size.height / 5 ) - STSpinnerWidth / 2,
                                      STSpinnerWidth, STSpinnerHeight
                                      );
    
    SCNView *moonView = [[SCNView alloc] initWithFrame:[self.view frame] options:NULL];
    self.moonController = [[STMoonController alloc] initWithView:moonView];
    [self.view addSubview:moonView];
    
    self.progressView = [[UIActivityIndicatorView alloc] initWithFrame:progressFrame];
    self.progressView.activityIndicatorViewStyle = UIActivityIndicatorViewStyleLarge;
    self.progressView.color = [STColorClass whiteColor];
    self.progressView.hidesWhenStopped = YES;
    [self.view addSubview:self.progressView];
    
    self.calendarView = [[STCalendarView alloc] initWithFrame:CGRectInset([self.view frame], STCalendarViewInsetX, STCalendarViewInsetY)];
    self.calendarView.effectiveNewMoonStart = [DP lastNewMoonStart];
    self.calendarView.backgroundColor = [STColorClass clearColor];
    //self.calendarView.layer.opaque = 0.5;
    [self _addCalendarView];
    
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
