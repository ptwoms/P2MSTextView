//
//  P2MSTextWindow.m
//  P2MSTextView
//
//  Created by PYAE PHYO MYINT SOE on 3/12/13.
//  Copyright (c) 2013 PYAE PHYO MYINT SOE. All rights reserved.
//

#import "P2MSTextWindow.h"
#import "P2MSGlobalFunctions.h"
#import "P2MSSelectionView.h"

@implementation P2MSTextWindow

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
    }
    return self;
}

- (void)hideTextWindow:(BOOL)animated{
    if ((windowView)) {
        [UIView animateWithDuration:kAnimationDuration animations:^{
            CGRect frame = windowView.frame;
            CGPoint center = windowView.center;
            frame.origin.x = floorf(center.x-(frame.size.width/2));
            frame.origin.y = center.y;
            windowView.frame = frame;
            windowView.transform = CGAffineTransformMakeScale(0.01f, 0.01f);
        } completion:^(BOOL finished) {
            _showing=NO;
            [windowView removeFromSuperview];
            windowView=nil;
            self.windowLevel = UIWindowLevelNormal;
            self.hidden = YES;
        }];
    }
}

- (UIImage*)screenshotFromFrame:(CGRect)rect inView:(UIView*)view{
    CGRect offsetRect =  [self convertRect:rect toView:view];
    CGFloat scaleD = 1.0f;
    if (_windowType == P2MS_TEXT_MAGNIFY) {
        offsetRect.origin.y -= 8;
//        scaleD = 1.1f;
    }
    
    UIGraphicsBeginImageContextWithOptions(windowView.bounds.size, YES, [[UIScreen mainScreen] scale]);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(ctx, [UIColor colorWithRed:1.0f green:1.0f blue:1.0f alpha:1.0f].CGColor);
    UIRectFill(CGContextGetClipBoundingBox(ctx));
    
    CGContextSaveGState(ctx);
    CGAffineTransform flipVertical = CGAffineTransformMake(scaleD, 0, 0, -scaleD, 0, view.bounds.size.height);
    CGContextConcatCTM(ctx, flipVertical);
    CGContextTranslateCTM(ctx,-offsetRect.origin.x+(windowView.bounds.size.width/2), view.bounds.size.height-offsetRect.origin.y-(windowView.bounds.size.height/2)-(rect.size.height/2));
    
    UIView *selectionView = nil;
    CGRect selectionFrame = CGRectZero;
    if ([[[UIDevice currentDevice]systemVersion]floatValue] < 6.0) {
        for (UIView *subview in view.subviews){
            if ([subview isKindOfClass:[P2MSSelectionView class]]) {
                selectionView = subview;
            }
        }
        if (selectionView) {
            selectionFrame = selectionView.frame;
            CGRect newFrame = selectionFrame;
            newFrame.origin.y = (selectionFrame.size.height - view.bounds.size.height) - ((selectionFrame.origin.y + selectionFrame.size.height) - view.bounds.size.height);
            selectionView.frame = newFrame;
        }
    }
    [[view layer]renderInContext:ctx];
    CGContextRestoreGState(ctx);
    UIImage *aImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    if (selectionView) {
        selectionView.frame = selectionFrame;
    }
    return aImage;
}

- (void)showTextWindowFromView:(UIView*)view rect:(CGRect)rect {
    if (!_showing) {
        if (windowView == nil) {
            windowView = (_windowType == P2MS_TEXT_LOUPE)?[[P2MSLoupeView alloc] init]:[[P2MSMagnifyView alloc] init];
            [self addSubview:windowView];
        }
        CGRect frame = windowView.frame;
        frame.origin.x = floorf(CGRectGetMinX(rect) - (windowView.bounds.size.width/2));
        CGFloat posY = floorf(CGRectGetMinY(rect) - windowView.bounds.size.height);
        if (_windowType == P2MS_TEXT_LOUPE) {
            frame.origin.y = MAX(posY-10, -40.0f);
        }else {
            frame.origin.y = MAX(posY+8.0f, 0.0f);
            frame.origin.x += 2.0f;
        }
        CGRect originFrame = frame;
        frame.origin.y += frame.size.height/2;
        windowView.frame = frame;
        windowView.transform = CGAffineTransformMakeScale(0.01f, 0.01f);
        windowView.alpha = 0.01f;
        [UIView animateWithDuration:kAnimationDuration animations:^{
            windowView.alpha = 1.0f;
            windowView.transform = CGAffineTransformMakeScale(1.0f, 1.0f);
            windowView.frame = originFrame;
        } completion:^(BOOL finished) {
            _showing=YES;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (0.01f*NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self renderContentView:view fromRect:rect];
            });
        }];
    }
}

- (void)renderContentView:(UIView*)view fromRect:(CGRect)rect {
    if (_showing && windowView) {
        CGRect frame = windowView.frame;
        frame.origin.x = floorf((CGRectGetMinX(rect) - (windowView.bounds.size.width/2)) + (rect.size.width/2));
        CGFloat posY = floorf(CGRectGetMinY(rect) - windowView.bounds.size.height);
        if (_windowType == P2MS_TEXT_LOUPE) {
            frame.origin.y = MAX(posY-10.0f, -40.0f);
            rect.origin.y -= 10;
        }else{
            frame.origin.y = MAX(0.0f, posY-8.0f);
        }
        windowView.frame = frame;
        [windowView setTextImage:[self screenshotFromFrame:rect inView:view]];
    }
}

+ (P2MSTextWindow *)getTextWindow:(P2MSTextWindow *)textWindow{
    if(textWindow==nil) {
        //search for existing one
        for (P2MSTextWindow *aWindow in [[UIApplication sharedApplication] windows]){
            if ([aWindow isKindOfClass:[P2MSTextWindow class]]) {
                textWindow = aWindow;
                textWindow.frame = [[UIScreen mainScreen] bounds];break;
            }
        }
        //if not, create new one
        if (textWindow == nil) {
            textWindow = [[P2MSTextWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
        }
        textWindow.windowLevel = UIWindowLevelStatusBar;
        textWindow.hidden = NO;
    }
    [textWindow updateForOrientationChange];
    return textWindow;
}

- (void)updateForOrientationChange{
    self.frame = [[UIScreen mainScreen] bounds];
    switch ([[UIApplication sharedApplication] statusBarOrientation]) {
        case UIInterfaceOrientationPortrait:
            self.layer.transform = CATransform3DIdentity;
            break;
        case UIInterfaceOrientationLandscapeRight:
            self.layer.transform = CATransform3DMakeRotation(M_PI/2, 0, 0, 1);
            break;
        case UIInterfaceOrientationLandscapeLeft:
            self.layer.transform = CATransform3DMakeRotation(-(M_PI/2), 0, 0, 1);
            break;
        case UIInterfaceOrientationPortraitUpsideDown:
            self.layer.transform = CATransform3DMakeRotation(M_PI, 0, 0, 1);
            break;
        default:
            break;
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [self updateForOrientationChange];
}
@end
