//
//  P2MSSelectionView.h
//  P2MSTextView
//
//  Created by PYAE PHYO MYINT SOE on 19/5/13.
//  Copyright (c) 2013 Pyae Phyo MS. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface P2MSSelectionView : UIView

@property (nonatomic) BOOL isSelectionLeft;

- (void)beginCaretForRect:(CGRect)begin endCaretForRect:(CGRect)end;

@end
