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
@property (strong) STButton *optionsButton;
//@property (strong) UIDatePicker *datePicker;
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
    NSDate *previousNewMoonStart = [STCalendar newMoonStartTimeForConjunction:lastLastConj];
    
    NSLog(@"swipe down, switching from %@ to %@ (%@, %@)",currentNewMoon,previousNewMoonStart,lastConj,lastLastConj);
    [self _replaceCurrentCalendarWithDate:previousNewMoonStart :NO];
}

- (void)_moveDown
{
    NSDate *currentNewMoon = self.calendarView.effectiveNewMoonStart;
    NSDate *nextConj = [DP conjunctionAfterDate:[currentNewMoon dateByAddingTimeInterval:STSecondsPerGregorianDay * 2]];
    NSDate *nextNewMoonStart = [STCalendar newMoonStartTimeForConjunction:nextConj];
    
    NSLog(@"swipe up, switching from %@ to %@ (%@)",currentNewMoon,nextNewMoonStart,nextConj);
    [self _replaceCurrentCalendarWithDate:nextNewMoonStart :YES];
}

- (void)_addCalendarViewWithDate:(NSDate *)date
{
    self.calendarView = [[STCalendarView alloc] initWithFrame:CGRectInset([self.view frame], STCalendarViewInsetX, STCalendarViewInsetY)];
    self.calendarView.effectiveNewMoonStart = [STCalendar lastNewMoonForDate:date];
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

/*- (void)jumpToDateChanged:(id)sender
{
    NSLog(@"jump to %@!",self.datePicker.date);
}*/

- (void)_jumpToYear:(NSString *)string gregorian:(BOOL)gregorian
{
    NSNumberFormatter *f = [NSNumberFormatter new];
    f.numberStyle = NSNumberFormatterDecimalStyle;
    NSNumber *number = [f numberFromString:string];
    
    if ( ! number ) {
        NSLog(@"invalid jump '%@'",string);
        return;
    }
    
    NSInteger year = [number integerValue];
    NSLog(@"jumping to year %ld",year);
    NSDateComponents *comps = [NSDateComponents new];
    if ( year < 0 ) {
        comps.era = 0;
        comps.year = -(year) + 1;
    } else {
        comps.era = 1;
        comps.year = year;
    }
    NSDate *date = [[NSCalendar currentCalendar] dateFromComponents:comps];
    if ( ! gregorian ) {
        NSDate *yearFrom = [STCalendar date:date byAddingDays:365 hours:0 minutes:0 seconds:0];
        date = [DP lastNewYearForDate:yearFrom];
    }
    [self _replaceCurrentCalendarWithDate:date :[date timeIntervalSinceDate:self.calendarView.effectiveNewMoonStart] > 0];
}

- (void)_addOptionsButton
{
    /*UIMenuElement *settings = [UIAction actionWithTitle:@"settings..." image:[UIImage systemImageNamed:@"gear"] identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
    }];
    UIMenuElement *jumpToDate = [UIAction actionWithTitle:@"jump to date" image:[UIImage systemImageNamed:@"moon"] identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
        if ( ! self.datePicker ) {
            UIDatePicker *picker = [[UIDatePicker alloc] initWithFrame:CGRectMake(0, 100, 50, 50)];
            picker.preferredDatePickerStyle = UIDatePickerStyleCompact;//UIDatePickerStyleInline;
            picker.datePickerMode = UIDatePickerModeDate;
            [picker addTarget:self action:@selector(jumpToDateChanged:) forControlEvents:UIControlEventValueChanged];
            self.datePicker = picker;
            [self.view addSubview:self.datePicker];
        }
    }];*/
#ifndef __MAC_OS_X_VERSION_MAX_ALLOWED
    UIMenuElement *jumpToYear = [UIAction actionWithTitle:@"jump to year" image:[UIImage systemImageNamed:@"moon"] identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"jump to year" message:nil preferredStyle:UIAlertControllerStyleAlert];
        [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
            [textField setText:@""];
            [textField setKeyboardType:UIKeyboardTypeNumbersAndPunctuation];
        }];
        [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        }]];
        [alert addAction:[UIAlertAction actionWithTitle:@"January" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [self _jumpToYear:alert.textFields.firstObject.text gregorian:YES];
        }]];
        [alert addAction:[UIAlertAction actionWithTitle:@"Abib" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [self _jumpToYear:alert.textFields.firstObject.text gregorian:NO];
        }]];
        
        [self presentViewController:alert animated:YES completion:^{
        }];
    }];
    UIMenu *menu = [UIMenu menuWithTitle:@"" image:nil identifier:nil options:0 children:[NSArray arrayWithObjects:/*settings,jumpToDate,*/jumpToYear,nil]];
    
    self.optionsButton = [STButton buttonWithType:UIButtonTypeSystem];
    self.optionsButton.menu = menu;
    self.optionsButton.showsMenuAsPrimaryAction = YES;
    [self.optionsButton setTitle:@"..." forState:UIControlStateNormal];
    self.optionsButton.frame = CGRectMake(5, 100, 30, 30);
    [self.view addSubview:self.optionsButton];
#endif
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
    
    [self _addOptionsButton];
    
    //[self.moonController doIntroAnimationWithCompletionHandler:^{
    //    NSLog(@"did intro animation");
        [self.moonController animateToCurrentPhaseWithCompletionHandler:^{
            NSLog(@"animated to current phase on app launch");
            [self _updatePhase];
        }];
    //®®}];
    
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
    
//#define PeriodicRedraw
#ifdef PeriodicRedraw
    [self _periodicRedraw];
#endif
    
    [[STState state] requestNotificationApprovalWithDelay:STNotificationRequestDelay];
}

- (void)_periodicRedraw
{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(STPeriodicRedrawSeconds * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self _replaceCurrentCalendarWithDate:[NSDate myNow] :NO];
        [self _periodicRedraw];
    });
}

@end
