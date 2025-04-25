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

@interface ViewController ()
@property (strong) STMoonController *moonViewController;
@property (strong) UIView *calendarView;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
#ifdef __MAC_OS_X_VERSION_MAX_ALLOWED
    CGFloat yInset = 50;
#else
    CGFloat yInset = 300;
#endif
    self.calendarView = [[STCalendarView alloc] initWithFrame:CGRectInset([self.view frame], 50, yInset)];
    //self.calendarView.layer.opaque = 0.5;
    [self.view addSubview:self.calendarView];
    
    SCNView *moonView = [[SCNView alloc] initWithFrame:CGRectInset([self.view frame], 10, 10) options:NULL];
    self.moonViewController = [[STMoonController alloc] initWithView:moonView];
    [self.view addSubview:moonView];
}


@end
