//
//  P2MSWindowView.m
//  P2MSTextView
//
//  Created by PYAE PHYO MYINT SOE on 3/12/13.
//  Copyright (c) 2013 PYAE PHYO MYINT SOE. All rights reserved.
//

#import "P2MSWindowView.h"

@implementation P2MSWindowView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
    }
    return self;
}

- (void)setTextImage:(UIImage *)image{
    _textImage=nil;
    _textImage = image;
    [self setNeedsDisplay];
}


@end



@implementation P2MSMagnifyView


- (id)init {
    return [super initWithFrame:CGRectMake(0.0f, 0.0f, 145.0f, 59.0f)];
}

- (void)drawRect:(CGRect)rect {
    [[UIImage imageNamed:@"magnifier"] drawInRect:rect];
    if (self.textImage) {
        CGContextRef context = UIGraphicsGetCurrentContext();
        CGContextSaveGState(context);
        CGContextClipToMask(context, rect, [UIImage imageNamed:@"magnifier-mask"].CGImage);
        [self.textImage drawInRect:rect];
        CGContextRestoreGState(context);
    }
}

@end


@implementation P2MSLoupeView

- (id)init {
    return [super initWithFrame:CGRectMake(0.0f, 0.0f, 127.0f, 127.0f)];
}

- (void)drawRect:(CGRect)rect {
    [[UIImage imageNamed:@"loupe"] drawInRect:rect];
    if (self.textImage) {
        CGContextRef context = UIGraphicsGetCurrentContext();
        CGContextSaveGState(context);
        CGContextClipToMask(context, rect, [UIImage imageNamed:@"loupe-mask"].CGImage);
        [self.textImage drawInRect:rect];
        CGContextRestoreGState(context);
    }
}

@end