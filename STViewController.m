//
//  STViewController.m
//  Sabbatic
//
//  Created by david on 3/20/25.
//

#import "STViewController.h"

#import <SceneKit/SceneKit.h>

#import "STCalendarView.h"
#import "STVerseView.h"
#import "STGreetingView.h"
#import "STMoonController.h"
#import "STDefines.h"
#import "STState.h"
#import "STCalendar.h"
#import "NSDate+MyNow.h"
#ifdef __MAC_OS_X_VERSION_MAX_ALLOWED
#import "STMenuItem.h"
#import "STButton.h"
#endif

@interface STViewController ()
@property (strong) STMoonController *moonController;
@property (strong) STCalendarView *calendarView;
@property (strong) STVerseView *verseView;
@property (strong) STGreetingView *greetingView;
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
            [self.view sortSubviewsUsingFunction:(NSComparisonResult (*)(id, id, void*))sortViews context:(__bridge void * _Nullable)(self)];
            [self.view.window makeFirstResponder:self.calendarView];
#endif
            
        });
    });
}

NSComparisonResult sortViews(id one, id two, void *context) {
    STViewController *vc = (__bridge STViewController *)context;

    if ( one == vc.optionsButton ) {
        return NSOrderedDescending;
    } else if ( two == vc.optionsButton ) {
        return NSOrderedAscending;
    }
    return NSOrderedSame;
}

- (void)_replaceCurrentCalendarWithDate:(NSDate *)date :(BOOL)up :(BOOL)animated
{
#ifndef __MAC_OS_X_VERSION_MAX_ALLOWED
    STCalendarView *oldCalendar = self.calendarView;
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
    [self _reloadCalendarWithDate:date :NO];
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
#warning factor this
#ifndef __MAC_OS_X_VERSION_MAX_ALLOWED
    self.verseView = [[STVerseView alloc] initWithFrame:CGRectMake(self.calendarView.frame.origin.x + STVerseViewInsetX,
                                                                   self.calendarView.frame.origin.y + self.calendarView.frame.size.height,
                                                                   self.calendarView.frame.size.width - 2*STVerseViewInsetX,
                                                                   self.view.frame.size.height - ( self.calendarView.frame.origin.y + self.calendarView.frame.size.height ))];
    [self.verseView preload];
    [self.view addSubview:self.verseView];
#else
    self.verseView = [[STVerseView alloc] initWithFrame:CGRectInset(self.calendarView.frame,STVerseViewInsetX,STVerseViewInsetX)];
    [self.verseView preload];
    [self.calendarView addSubview:self.verseView];
#endif
}

