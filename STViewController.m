//
//  STViewController.m
//  Sabbatic
//
//  Created by david on 3/20/25.
//

#import "STViewController.h"

#import <SceneKit/SceneKit.h>

#import "STCalendarView.h"
#import "STMoonController.h"
#import "STDefines.h"
#import "STState.h"
#import "STCalendar.h"
#import "NSDate+MyNow.h"

@interface STViewController ()
@property (strong) STMoonController *moonController;
@property (strong) STCalendarView *calendarView;
#ifndef __MAC_OS_X_VERSION_MAX_ALLOWED
@property (strong) UIActivityIndicatorView *progressView;
#endif
@property BOOL currentViewLoaded;
@end

@implementation STViewController

+ (void)initialize
{    
    [[STState state] setDataProvider:[[STDataProviderClass alloc] init]];
    
//#define MyNow
#define fast 0
#ifdef MyNow
    //NSDate *myNow = [STCalendar date:[DP lastNewMoonStart] byAddingDays:0 hours:0 minutes:0 seconds:-5];
    
    //NSDate *myNow = [NSDate myNow];
    NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    NSDate *myNow = [gregorian dateWithEra:1 year:2025 month:5 day:27 hour:20 minute:16 second:0 nanosecond:0];
    
    // yesterday 5 seconds to midnight
    //NSDate *myNow =   [STCalendar date:[DP normalizeDate:[STCalendar date:[NSDate date] byAddingDays:-1 hours:0 minutes:0 seconds:0]]
    //                      byAddingDays:0 hours:23 minutes:59 seconds:55];
    
    // today at x x x
    //NSDate *myNow =   [[NSDate date] normalizedDatePlusHour:19 minute:57 second:55];
    
    // 5 secs before last sunset
    //NSDate *myNow = [DP lastSunsetForDate:[NSDate myNow] momentAfter:YES];
    //myNow = [STCalendar date:myNow byAddingDays:0 hours:0 minutes:0 seconds:-5];
    
    // plain old now
    //NSDate *myNow = [NSDate myNow];
    
    // 15 days ago
    //NSDate *myNow = [STCalendar date:[NSDate date] byAddingDays:-15 hours:0 minutes:0 seconds:0];
    
    // 30 days from now
    //NSDate *myNow = [STCalendar date:[NSDate date] byAddingDays:30 hours:0 minutes:0 seconds:0];
    
    // 1 hour ago
    //NSDate *myNow = [STCalendar date:[NSDate date] byAddingDays:0 hours:-1 minutes:0 seconds:0];
    
    // 12 hours from now
    //NSDate *myNow = [STCalendar date:[NSDate date] byAddingDays:0 hours:12 minutes:0 seconds:0];
    
    [NSDate setMyNow:myNow realSecondsPerDay:fast];
#else
    [NSDate enqueueRealSunsetNotifications];
#endif
}

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
#ifndef __MAC_OS_X_VERSION_MAX_ALLOWED
    [self _startProgressOnCalendarChange];
#endif
    self.currentViewLoaded = NO;
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [self.calendarView preload];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.currentViewLoaded = YES;
#ifndef __MAC_OS_X_VERSION_MAX_ALLOWED
            [self.progressView stopAnimating];
#endif
            [self.view addSubview:self.calendarView];
#ifdef __MAC_OS_X_VERSION_MAX_ALLOWED
            [self.view.window makeFirstResponder:self.calendarView];
#endif
            
        });
    });
}

- (void)_replaceCurrentCalendarWithDate:(NSDate *)date :(BOOL)up
{
    STCalendarView *oldCalendar = self.calendarView;
    
#ifndef __MAC_OS_X_VERSION_MAX_ALLOWED
    NSTimeInterval duration = STCalendarAnimationDuration;
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
        [self _addCalendarViewWithDate:date];
        
        [UIView animateWithDuration:duration delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            //self.calendarView.layer.opaque = 1.0;
        } completion:^(BOOL finished) {
            NSLog(@"new calendar animated in");
        }];
    });
#else
    [oldCalendar removeFromSuperview];
    [self _addCalendarViewWithDate:date];    
#endif
}

