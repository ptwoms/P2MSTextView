//
//  P2MSMagnifyView.m
//  P2MSTextView
//
//  Created by P2MS on 17/5/13.
//  Copyright (c) 2013 Pyae Phyo MS. All rights reserved.
//
//http://mozainuddin.deviantart.com/art/Apple-iOS-7-loupe-magnification-PSD-379756847 Loupe View

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
    [[UIImage imageNamed:@"magnifier-ranged-lo.png"] drawInRect:rect];
    if (self.textImage) {
        CGContextRef context = UIGraphicsGetCurrentContext();
        CGContextSaveGState(context);
        CGContextClipToMask(context, rect, [UIImage imageNamed:@"magnifier-ranged-mask.png"].CGImage);
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
    [[UIImage imageNamed:@"loupe-lo.png"] drawInRect:rect];
    if (self.textImage) {
        CGContextRef context = UIGraphicsGetCurrentContext();
        CGContextSaveGState(context);
        CGContextClipToMask(context, rect, [UIImage imageNamed:@"loupe-mask.png"].CGImage);
        [self.textImage drawInRect:rect];
        CGContextRestoreGState(context);
    }
}

@end
