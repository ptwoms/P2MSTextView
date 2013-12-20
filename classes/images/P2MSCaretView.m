//
//  P2MSCaretView.m
//  P2MSTextView
//
//  Created by P2MS on 17/5/13.
//  Copyright (c) 2013 Pyae Phyo MS. All rights reserved.
//

#import "P2MSCaretView.h"
#import <QuartzCore/QuartzCore.h>
#import "P2MSConstants.h"

@implementation P2MSCaretView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [P2MSConstants caretColor];
    }
    return self;
}

- (void)removeAnimations {
    [self.layer removeAllAnimations];    
}

- (void)setCaretColor:(UIColor *)color{
    self.backgroundColor = color;
//    [self setNeedsDisplay];
}


- (void)didMoveToSuperview {
    if (self.superview) {
        [self delayBlink];
    } else {
        [self.layer removeAllAnimations];
    }
}

- (void)delayBlink {
    CAKeyframeAnimation *animation = [CAKeyframeAnimation animationWithKeyPath:@"opacity"];
    animation.values = [NSArray arrayWithObjects:[NSNumber numberWithFloat:1.0f], [NSNumber numberWithFloat:1.0f], [NSNumber numberWithFloat:0.0f], [NSNumber numberWithFloat:0.0f], nil];
    animation.calculationMode = kCAAnimationCubic;
    animation.duration = 1.0;
    animation.beginTime = CACurrentMediaTime() + 0.6;
    animation.repeatCount = CGFLOAT_MAX;
    [self.layer addAnimation:animation forKey:@"blink"];
}


@end