#ifndef __MAC_OS_X_VERSION_MAX_ALLOWED
- (void)handleGesture:(UIGestureRecognizer *)gestureRecognizer
{
    if ( [gestureRecognizer isKindOfClass:[UISwipeGestureRecognizer class]] ) {
        UISwipeGestureRecognizer *swipe = (UISwipeGestureRecognizer *)gestureRecognizer;
        if ( swipe.direction == UISwipeGestureRecognizerDirectionDown ) {
            [self _moveUp];
        } else if ( swipe.direction == UISwipeGestureRecognizerDirectionUp ) {
            [self _moveDown];
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
#endif

- (void)_moveUp
{
    NSDate *currentNewMoon = self.calendarView.effectiveNewMoonStart;
    NSDate *lastConj = [DP conjunctionPriorToDate:currentNewMoon];
    NSDate *lastLastConj = [DP conjunctionPriorToDate:[lastConj dateByAddingTimeInterval:-( STSecondsPerGregorianDay * 2 )]];
    NSDate *previousNewMoonStart = [STCalendar newMoonStartTimeForConjunction:lastLastConj :NULL];
    
    NSLog(@"swipe down, switching from %@ to %@",currentNewMoon,previousNewMoonStart);
    [self _replaceCurrentCalendarWithDate:previousNewMoonStart :NO];
}

- (void)_moveDown
{
    NSDate *currentNewMoon = self.calendarView.effectiveNewMoonStart;
    NSDate *nextConj = [DP conjunctionAfterDate:[currentNewMoon dateByAddingTimeInterval:STSecondsPerGregorianDay * 2]];
    NSDate *nextNewMoonStart = [STCalendar newMoonStartTimeForConjunction:nextConj :NULL];
    
    NSLog(@"swipe up, switching from %@ to %@",currentNewMoon,nextNewMoonStart);
    [self _replaceCurrentCalendarWithDate:nextNewMoonStart :YES];
}

- (void)_addCalendarViewWithDate:(NSDate *)date
{
    self.calendarView = [[STCalendarView alloc] initWithFrame:CGRectInset([self.view frame], 0, 0)];
    self.calendarView.effectiveNewMoonStart = date;
#ifndef __MAC_OS_X_VERSION_MAX_ALLOWED
    self.calendarView.backgroundColor = [STColorClass clearColor];
#endif
    __weak typeof(self) weakSelf = self;
    self.calendarView.moveUpHandler = ^{
        [weakSelf _moveUp];
    };
    self.calendarView.moveDownHandler = ^{
        [weakSelf _moveDown];
    };
    //self.calendarView.layer.opaque = 0.5;
    [self _addCalendarView];
}

- (void)viewDidLoad {
    [super viewDidLoad];
        
    SCNView *moonView = [[SCNView alloc] initWithFrame:[self.view frame] options:NULL];
    self.moonController = [[STMoonController alloc] initWithView:moonView];
    [self.view addSubview:moonView];
    
#ifndef __MAC_OS_X_VERSION_MAX_ALLOWED
    UISwipeGestureRecognizer *up = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleGesture:)];
    up.direction = UISwipeGestureRecognizerDirectionUp;
    UISwipeGestureRecognizer *down = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleGesture:)];
    down.direction = UISwipeGestureRecognizerDirectionDown;
    self.view.gestureRecognizers = @[ up, down ];
    
    CGRect progressFrame = CGRectMake([self.view frame].origin.x + [self.view frame].size.width / 2 - STSpinnerWidth / 2,
                                      [self.view frame].origin.y + 4 * ( [self.view frame].size.height / 5 ) - STSpinnerWidth / 2,
                                      STSpinnerWidth, STSpinnerHeight
                                      );
    
    self.progressView = [[UIActivityIndicatorView alloc] initWithFrame:progressFrame];
    self.progressView.activityIndicatorViewStyle = UIActivityIndicatorViewStyleLarge;
    self.progressView.color = [STColorClass whiteColor];
    self.progressView.hidesWhenStopped = YES;
    [self.view addSubview:self.progressView];
#endif
    
    [self _addCalendarViewWithDate:[DP lastNewMoonStart]];
    
    [self.moonController doIntroAnimationWithCompletionHandler:^{
        NSLog(@"did intro animation");
        [self.moonController animateToCurrentPhaseWithCompletionHandler:^{
            NSLog(@"animated to current phase on app launch");
            [self _updatePhase];
        }];
    }];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:NSCalendarDayChangedNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull notification) {    
        [self _replaceCurrentCalendarWithDate:[NSDate myNow] :NO];
        [self.moonController animateToCurrentPhaseWithCompletionHandler:^{
            NSLog(@"animated to current phase on day change");
        }];
        
        [[STState state] sendSabbathNotificationWithDelay:STSecondsPerGregorianDay / 2.];
    }];
    [[NSNotificationCenter defaultCenter] addObserverForName:NSSystemClockDidChangeNotification object:nil queue:[NSOperationQueue mainQueue]  usingBlock:^(NSNotification * _Nonnull notification) {
        NSLog(@"NSSystemClockDidChangeNotification!");
        [self _replaceCurrentCalendarWithDate:[NSDate myNow] :NO];
        [self.moonController animateToCurrentPhaseWithCompletionHandler:^{
            NSLog(@"animated to current phase on clock change");
        }];
        
        [[STState state] sendSabbathNotificationWithDelay:0];
    }];
    
    [[STState state] requestNotificationApprovalWithDelay:STNotificationRequestDelay];
}

@end
