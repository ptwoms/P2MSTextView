//
//  P2MSSelectionView.m
//  P2MSTextView
//
//  Created by PYAE PHYO MYINT SOE on 3/12/13.
//  Copyright (c) 2013 PYAE PHYO MYINT SOE. All rights reserved.
//

#import "P2MSSelectionView.h"
#import "P2MSGlobalFunctions.h"

@interface P2MSSelectionView(){
    UIView *_leftDot;
    UIView *_rightDot;
    UIView *_leftCaret;
    UIView *_rightCaret;
}

@end

@implementation P2MSSelectionView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = NO;
        self.layer.geometryFlipped = YES;
    }
    return self;
}

- (void)beginCaretForRect:(CGRect)begin endCaretForRect:(CGRect)end{
    if(!self.superview) return;
    self.frame = CGRectMake(begin.origin.x, begin.origin.y + begin.size.height, end.origin.x - begin.origin.x, (end.origin.y-end.size.height)-begin.origin.y);
    begin = [self.superview convertRect:begin toView:self];
    end = [self.superview convertRect:end toView:self];
    
    if (_leftCaret == nil) {
        _leftCaret = [[UIView alloc] initWithFrame:begin];
        _leftCaret.backgroundColor = [P2MSGlobalFunctions caretColor];
        [self addSubview:_leftCaret];
        
        UIImage *image = [UIImage imageNamed:@"selection-dot.png"];
        _leftDot = [[UIImageView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, image.size.width, image.size.height)];
        [(UIImageView *)_leftDot setImage:image];
        [self addSubview:_leftDot];
        
        _rightCaret = [[UIView alloc] initWithFrame:end];
        _rightCaret.backgroundColor = [P2MSGlobalFunctions caretColor];
        [self addSubview:_rightCaret];
        
        _rightDot = [[UIImageView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, image.size.width, image.size.height)];
        [(UIImageView *)_rightDot setImage:[UIImage imageNamed:@"selection-dot.png"]];
        [self addSubview:_rightDot];
    }
    
    _leftCaret.frame = begin;
    _leftDot.frame = CGRectMake(floorf(_leftCaret.center.x - (_leftDot.bounds.size.width/2)), _leftCaret.frame.origin.y-(_leftDot.bounds.size.height-5.0f), _leftDot.bounds.size.width, _leftDot.bounds.size.height);
    
    _rightCaret.frame = end;
    _rightDot.frame = CGRectMake(floorf(_rightCaret.center.x - (_rightDot.bounds.size.width/2)), CGRectGetMaxY(_rightCaret.frame), _rightDot.bounds.size.width, _rightDot.bounds.size.height);
}
@end
