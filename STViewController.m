//
//  STViewController.m
//  Sabbatic
//
//  Created by david on 3/20/25.
//

#import "STViewController.h"

#import <SceneKit/SceneKit.h>

#import "STCalendarView.h"
#import "STverseView.h"
#import "STMoonController.h"
#import "STDefines.h"
#import "STState.h"
#import "STCalendar.h"
#import "NSDate+MyNow.h"

@interface STViewController ()
@property (strong) STMoonController *moonController;
@property (strong) STCalendarView *calendarView;
@property (strong) STVerseView *verseView;
@property (strong) STButton *optionsButton;
//@property (strong) UIDatePicker *datePicker;
@property BOOL nowAndThen;
#ifndef __MAC_OS_X_VERSION_MAX_ALLOWED
@property (strong) UIActivityIndicatorView *progressView;
#endif
@property BOOL currentViewLoaded;
@end

@implementation STViewController

+ (void)initialize
{    
    [ST setDataProvider:[[STDataProviderClass alloc] init]];
}

// now an instance method so it can be deferred until location is determined, one way or another
- (void)initializeNow
{
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

- (void)_replaceCurrentCalendarWithDate:(NSDate *)date :(BOOL)up :(BOOL)animated
{
    STCalendarView *oldCalendar = self.calendarView;

#ifndef __MAC_OS_X_VERSION_MAX_ALLOWED
    if ( ! animated ) {
        [self _reloadCalendarWithDate:date :NO];
        return;
    }
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
        [self _reloadCalendarWithDate:date :NO];
        
        [UIView animateWithDuration:duration delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            //self.calendarView.layer.opaque = 1.0;
        } completion:^(BOOL finished) {
            NSLog(@"new calendar animated in");
        }];
    });
#else
    [self _replaceCurrentCalendarFinally:date];
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
    [self _replaceCurrentCalendarWithDate:previousNewMoonStart :NO :YES];
}

- (void)_moveDown
{
    NSDate *currentNewMoon = self.calendarView.effectiveNewMoonStart;
    NSDate *nextConj = [DP conjunctionAfterDate:[currentNewMoon dateByAddingTimeInterval:STSecondsPerGregorianDay * 2]];
    NSDate *nextNewMoonStart = [STCalendar newMoonStartTimeForConjunction:nextConj];
    
    NSLog(@"swipe up, switching from %@ to %@ (%@)",currentNewMoon,nextNewMoonStart,nextConj);
    [self _replaceCurrentCalendarWithDate:nextNewMoonStart :YES :YES];
}

- (void)_reloadCalendarWithDate:(NSDate *)date :(BOOL)appLaunch
{
    if ( self.calendarView )
        [self.calendarView removeFromSuperview];
    
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
    
    if ( appLaunch ) {
        [self viewDidLoadFinally];
    }
}

- (void)_addVerseView
{
    self.verseView = [[STVerseView alloc] initWithFrame:CGRectMake(self.calendarView.frame.origin.x + STVerseViewInsetX,
                                                                   self.calendarView.frame.origin.y + self.calendarView.frame.size.height,
                                                                   self.calendarView.frame.size.width - 2*STVerseViewInsetX,
                                                                   self.view.frame.size.height - ( self.calendarView.frame.origin.y + self.calendarView.frame.size.height ))];
    [self.verseView preload];
    [self.view addSubview:self.verseView];
}

/*- (void)jumpToDateChanged:(id)sender
{
    NSLog(@"jump to %@!",self.datePicker.date);
}*/

- (void)_jumpToYear:(NSString *)string month:(int)month gregorian:(BOOL)gregorian
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
        
        while ( month-- ) {
            date = [STCalendar newMoonDayForConjunction:[DP conjunctionAfterDate:[STCalendar date:date byAddingDays:1 hours:0 minutes:0 seconds:0]]];
        }
    }
    self.nowAndThen = NO;
    BOOL up = [date timeIntervalSinceDate:self.calendarView.effectiveNewMoonStart] > 0;
    [self _replaceCurrentCalendarWithDate:date :up :YES];
}

