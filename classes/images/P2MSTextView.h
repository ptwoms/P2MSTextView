//
//  P2MSTextView.h
//  P2MSTextView
//
//  Created by PYAE PHYO MYINT SOE on 18/5/13.
//  Copyright (c) 2013 Pyae Phyo MS. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreText/CoreText.h>
#include <objc/runtime.h>
#import "P2MSCaretView.h"
#import "P2MSTextWindow.h"
#import "P2MSDocument.h"
#import "P2MSLinkViewController.h"

#define kNormalFont @"P2MSTEXTVIEW-NORMAL-FONT"
#define kBoldFont @"P2MSTEXTVIEW-BOLD-FONT"
#define kItalicFont @"P2MSTEXTVIEW-ITALIC-FONT"
#define kBoldItalicFont @"P2MSTEXTVIEW-BOLD-ITALIC-FONT"


@class P2MSTextView;

@protocol P2MSTextViewDelegate <NSObject, UIScrollViewDelegate>
@optional

//- (BOOL)p2msTextViewShouldBeginEditing:(P2MSTextView *)textView;
//- (BOOL)p2msTextViewShouldEndEditing:(P2MSTextView *)textView;
- (void)p2msTextViewDidBeginEditing:(P2MSTextView *)textView;
- (void)p2msTextViewDidEndEditing:(P2MSTextView *)textView;

- (void)p2msTextViewDidChange:(P2MSTextView *)textView;
- (void)p2msTextViewDidChangeSelection:(P2MSTextView *)textView;

- (void)p2msTextViewLinkAdded:(P2MSTextView *)textView andLink:(P2MSLink *)link;
- (void)p2msTextViewLinkClicked:(P2MSTextView *)textView andLink:(P2MSLink *)link;

@end


@interface P2MSTextView : UIScrollView<UITextInput, UIGestureRecognizerDelegate, P2MSLinkViewControllerDelegate>

@property(nonatomic, readonly) UILongPressGestureRecognizer *longPressGR;
@property (nonatomic)BOOL editable;
@property (nonatomic)BOOL showingCorrectionMenu;
@property(nonatomic,unsafe_unretained) id <P2MSTextViewDelegate> textViewDelegate;
@property(readwrite, retain) UIView *inputAccessoryView;

- (PARAGRAPH_FORMAT)getCurParagraphFormat;
- (NSMutableDictionary *)getAttributes;

+ (CGFloat)suggestHeightForHTMLText:(NSString *)htmlText Width:(CGFloat)widthConstraint withFonts:(NSDictionary *)fonts;

- (void)toggleNormalKeyboard;
- (void)toggleFormattingKeyboard;

- (CGFloat)getTextViewHeight;


- (NSString *)exportHTMLString;
- (void) importHTMLString:(NSString *)htmlString;

@end
