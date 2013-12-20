//
//  P2MSCaretView.h
//  P2MSTextView
//
//  Created by PYAE PHYO MYINT SOE on 3/12/13.
//  Copyright (c) 2013 PYAE PHYO MYINT SOE. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface P2MSCaretView : UIView

- (void)setCaretColor:(UIColor *)color;
- (void)blinkCaret;
- (void)removeAnimations;

@end
