//
//  ViewController.m
//  iSH
//
//  Created by Theodore Dubois on 10/17/17.
//

#import "TerminalViewController.h"
#import "AppDelegate.h"
#import "TerminalView.h"
#import "ArrowBarButton.h"
#import "ExportViewController.h"

@interface TerminalViewController () <UIGestureRecognizerDelegate>

@property Terminal *terminal;
@property UITapGestureRecognizer *tapRecognizer;
@property (weak, nonatomic) IBOutlet TerminalView *termView;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *bottomConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *safeAreaBottomConstraint;

@property (weak, nonatomic) IBOutlet UIButton *controlKey;

@property (weak, nonatomic) IBOutlet UIInputView *barView;
@property (weak, nonatomic) IBOutlet UIStackView *bar;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *barTop;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *barBottom;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *barLeading;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *barTrailing;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *barButtonWidth;
@property (weak, nonatomic) IBOutlet UIButton *hideKeyboardButton;

@end

@implementation TerminalViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.terminal = [Terminal terminalWithType:0 number:0];
    self.termView.terminal = self.terminal;
    [self.termView becomeFirstResponder];

    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self
               selector:@selector(keyboardDidSomething:)
                   name:UIKeyboardWillShowNotification
                 object:nil];
    [center addObserver:self
               selector:@selector(keyboardDidSomething:)
                   name:UIKeyboardWillHideNotification
                 object:nil];

    [center addObserver:self
               selector:@selector(ishExited:)
                   name:ISHExitedNotification
                 object:nil];

    [self.termView registerExternalKeyboardNotificationsToNotificationCenter:center];
    
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        [self.bar removeArrangedSubview:self.hideKeyboardButton];
        [self.hideKeyboardButton removeFromSuperview];
    }
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPhone) {
        self.barView.frame = CGRectMake(0, 0, 100, 48);
    } else {
        self.barView.frame = CGRectMake(0, 0, 100, 55);
    }
}

- (BOOL)prefersStatusBarHidden {
    BOOL isIPhoneX = UIApplication.sharedApplication.delegate.window.safeAreaInsets.top > 20;
    return !isIPhoneX;
}

- (void)keyboardDidSomething:(NSNotification *)notification {
    BOOL initialLayout = self.termView.needsUpdateConstraints;
    
    CGFloat pad = 0;
    if ([notification.name isEqualToString:UIKeyboardWillShowNotification]) {
        NSValue *frame = notification.userInfo[UIKeyboardFrameEndUserInfoKey];
        pad = frame.CGRectValue.size.height;
    }
    self.bottomConstraint.constant = -pad;
    if (pad == 0) {
        self.bottomConstraint.active = NO;
        self.safeAreaBottomConstraint.active = YES;
    } else {
        self.safeAreaBottomConstraint.active = NO;
        self.bottomConstraint.active = YES;
    }
    [self.view setNeedsUpdateConstraints];
    
    if (!initialLayout) {
        // if initial layout hasn't happened yet, the terminal view is going to be at a really weird place, so animating it is going to look really bad
        NSNumber *interval = notification.userInfo[UIKeyboardAnimationDurationUserInfoKey];
        NSNumber *curve = notification.userInfo[UIKeyboardAnimationCurveUserInfoKey];
        [UIView animateWithDuration:interval.doubleValue
                              delay:0
                            options:curve.integerValue << 16
                         animations:^{
                             [self.view layoutIfNeeded];
                         }
                         completion:nil];
    }
}

- (void)ishExited:(NSNotification *)notification {
    [self performSelectorOnMainThread:@selector(displayExitThing) withObject:nil waitUntilDone:YES];
}

- (void)displayExitThing {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"attempted to kill init" message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"goodbye" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        exit(0);
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark Bar

- (IBAction)showAbout:(id)sender {
    UIViewController *aboutViewController = [[UIStoryboard storyboardWithName:@"About" bundle:nil] instantiateInitialViewController];
    [self presentViewController:aboutViewController animated:YES completion:nil];
}

- (void)resizeBar {
    CGSize screen = UIScreen.mainScreen.bounds.size;
    CGSize bar = self.barView.bounds.size;
    // set sizing parameters on bar
    // numbers stolen from iVim and modified somewhat
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPhone) {
        // phone
        [self setBarHorizontalPadding:6 verticalPadding:6 buttonWidth:32];
    } else if (bar.width == screen.width || bar.width == screen.height) {
        // full-screen ipad
        [self setBarHorizontalPadding:15 verticalPadding:8 buttonWidth:43];
    } else if (bar.width <= 320) {
        // slide over
        [self setBarHorizontalPadding:8 verticalPadding:8 buttonWidth:26];
    } else {
        // split view
        [self setBarHorizontalPadding:10 verticalPadding:8 buttonWidth:36];
    }
    [UIView performWithoutAnimation:^{
        [self.barView layoutIfNeeded];
    }];
}

- (void)setBarHorizontalPadding:(CGFloat)horizontal verticalPadding:(CGFloat)vertical buttonWidth:(CGFloat)buttonWidth {
    self.barLeading.constant = self.barTrailing.constant = horizontal;
    self.barTop.constant = self.barBottom.constant = vertical;
    self.barButtonWidth.constant = buttonWidth;
}

- (IBAction)pressEscape:(BarButton *)sender {
    [self pressKey:@"\x1b"];
}
- (IBAction)pressTab:(BarButton *)sender {
    [self pressKey:@"\t"];
}
- (void)pressKey:(NSString *)key {
    [self.termView insertText:key];
}

- (IBAction)pressControl:(BarButton *)sender {
    self.controlKey.selected = !self.controlKey.selected;
}

- (IBAction)pressShare:(BarButton *)sender {
    UIViewController *exportViewController = [[UIStoryboard storyboardWithName:@"Export" bundle:nil] instantiateInitialViewController];
    [self presentViewController:exportViewController animated:YES completion:nil];
}

- (IBAction)pressArrow:(ArrowBarButton *)sender {
    switch (sender.direction) {
        case ArrowUp: [self pressKey:@"\x1b[A"]; break;
        case ArrowDown: [self pressKey:@"\x1b[B"]; break;
        case ArrowLeft: [self pressKey:@"\x1b[D"]; break;
        case ArrowRight: [self pressKey:@"\x1b[C"]; break;
        case ArrowNone: break;
    }
}

@end

@interface BarView : UIInputView
@property (weak) IBOutlet TerminalViewController *terminalViewController;
@end
@implementation BarView

- (void)layoutSubviews {
    [self.terminalViewController resizeBar];
}

@end
