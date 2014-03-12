//
//  P2MSTextView.h
//  P2MSTextView
//
//  Created by PYAE PHYO MYINT SOE on 3/12/13.
//  Copyright (c) 2013 PYAE PHYO MYINT SOE. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreText/CoreText.h>
#import "P2MSContentView.h"
#import "P2MSGlobalFunctions.h"
#import "P2MSLinkViewController.h"
#import "P2MSParagraph.h"

typedef enum {
    KEYBOARD_TYPE_DEFAULT,
    KEYBOARD_TYPE_FORMAT
}KEYBOARD_TYPE;

@class P2MSTextView;

@protocol P2MSTextViewDelegate <NSObject, UIScrollViewDelegate>
@optional

- (BOOL)p2msTextViewShouldBeginEditing:(P2MSTextView *)textView;
- (BOOL)p2msTextViewShouldEndEditing:(P2MSTextView *)textView;
- (void)p2msTextViewDidBeginEditing:(P2MSTextView *)textView;
- (void)p2msTextViewDidEndEditing:(P2MSTextView *)textView;

- (void)p2msTextViewDidChange:(P2MSTextView *)textView;
- (void)p2msTextViewDidChangeSelection:(P2MSTextView *)textView;

- (void)p2msTextViewLinkAdded:(P2MSTextView *)textView andLink:(P2MSLink *)link;
- (void)p2msTextViewLinkClicked:(P2MSTextView *)textView andLink:(P2MSLink *)link;

@end


@interface P2MSTextView : UIScrollView<UITextInput, UIGestureRecognizerDelegate, P2MSLinkViewControllerDelegate>

@property (nonatomic)BOOL editable;
@property(nonatomic,unsafe_unretained) id <P2MSTextViewDelegate> textViewDelegate;

@property (nonatomic, readonly)TEXT_ATTRIBUTE curTextStyle;

@property (nonatomic, retain) NSDictionary *fontNames, *fontSizes;
@property (nonatomic, retain) NSDictionary *fontColors;

@property(readwrite, retain) UIView *inputAccessoryView;

@property (nonatomic, readonly) P2MSParagraphs *paragraphs;

@property (nonatomic, readonly) UILongPressGestureRecognizer *longPressGestureRecognizer;
@property (nonatomic, readonly) UITapGestureRecognizer *tapGestureRecognizer, *doubleTapGestureRecognizer;

@property (nonatomic) NSRange markedRange; // Marked text range (for input method marked text).
@property (nonatomic) NSRange selectedRange; // Selected text range.
@property (nonatomic) NSRange correctionRange;

@property (nonatomic, readonly) KEYBOARD_TYPE activeKeyboardType;
@property (nonatomic) NSString *plainText;
@property (nonatomic) BOOL canDisplayCustomKeyboard;

@property (nonatomic) UIEdgeInsets edgeInsets;

- (NSMutableDictionary *)getStyleAttributes;

- (void)setAction:(TEXT_ATTRIBUTE)txtFormat;

- (void)toggleKeyboard;

//hide kb if you call the same keyboard type twice
- (void)showKeyboard:(KEYBOARD_TYPE)kbType;

//HTML related
- (NSString *)exportHTMLString;
- (void) importHTMLString:(NSString *)htmlString;


@end