- (void)_jumpToNow
{
    if ( ! self.nowAndThen ) {
        self.nowAndThen = YES;
        BOOL up = [[NSDate myNow] timeIntervalSinceDate:self.calendarView.effectiveNewMoonStart] > 0;
        [self _replaceCurrentCalendarWithDate:[NSDate myNow] :up :YES];
    }
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
    UIMenuElement *jumpToYear = [UIAction actionWithTitle:@"jump to year" image:[UIImage systemImageNamed:@"slider.horizontal.below.sun.max"] identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"jump to year" message:nil preferredStyle:UIAlertControllerStyleAlert];
        [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
            [textField setText:@""];
            [textField setKeyboardType:UIKeyboardTypeNumbersAndPunctuation];
        }];
        [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        }]];
        [alert addAction:[UIAlertAction actionWithTitle:@"January" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [self _jumpToYear:alert.textFields.firstObject.text month:0 gregorian:YES];
        }]];
        [alert addAction:[UIAlertAction actionWithTitle:@"Abib" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [self _jumpToYear:alert.textFields.firstObject.text month:0 gregorian:NO];
        }]];
        [alert addAction:[UIAlertAction actionWithTitle:@"Tishrei" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [self _jumpToYear:alert.textFields.firstObject.text month:6 gregorian:NO];
        }]];
        
        [self presentViewController:alert animated:YES completion:^{
        }];
    }];
    UIMenuElement *jumpToNow = [UIAction actionWithTitle:@"jump to now" image:[UIImage systemImageNamed:@"sun.max"] identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
        [self _jumpToNow];
    }];
    UIMenuElement *updateLocPref = [UIAction actionWithTitle:@"change location" image:[UIImage systemImageNamed:@"location.viewfinder"] identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
        [ST _clearLocationPreferences];
        [self _gatherLocationPreference:NO];
    }];
    UIMenu *menu = [UIMenu menuWithTitle:@"" image:nil identifier:nil options:0 children:[NSArray arrayWithObjects:/*settings,jumpToDate,*/jumpToYear,jumpToNow,updateLocPref,nil]];
    
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
    
    BOOL deferCalendar = NO;
    if ( ! ST.locationPreferenceGathered ) {
        NSLog(@"gathering location prefs...");
        deferCalendar = YES;
        [self _gatherLocationPreference:YES];
    } else
        NSLog(@"location prefs known and are %@ %@",ST.useManualLocation?@"manual":@"ls-based",ST.effectiveLocation);
    
    SCNView *moonView = [[SCNView alloc] initWithFrame:[self.view frame] options:NULL];
    self.moonController = [[STMoonController alloc] initWithView:moonView];
    [self.view addSubview:moonView];
    
    //[self.moonController doIntroAnimationWithCompletionHandler:^{
    //    NSLog(@"did intro animation");
        [self.moonController animateToCurrentPhaseWithCompletionHandler:^{
            //NSLog(@"animated to current phase on app launch");
            [self _updatePhase];
        }];
    //®®}];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:NSCalendarDayChangedNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull notification) {
        [self _replaceCurrentCalendarWithDate:[NSDate myNow] :NO :NO];
        [self.moonController animateToCurrentPhaseWithCompletionHandler:^{
            NSLog(@"animated to current phase on day change");
        }];
        
        [ST sendSabbathNotificationWithDelay:STSecondsPerGregorianDay / 2.];
    }];
    [[NSNotificationCenter defaultCenter] addObserverForName:NSSystemClockDidChangeNotification object:nil queue:[NSOperationQueue mainQueue]  usingBlock:^(NSNotification * _Nonnull notification) {
        NSLog(@"NSSystemClockDidChangeNotification!");
        [self _replaceCurrentCalendarWithDate:[NSDate myNow] :NO :NO];
        [self.moonController animateToCurrentPhaseWithCompletionHandler:^{
            NSLog(@"animated to current phase on clock change");
        }];
        
        [ST sendSabbathNotificationWithDelay:0];
    }];
    
//#define PeriodicRedraw
#ifdef PeriodicRedraw
    [self _periodicRedraw];
#endif
    
#warning will this conflict with location alerts now?
    [ST requestNotificationApprovalWithDelay:STNotificationRequestDelay];
    
    if ( ! deferCalendar ) {
        [self _reloadCalendarWithDate:[DP lastNewMoonStart] :YES];
    }
}

- (void)viewDidLoadFinally
{
    [self initializeNow];
    
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
        
    [self _addVerseView];
    
    [self _addOptionsButton];
    self.nowAndThen = YES;
}

- (void)_gatherLocationPreference:(BOOL)appLaunch
{
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Location Preference" message:@"Sabbatic uses your location to display sunset times. You can use Location Services, or enter an approximate location manually." preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"Enter Location" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
            [self _enterLocation:appLaunch];
        }]];
        [alert addAction:[UIAlertAction actionWithTitle:@"Use Location Services" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [ST requestLocationAuthorization:^(BOOL okay) {
                NSLog(@"loc auth result: %d",okay);
                if ( okay ) {
                    ST.locationPreferenceGathered = YES;
                    ST.useManualLocation = NO;
                    [ST save];
                    [self _reloadCalendarWithDate:[DP lastNewMoonStart] :appLaunch];
                } else
                    [self _gatherLocationPreference:appLaunch];
            }];
        }]];
        [self presentViewController:alert animated:YES completion:^{
        }];
    });
}

- (void)_enterLocation:(BOOL)appLaunch
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Enter location" message:@"e.g. 38.62, -90.2" preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        [textField setText:@""];
        [textField setPlaceholder:@"latitude"];
        [textField setKeyboardType:UIKeyboardTypeNumbersAndPunctuation];
     }];
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        [textField setText:@""];
        [textField setPlaceholder:@"longitude"];
        [textField setKeyboardType:UIKeyboardTypeNumbersAndPunctuation];
     }];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        [self _gatherLocationPreference:appLaunch];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Okay" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        ST.useManualLocation = YES;
        double lat = [alert.textFields.firstObject.text doubleValue];
        double lon = [alert.textFields.lastObject.text doubleValue];
        
        // text changed is by notification afaik, losing scope here, so for now doing this lazily
        // would like okay to enable instead
        if ( lat == 0 && lon == 0 ) {
            [self _enterLocation:appLaunch];
            return;
        } if ( lat < -66 || lat > 66 ) {
            [self _enterLocation:appLaunch];
            return;
        } else if ( lon < -180 || lat > 180 ) {
            [self _enterLocation:appLaunch];
            return;
        }
        
        ST.manualLatitude = lat;
        ST.manualLongitude = lon;
        ST.locationPreferenceGathered = YES;
        [ST save];
        NSLog(@"entered manual location (%0.2f,%0.2f)",ST.manualLatitude,ST.manualLongitude);
        
        [self _reloadCalendarWithDate:[DP lastNewMoonStart] :appLaunch];
    }]];
    [self presentViewController:alert animated:YES completion:^{
    }];
}

- (void)_periodicRedraw
{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(STPeriodicRedrawSeconds * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self _replaceCurrentCalendarWithDate:[NSDate myNow] :NO :NO];
        [self _periodicRedraw];
    });
}

@end