- (void)_addGreetingView
{
    self.greetingView = [[STGreetingView alloc] initWithFrame:CGRectMake(self.calendarView.frame.origin.x + STGreetingViewInsetX,
                                                                         self.calendarView.frame.origin.y - STGreetingViewHeight,
                                                                         self.calendarView.frame.size.width - 2*STGreetingViewInsetX,
                                                                         STGreetingViewHeight)];
    [self.view addSubview:self.greetingView];
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
#ifndef __MAC_OS_X_VERSION_MAX_ALLOWED
    UIMenuElement *jumpToYear = [UIAction actionWithTitle:@"jump to year" image:[UIImage systemImageNamed:@"slider.horizontal.below.sun.max"] identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"jump to year" message:nil preferredStyle:UIAlertControllerStyleAlert];
        [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
            [textField setText:@""];
            [textField setKeyboardType:UIKeyboardTypeNumbersAndPunctuation];
        }];
        [alert addAction:[UIAlertAction actionWithTitle:@"cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        }]];
        [alert addAction:[UIAlertAction actionWithTitle:@"january" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [self _jumpToYear:alert.textFields.firstObject.text month:0 gregorian:YES];
        }]];
        [alert addAction:[UIAlertAction actionWithTitle:@"abib" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [self _jumpToYear:alert.textFields.firstObject.text month:0 gregorian:NO];
        }]];
        [alert addAction:[UIAlertAction actionWithTitle:@"tishrei" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
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
    UIMenu *menu = [UIMenu menuWithTitle:@"" image:nil identifier:nil options:0 children:[NSArray arrayWithObjects:jumpToYear,jumpToNow,updateLocPref,nil]];
    
    self.optionsButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.optionsButton.tintColor = [UIColor lightGrayColor];
    self.optionsButton.menu = menu;
    self.optionsButton.showsMenuAsPrimaryAction = YES;
    [self.optionsButton setImage:[UIImage systemImageNamed:@"slider.horizontal.3"] forState:UIControlStateNormal];
    self.optionsButton.frame = CGRectMake(10, 75, 30, 30);
    [self.view addSubview:self.optionsButton];
#else
    STMenuItem *jumpToYear = [STMenuItem itemWithTitle:@"jump to year" image:[NSImage imageWithSystemSymbolName:@"slider.horizontal.below.sun.max" accessibilityDescription:@""] handler:^(NSMenuItem * _Nonnull item) {
        NSAlert *alert = [NSAlert new];
        alert.messageText = @"jump to year";
        //alert.informativeText = @"";
        [alert addButtonWithTitle:@"january"];
        [alert addButtonWithTitle:@"abib"];
        [alert addButtonWithTitle:@"tishrei"];
        [alert addButtonWithTitle:@"cancel"];
        
        NSView *inputView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 100, 25)];
        NSTextField *yearField = [[NSTextField alloc] initWithFrame:inputView.frame];
        yearField.placeholderString = @"year";
        [inputView addSubview:yearField];
        [alert setAccessoryView:inputView];
        
        [alert beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse returnCode) {
            if ( returnCode == NSAlertFirstButtonReturn ) {
                [self _jumpToYear:yearField.stringValue month:0 gregorian:YES];
            } else if ( returnCode == NSAlertSecondButtonReturn ) {
                [self _jumpToYear:yearField.stringValue month:0 gregorian:NO];
            } else if ( returnCode == NSAlertThirdButtonReturn ) {
                [self _jumpToYear:yearField.stringValue month:6 gregorian:NO];
            } else if ( returnCode == ( NSAlertThirdButtonReturn + 1 ) ) {
            }
        }];
    }];
    STMenuItem *jumpToNow = [STMenuItem itemWithTitle:@"jump to now" image:[NSImage imageWithSystemSymbolName:@"sun.max" accessibilityDescription:@""] handler:^(NSMenuItem * _Nonnull item) {
        [self _jumpToNow];
    }];
    STMenuItem *updateLocPref = [STMenuItem itemWithTitle:@"change location" image:[NSImage imageWithSystemSymbolName:@"location.viewfinder" accessibilityDescription:@""] handler:^(NSMenuItem * _Nonnull item) {
        [ST _clearLocationPreferences];
        [self _gatherLocationPreference:NO];
    }];
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@""];
    [menu setItemArray:[NSArray arrayWithObjects:jumpToYear,jumpToNow,updateLocPref, nil]];
    
    self.optionsButton = [STButton buttonWithImage:[NSImage imageWithSystemSymbolName:@"slider.horizontal.3" accessibilityDescription:@""] handler:^(NSButton * _Nonnull button) {
        [menu popUpMenuPositioningItem:jumpToYear atLocation:NSMakePoint(button.frame.origin.x, button.frame.origin.y) inView:self.view];
    }];
    self.optionsButton.bezelStyle = NSBezelStyleCircular;
    self.optionsButton.bezelColor = [NSColor darkGrayColor];
    self.optionsButton.contentTintColor = [NSColor lightGrayColor];
    self.optionsButton.frame = CGRectMake(5, self.view.frame.size.height - 50, 30, 30);
    // why?
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.view addSubview:self.optionsButton];
    });
    
