//
//  P2MSContentView.h
//  P2MSTextView
//
//  Created by PYAE PHYO MYINT SOE on 18/5/13.
//  Copyright (c) 2013 Pyae Phyo MS. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "P2MSCaretView.h"
#import "P2MSSelectionView.h"
#import "P2MSTextView.h"

#define PARAGRAPH_FONT_SIZE 15
#define SECTION_FONT_SIZE 32
#define SUB_SECTION_FONT_SIZE 23

@interface P2MSContentView : UIView{
    P2MSSelectionView    *selectionView;
    P2MSTextWindow *textWindow;
    BOOL isDrawing;
}

@property (nonatomic, copy) NSString *contentText;
@property (nonatomic, getter=isEditing) BOOL editing; // Is view in "editing" mode or not (affects drawn results).
@property (nonatomic) NSRange markedTextRange; // Marked text range (for input method marked text).
@property (nonatomic) NSRange selectedTextRange; // Selected text range.
@property (nonatomic) NSRange correctionRange;
@property (nonatomic) P2MSCaretView *caretView;
@property (nonatomic) CGFloat fontSize;

@property (nonatomic, readonly) NSMutableAttributedString *attributedString;
@property (nonatomic, unsafe_unretained) P2MSTextView *parentView;

- (CGRect)caretRectForIndex:(int)index;
- (CGRect)firstRectForRange:(NSRange)range;
- (NSInteger)closestIndexToPoint:(CGPoint)point;
- (NSInteger)closestWhitespaceToPoint:(CGPoint)point;
- (NSRange)getWordRangeAtPoint:(CGPoint)point;
- (NSRange)characterRangeAtIndex:(NSInteger)index;

- (void)responseToLongPress:(UILongPressGestureRecognizer*)gesture;
- (P2MSSelectionView *)selectionView;

- (void)refreshLayout;
- (void)refreshView;

- (void)selectionChanged;
- (void)textChanged;
- (void)setFontName:(NSString *)newFontName withSize:(CGFloat) fontSize;

+ (NSDictionary *)getParagraphFormatWithLeftPadding:(CGFloat)leftPadding;

@end
