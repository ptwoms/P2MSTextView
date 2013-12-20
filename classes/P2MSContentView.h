//
//  P2MSContentView.h
//  P2MSTextView
//
//  Created by PYAE PHYO MYINT SOE on 3/12/13.
//  Copyright (c) 2013 PYAE PHYO MYINT SOE. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "P2MSCaretView.h"
#import "P2MSSelectionView.h"
#import "P2MSTextWindow.h"
#import "P2MSTextView.h"

@interface P2MSContentView : UIView{
    P2MSTextWindow *textWindow;
    BOOL isDrawing;
}

@property (nonatomic, copy) NSString *contentText;
@property (nonatomic, getter=isEditing) BOOL editing; // Is view in "editing" mode or not (affects drawn results).
@property (nonatomic) P2MSCaretView *caretView;

@property (nonatomic, retain) NSDictionary *fontNames, *fontSizes;
@property (nonatomic, retain) NSDictionary *fontColors;
@property (nonatomic, readonly) NSMutableAttributedString *attributedString;
@property (nonatomic, readonly) P2MSSelectionView *selectionView;
@property (nonatomic) BOOL showCorrectinMenu;

- (CGRect)caretRectForIndex:(int)index;
- (CGRect)firstRectForRange:(NSRange)range;
- (NSInteger)closestIndexToPoint:(CGPoint)point;
- (NSInteger)closestWhitespaceToPoint:(CGPoint)point;
- (NSRange)getWordRangeAtPoint:(CGPoint)point;
- (NSRange)characterRangeAtIndex:(NSInteger)index;

- (void)responseToLongPress:(UILongPressGestureRecognizer*)gesture;

- (void)refreshLayout;
- (void)refreshView;

- (void)updateSelection;
- (void)redrawContentFrame;

+ (NSDictionary *)getParagraphFormatWithLeftPadding:(CGFloat)leftPadding;

@end