#endif
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
#if 0
    [ST _clearLocationPreferences];
#endif
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
    
    [self _addOptionsButton];
    [self _addVerseView];
    //[self _addGreetingView];
    self.nowAndThen = YES;
    
    [ST requestNotificationApprovalWithDelay:STNotificationRequestDelay];
}

- (void)_gatherLocationPreference:(BOOL)appLaunch
{
#ifndef __MAC_OS_X_VERSION_MAX_ALLOWED
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Location Preference" message:@"Sabbatic uses your location to display sunset times. You can use Location Services, or enter an approximate location manually." preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"Enter Location" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
            [self _enterLocation:appLaunch];
        }]];
        [alert addAction:[UIAlertAction actionWithTitle:@"Use Location Services" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [self _requestLocAuth:appLaunch];
        }]];
        [self presentViewController:alert animated:YES completion:^{
        }];
    });
#else
    NSAlert *alert = [NSAlert new];
    alert.messageText = @"Location Preference";
    alert.informativeText = @"Sabbatic uses your location to display sunset times. You can use Location Services, or enter an approximate location manually.";
    [alert addButtonWithTitle:@"Enter Location"];
    [alert addButtonWithTitle:@"Use Location Services"];
    [alert beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse returnCode) {
        if ( returnCode == NSAlertFirstButtonReturn ) {
            [self _enterLocation:appLaunch];
        } else if ( returnCode == NSAlertSecondButtonReturn ) {
            [self _requestLocAuth:appLaunch];
        }
    }];
#endif
}

- (void)_requestLocAuth:(BOOL)appLaunch {
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
}

- (void)_enterLocation:(BOOL)appLaunch
{
#ifndef __MAC_OS_X_VERSION_MAX_ALLOWED
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
        double lat = [alert.textFields.firstObject.text doubleValue];
        double lon = [alert.textFields.lastObject.text doubleValue];
        
        [self _validateLocationAndReload:lat :lon :appLaunch];
    }]];
    [self presentViewController:alert animated:YES completion:^{
    }];
#else
    NSAlert *alert = [NSAlert new];
    alert.messageText = @"Enter location";
    alert.informativeText = @"e.g. 38.62, -90.2";
    [alert addButtonWithTitle:@"Okay"];
    [alert addButtonWithTitle:@"Cancel"];
    
    NSView *inputView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 100, 50)];
    NSTextField *latField = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 25, 100, 25)];
    latField.placeholderString = @"latitude";
    [inputView addSubview:latField];
    NSTextField *lonField = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 100, 25)];
    lonField.placeholderString = @"longitude";
    [inputView addSubview:lonField];
    [alert setAccessoryView:inputView];
    
    [alert beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse returnCode) {
        if ( returnCode == NSAlertFirstButtonReturn ) {
            double lat = [latField.stringValue doubleValue];
            double lon = [lonField.stringValue doubleValue];
            [self _validateLocationAndReload:lat :lon :appLaunch];
        } else if ( returnCode == NSAlertSecondButtonReturn ) {
            [self _gatherLocationPreference:appLaunch];
        }
    }];
#endif
}

- (void)_validateLocationAndReload:(double)lat :(double)lon :(BOOL)appLaunch
{
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
    
    ST.useManualLocation = YES;
    ST.manualLatitude = lat;
    ST.manualLongitude = lon;
    ST.locationPreferenceGathered = YES;
    [ST save];
    NSLog(@"entered manual location (%0.2f,%0.2f)",ST.manualLatitude,ST.manualLongitude);
    
    [self _reloadCalendarWithDate:[DP lastNewMoonStart] :appLaunch];
}

- (void)_periodicRedraw
{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(STPeriodicRedrawSeconds * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self _replaceCurrentCalendarWithDate:[NSDate myNow] :NO :NO];
        [self _periodicRedraw];
    });
}

@end
