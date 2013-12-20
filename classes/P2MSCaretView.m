
//
//  P2MSCaretView.m
//  P2MSTextView
//
//  Created by PYAE PHYO MYINT SOE on 3/12/13.
//  Copyright (c) 2013 PYAE PHYO MYINT SOE. All rights reserved.
//

#import "P2MSCaretView.h"

@implementation P2MSCaretView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        //set default backgrund color
        self.backgroundColor = [UIColor colorWithRed:0.3176 green:0.41568 blue:0.9294 alpha:0.9];
        // Initialization code
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
        [self blinkCaret];
    } else {
        [self.layer removeAllAnimations];
    }
}

- (void)blinkCaret {
    [self.layer removeAnimationForKey:@"blink"];
    CAKeyframeAnimation *animation = [CAKeyframeAnimation animationWithKeyPath:@"opacity"];
    animation.values = [NSArray arrayWithObjects:[NSNumber numberWithFloat:1.0f], [NSNumber numberWithFloat:1.0f], [NSNumber numberWithFloat:0.0f], [NSNumber numberWithFloat:0.0f], nil];
    animation.calculationMode = kCAAnimationCubic;
    animation.duration = 1.0;
    animation.beginTime = CACurrentMediaTime() + 0.6;
    animation.repeatCount = CGFLOAT_MAX;
    [self.layer addAnimation:animation forKey:@"blink"];
}


@end
