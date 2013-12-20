//
//  P2MSTextView.m
//  P2MSTextView
//
//  Created by PYAE PHYO MYINT SOE on 18/5/13.
//  Copyright (c) 2013 Pyae Phyo MS. All rights reserved.
//

#import "P2MSTextView.h"
#import "P2MSIndexedPosition.h"
#import "P2MSIndexedRange.h"
#import "P2MSContentView.h"
#import <QuartzCore/QuartzCore.h>
#import "GTMNSString+HTML.h"

@interface P2MSHTMLNode : NSObject

@property(nonatomic, retain) NSString *content, *htmlTag;
@property (nonatomic, retain) NSMutableArray *children;
@property (nonatomic, retain) NSMutableDictionary *attributes;
@property (nonatomic) NSRange range;

@end

@implementation P2MSHTMLNode

- (NSMutableDictionary *)attributes{
    if (!_attributes) {
        _attributes = [NSMutableDictionary dictionary];
    }
    return _attributes;
}
@end


@interface P2MSTextView()<UIGestureRecognizerDelegate>{
    
    //char & paragraph Formatting
    NSRange curActionRange;
    NSRange curSetActionRange;
    NSRange curParaRange;
    TEXT_FORMAT curTextFormat;
    TEXT_FORMAT curSetTextFormat;
    PARAGRAPH_FORMAT curParagraphFormat;
    
    NSMutableArray *curAttributes;
    NSMutableSet *curParagraphs;
    NSMutableSet *links;
    
    //formatting KB
    UIView *styleBaseView;
    
    //delegate method test
    BOOL responseToDidSelectionChange;
    BOOL willHandleLink;
    
    P2MSTextWindow *textWindow;
    
    UITextInputStringTokenizer *tokenizer;
    UITextChecker *textChecker;
    
    NSMutableDictionary *menuItemActions;
    NSString *language;
    
    BOOL _showKeyboard;
}

@property (nonatomic) NSMutableString *text;
@property (nonatomic, retain) P2MSContentView *textView;

@end

@implementation P2MSTextView
@synthesize markedTextStyle = _markedTextStyle;
@synthesize inputDelegate = _inputDelegate;
@synthesize autocorrectionType = _autocorrectionType;
@synthesize keyboardType = _keyboardType;
@synthesize inputAccessoryView = _inputAccessoryView;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        willHandleLink = NO;
        _showKeyboard = YES;
        
        self.autocorrectionType = UITextAutocorrectionTypeNo;
        
        curAttributes = [NSMutableArray array];
        curParagraphs = [NSMutableSet set];
        links = [NSMutableSet set];
        
        curActionRange = NSMakeRange(0, 0);
        curParaRange = NSMakeRange(NSNotFound, 0);
        curParagraphFormat = TEXT_PARAGRAPH;
        curTextFormat = TEXT_FORMAT_NONE;
        
        self.text = [[NSMutableString alloc] init];
        self.editable = YES;
        self.userInteractionEnabled = YES;
        self.autoresizesSubviews = YES;
        
        _textView = [[P2MSContentView alloc] initWithFrame:CGRectMake(8, 8, frame.size.width-16, frame.size.height-16)];
        _textView.parentView = self;
        [self addSubview:_textView];
        _textView.userInteractionEnabled = NO;
        
        //setup gesture recognizers
        UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tap:)];
        [self addGestureRecognizer:tapGestureRecognizer];
        tapGestureRecognizer.delegate = self;

        _longPressGR = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPress:)];
        _longPressGR.delegate = (id<UIGestureRecognizerDelegate>)self;
        [self addGestureRecognizer:_longPressGR];
        
        UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(doubleTap:)];
        [doubleTap setNumberOfTapsRequired:2];
        [self addGestureRecognizer:doubleTap];
        
        language = [[UITextChecker availableLanguages] objectAtIndex:0];
        if (!language) {
            language = @"en_US";
        }

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(orientationChanged:) name:UIDeviceOrientationDidChangeNotification object:nil];
    }
    return self;
}

- (void)dealloc{
    [[NSNotificationCenter defaultCenter]removeObserver:self name:UIDeviceOrientationDidChangeNotification object:nil];
}

- (void)setFontName:(NSString *)fontName withSize:(CGFloat)fontSize{
    [_textView setFontName:fontName withSize:fontSize];
}

- (void)setDelegate:(id<UIScrollViewDelegate>)delegate{
    [super setDelegate:delegate];
    self.textViewDelegate = (id<P2MSTextViewDelegate>)delegate;
    responseToDidSelectionChange = [_textViewDelegate respondsToSelector:@selector(p2msTextViewDidChangeSelection:)];
}

- (void)setFontSize:(CGFloat)fontSize{
    _textView.fontSize = fontSize;
}

- (void)setTextViewDelegate:(id<P2MSTextViewDelegate>)textViewDelegate{
    _textViewDelegate = textViewDelegate;
    willHandleLink = (_textViewDelegate && [_textViewDelegate respondsToSelector:@selector(p2msTextViewLinkClicked:andLink:)]);
}

- (void)setP2msText:(NSString *)p2msText{
    if (p2msText) {
        [self insertText:p2msText];
    }
}

- (NSString *)p2msText{
    return _text;
}

- (PARAGRAPH_FORMAT)getCurParagraphFormat{
    return curParagraphFormat;
}

- (BOOL)canBecomeFirstResponder
{
    return YES;
}

- (BOOL)becomeFirstResponder {
    BOOL val = [super becomeFirstResponder];
    if (val && _editable) {
        self.textView.editing = YES;
        if (self.textViewDelegate && [self.textViewDelegate respondsToSelector:@selector(p2msTextViewDidBeginEditing:)]) {
            [self.textViewDelegate p2msTextViewDidBeginEditing:self];
        }
    }
    return val;
}

- (BOOL)resignFirstResponder {
    if (_editable) {
        self.textView.editing = NO;
        if (self.textViewDelegate && [self.textViewDelegate respondsToSelector:@selector(p2msTextViewDidEndEditing:)]) {
            [self.textViewDelegate p2msTextViewDidEndEditing:self];
        }
        [self.textView selectionChanged];
    }
	return [super resignFirstResponder];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gesture shouldReceiveTouch:(UITouch *)touch
{
    return (touch.view == self);
}

#pragma mark Gesture Recognizer methods
- (void)tap:(UITapGestureRecognizer *)tap
{
    curSetTextFormat = TEXT_FORMAT_NOT_SET;
    if ([self isFirstResponder]) {
        
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(showMenu) object:nil];
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(showCorrectionMenu) object:nil];
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(showRelevantMenu) object:nil];
        
        NSInteger index = [self.textView closestWhitespaceToPoint:[tap locationInView:self.textView]];
        [self setCorrectionRange:NSMakeRange(NSNotFound, 0)];
        UIMenuController *menuController = [UIMenuController sharedMenuController];
        
        if (index == _textView.selectedTextRange.location) {
            if ([menuController isMenuVisible]) {
                [menuController setMenuVisible:NO animated:NO];
            }else if (_editable){
                [self performSelector:@selector(showRelevantMenu) withObject:nil afterDelay:0.35f];
            }else
                [self performSelector:@selector(showMenu) withObject:nil afterDelay:0.35f];
        }else{
            if ([menuController isMenuVisible]) {
                [menuController setMenuVisible:NO animated:NO];
            }
            if(_editable)
                [self performSelector:@selector(showCorrectionMenu) withObject:nil afterDelay:0.35f];
        }
        [self.inputDelegate selectionWillChange:self];
        
        if (_editable) {
            if (curParaRange.location != NSNotFound) {
                if (!NSLocationInRange(index, curParaRange)) {
                    P2MSParagraph *para = [[P2MSParagraph alloc]init];
                    para.paraFormat = curParagraphFormat;
                    para.formatRange = curParaRange;
                    [curParagraphs addObject:para];
                    curParaRange = NSMakeRange(NSNotFound, 0);
                    curParagraphFormat = TEXT_PARAGRAPH;
                }
            }
            if (curParaRange.location == NSNotFound) {
                NSInteger indexToConsider = index;
                if (index == _text.length) {
                    indexToConsider = index-1;
                }
                for (P2MSParagraph *curPara in curParagraphs) {
                    if (NSLocationInRange(indexToConsider, curPara.formatRange)) {
                        curParagraphFormat = curPara.paraFormat;
                        curParaRange = curPara.formatRange;
                        [curParagraphs removeObject:curPara];break;
                    }
                }
            }
            NSInteger indexToTest = index-1;
            if (index > 0 && [_text characterAtIndex:indexToTest] == '\n') {
                indexToTest = index;
            }else if (index > 0) {
                if (curParaRange.location == NSNotFound) {
                    for (P2MSParagraph *curPara in curParagraphs) {
                        if (NSLocationInRange(index-1, curPara.formatRange)) {
                            indexToTest = index;break;
                        }
                    }
                }
            }else
                indexToTest = index;
            
            [self reflectFormatForLocationChange:indexToTest];
            [self reflectIconForActionChange];
        }
        _textView.markedTextRange = NSMakeRange(NSNotFound, 0);
        _textView.selectedTextRange = NSMakeRange(index, 0);
        [self.inputDelegate selectionDidChange:self];
    }
    else {
        [self becomeFirstResponder];
        if (_editable) {
            self.textView.editing = YES;
        }
    }
    if (!_editable) {
        NSInteger index = [self.textView closestWhitespaceToPoint:[tap locationInView:self.textView]];
        _textView.selectedTextRange = NSMakeRange(index, 0);
        for (P2MSLink *curLink in links) {
            if (NSLocationInRange(index, curLink.formatRange)) {
                if (willHandleLink) {
                    [_textViewDelegate p2msTextViewLinkClicked:self andLink:curLink];
                }
                break;
            }
        }
    }
    //		[self.editableCoreTextViewDelegate editableCoreTextViewWillEdit:self];
}

- (void)doubleTap:(UITapGestureRecognizer*)gesture {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(showMenu) object:nil];
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(showCorrectionMenu) object:nil];
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(showRelevantMenu) object:nil];
    
    NSRange range = [self.textView getWordRangeAtPoint:[gesture locationInView:self.textView]];
    NSRange oldRange = self.textView.selectedTextRange;
    if (range.location!=NSNotFound){
        self.textView.selectedTextRange = range;
        if (![[UIMenuController sharedMenuController] isMenuVisible]) {
            [self performSelector:@selector(showMenu) withObject:nil afterDelay:0.1f];
        }
    }
    if (responseToDidSelectionChange && !NSEqualRanges(oldRange, range)) {
        [self.textViewDelegate p2msTextViewDidChangeSelection:self];
    }
}

- (void)longPress:(UILongPressGestureRecognizer*)gesture {
    curSetTextFormat = TEXT_FORMAT_NOT_SET;
    [self.textView responseToLongPress:gesture];
    if (gesture.state==UIGestureRecognizerStateBegan || gesture.state == UIGestureRecognizerStateChanged) {
        NSInteger index = _textView.selectedTextRange.location;
        if (curParaRange.location != NSNotFound) {
            if (!NSLocationInRange(index, curParaRange)) {
                P2MSParagraph *para = [[P2MSParagraph alloc]init];
                para.paraFormat = curParagraphFormat;
                para.formatRange = curParaRange;
                [curParagraphs addObject:para];
                curParaRange = NSMakeRange(NSNotFound, 0);
                curParagraphFormat = TEXT_PARAGRAPH;
            }
        }
        if (curParaRange.location == NSNotFound) {
            for (P2MSParagraph *curPara in curParagraphs) {
                if (NSLocationInRange(index, curPara.formatRange)) {
                    curParagraphFormat = curPara.paraFormat;
                    curParaRange = curPara.formatRange;
                    [curParagraphs removeObject:curPara];break;
                }
            }
        }
        
        NSInteger indexToTest = index;
        if (index > 0) {
            if (curParaRange.location == NSNotFound) {
                for (P2MSParagraph *curPara in curParagraphs) {
                    if (NSLocationInRange(index-1, curPara.formatRange)) {
                        indexToTest = index;
                        break;
                    }
                }
            }
        }else
            indexToTest = index;
        
        [self reflectFormatForLocationChange:indexToTest];
        [self reflectIconForActionChange];
        
        UIMenuController *menuController = [UIMenuController sharedMenuController];
        if ([menuController isMenuVisible]) {
            [menuController setMenuVisible:NO animated:NO];
        }
    }else if (gesture.state == UIGestureRecognizerStateEnded) {
        if (_textView.selectedTextRange.location!=NSNotFound) {
            [self showMenu];
        }
    }
}

- (void)reflectFormatForLocationChange:(NSUInteger)index{
    if (index == _text.length) {
        if (index != curActionRange.location+curActionRange.length) {
            P2MSTextFormat *lastFormat = [curAttributes lastObject];
            if (lastFormat) {
                [self saveCurrentAttributes];
                [curAttributes removeObject:lastFormat];
                curActionRange = lastFormat.formatRange;
                curTextFormat = lastFormat.txtFormat;
            }
        }
    }else if (!NSLocationInRange(index, curActionRange)) {
        [self saveCurrentAttributes];
        for (P2MSTextFormat *curFormat in curAttributes) {
            if (NSLocationInRange(index, curFormat.formatRange)){
                curActionRange = curFormat.formatRange;
                curTextFormat = curFormat.txtFormat;
                [curAttributes removeObject:curFormat];
                break;
            }
        }
    }
}

- (void)forceReflectFormatForLocationChange:(NSUInteger)index{
    if (index == _text.length) {
        P2MSTextFormat *lastFormat = [curAttributes lastObject];
        if (lastFormat) {
            [curAttributes removeObject:lastFormat];
            curActionRange = lastFormat.formatRange;
            curTextFormat = lastFormat.txtFormat;
        }
    }else{
        for (P2MSTextFormat *curFormat in curAttributes) {
            if (NSLocationInRange(index, curFormat.formatRange)){
                curActionRange = curFormat.formatRange;
                curTextFormat = curFormat.txtFormat;
                [curAttributes removeObject:curFormat];
                break;
            }
        }
    }
}

- (void)reflectIconForActionChange{
    if (styleBaseView) {
        UIButton *boldBtn = (UIButton *)[styleBaseView.subviews objectAtIndex:0];
        BOOL isToApply = (curSetTextFormat!=TEXT_FORMAT_NOT_SET)?curSetTextFormat&TEXT_BOLD:curTextFormat&TEXT_BOLD;
        [boldBtn setImage:[UIImage imageNamed:(isToApply)?@"bold-icon-hover":@"bold-icon"] forState:UIControlStateNormal];
        
        UIButton *italicBtn = (UIButton *)[styleBaseView.subviews objectAtIndex:1];
        isToApply = (curSetTextFormat!=TEXT_FORMAT_NOT_SET)?curSetTextFormat&TEXT_ITALIC:curTextFormat&TEXT_ITALIC;
        [italicBtn setImage:[UIImage imageNamed:(isToApply)?@"italic-icon-hover":@"italic-icon"] forState:UIControlStateNormal];
        
        UIButton *underline = (UIButton *)[styleBaseView.subviews objectAtIndex:2];
        isToApply = (curSetTextFormat!=TEXT_FORMAT_NOT_SET)?curSetTextFormat&TEXT_UNDERLINE:curTextFormat&TEXT_UNDERLINE;
        [underline setImage:[UIImage imageNamed:(isToApply)?@"underline-icon-hover":@"underline-icon"] forState:UIControlStateNormal];
        
        UIButton *strikethrough = (UIButton *)[styleBaseView.subviews objectAtIndex:3];
        isToApply = (curSetTextFormat!=TEXT_FORMAT_NOT_SET)?curSetTextFormat&TEXT_STRIKE_THROUGH:curTextFormat&TEXT_STRIKE_THROUGH;
        [strikethrough setImage:[UIImage imageNamed:(isToApply)?@"strike-icon-hover":@"strike-icon"] forState:UIControlStateNormal];
        
        UIButton *highlight = (UIButton *)[styleBaseView.subviews objectAtIndex:4];
        isToApply = (curSetTextFormat!=TEXT_FORMAT_NOT_SET)?curSetTextFormat&TEXT_HIGHLIGHT:curTextFormat&TEXT_HIGHLIGHT;
        [highlight setImage:[UIImage imageNamed:(isToApply)?@"highlight-icon-hover":@"highlight-icon"] forState:UIControlStateNormal];
        
        UIButton *bullet = (UIButton *)[styleBaseView.subviews objectAtIndex:5];
        isToApply = curParagraphFormat == TEXT_BULLET;
        [bullet setImage:[UIImage imageNamed:(isToApply)?@"bullet-hover":@"bullet"] forState:UIControlStateNormal];
        
        UIButton *numbering = (UIButton *)[styleBaseView.subviews objectAtIndex:6];
        isToApply = curParagraphFormat == TEXT_NUMBERING;
        [numbering setImage:[UIImage imageNamed:(isToApply)?@"numbering-hover":@"numbering"] forState:UIControlStateNormal];
    }
}


//- (P2MSTextWindow*)getTextWindow {
//    if (textWindow==nil) {
//        for (P2MSTextWindow *aWindow in [[UIApplication sharedApplication] windows]){
//            if ([aWindow isKindOfClass:[P2MSTextWindow class]]) {
//                textWindow = aWindow;
//                textWindow.frame = [[UIScreen mainScreen] bounds];
//                break;
//            }
//        }
//        if (textWindow==nil) {
//            textWindow = [[P2MSTextWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
//        }
//        textWindow.windowLevel = UIWindowLevelStatusBar;
//        textWindow.hidden = NO;
//    }
//    return textWindow;
//}


#pragma mark - UITextInput methods
#pragma mark UITextInput - Replacing and Returning Text

/**
 UITextInput protocol required method.
 Called by text system to get the string for a given range in the text storage.
 */
- (NSString *)textInRange:(UITextRange *)range
{
    P2MSIndexedRange *r = (P2MSIndexedRange *)range;
    return ([self.text substringWithRange:r.range]);
}


/**
 UITextInput protocol required method.
 Called by text system to replace the given text storage range with new text.
 */
- (void)replaceRange:(UITextRange *)range withText:(NSString *)text
{
    curSetActionRange = NSMakeRange(NSNotFound, 0);
    curSetTextFormat = TEXT_FORMAT_NOT_SET;
    
    P2MSIndexedRange *indexedRange = (P2MSIndexedRange *)range;
	// Determine if replaced range intersects current selection range
	// and update selection range if so.
    NSRange selectedNSRange = self.textView.selectedTextRange;
    if ((indexedRange.range.location + indexedRange.range.length) <= selectedNSRange.location) {
        selectedNSRange.location -= (indexedRange.range.length - text.length);
    } else {
        // Need to also deal with overlapping ranges.
    }
    [self.text replaceCharactersInRange:indexedRange.range withString:text];
    [self replaceTextFormatAtRange:indexedRange.range withText:text andSelectedRange:selectedNSRange];
    [self replaceParagraphFormatAtRange:indexedRange.range withText:text rangeAfter:selectedNSRange];
    [self.textView setContentText:self.text];
    self.textView.selectedTextRange = selectedNSRange;
    [self adjustScrollView];
}

#pragma mark UITextInput - Working with Marked and Selected Text
- (UITextRange *)selectedTextRange
{
    return [P2MSIndexedRange indexedRangeWithRange:self.textView.selectedTextRange];
}


- (void)setSelectedTextRange:(UITextRange *)range
{
    P2MSIndexedRange *indexedRange = (P2MSIndexedRange *)range;
    self.textView.selectedTextRange = indexedRange.range;
}

- (UITextRange *)markedTextRange
{
    NSRange markedTextRange = self.textView.markedTextRange;
    if (markedTextRange.length == 0) {
        return nil;
    }
    return [P2MSIndexedRange indexedRangeWithRange:markedTextRange];
}

/**
 UITextInput protocol required method.
 Insert the provided text and marks it to indicate that it is part of an active input session.
 */
- (void)setMarkedText:(NSString *)markedText selectedRange:(NSRange)selectedRange
{
    NSRange selectedNSRange = self.textView.selectedTextRange;
    NSRange markedTextRange = self.textView.markedTextRange;
    NSRange affectedRange;
    if (markedTextRange.location != NSNotFound) {
        if (!markedText)
            markedText = @"";
		// Replace characters in text storage and update markedText range length.
        [self.text replaceCharactersInRange:markedTextRange withString:markedText];
        affectedRange = markedTextRange;
        markedTextRange.length = markedText.length;
    }
    else if (selectedNSRange.length > 0) {
		// There currently isn't a marked text range, but there is a selected range,
		// so replace text storage at selected range and update markedTextRange.
        [self.text replaceCharactersInRange:selectedNSRange withString:markedText];
        affectedRange = selectedNSRange;
        markedTextRange.location = selectedNSRange.location;
        markedTextRange.length = markedText.length;
    }
    else {
		// There currently isn't marked or selected text ranges, so just insert
		// given text into storage and update markedTextRange.
        [self.text insertString:markedText atIndex:selectedNSRange.location];
        affectedRange = selectedNSRange;
        markedTextRange.location = selectedNSRange.location;
        markedTextRange.length = markedText.length;
    }
	// Updated selected text range and underlying ContentView.
    selectedNSRange = NSMakeRange(selectedRange.location + markedTextRange.location, selectedRange.length);
    [self replaceTextFormatAtRange:affectedRange withText:markedText andSelectedRange:selectedNSRange];
    [self replaceParagraphFormatAtRange:affectedRange withText:markedText rangeAfter:selectedNSRange];
    [self.textView setContentText:self.text];
    self.textView.markedTextRange = markedTextRange;
    self.textView.selectedTextRange = selectedNSRange;
    [self adjustScrollView];
}

/**
 UITextInput protocol required method.
 Unmark the currently marked text.
 */
- (void)unmarkText
{
    NSRange markedTextRange = self.textView.markedTextRange;
    
    if (markedTextRange.location == NSNotFound) {
        return;
    }
    markedTextRange.location = NSNotFound;
    self.textView.markedTextRange = markedTextRange;
}


#pragma mark UITextInput - Computing Text Ranges and Text Positions
// UITextInput beginningOfDocument property accessor override.
- (UITextPosition *)beginningOfDocument
{
    return [P2MSIndexedPosition positionWithIndex:0];
}


// UITextInput endOfDocument property accessor override.
- (UITextPosition *)endOfDocument
{
    return [P2MSIndexedPosition positionWithIndex:self.text.length];
}


/*
 UITextInput protocol required method.
 Return the range between two text positions using our implementation of UITextRange.
 */
- (UITextRange *)textRangeFromPosition:(UITextPosition *)fromPosition toPosition:(UITextPosition *)toPosition
{
	// Generate IndexedPosition instances that wrap the to and from ranges.
    P2MSIndexedPosition *fromIndexedPosition = (P2MSIndexedPosition *)fromPosition;
    P2MSIndexedPosition *toIndexedPosition = (P2MSIndexedPosition *)toPosition;
    NSRange range = NSMakeRange(MIN(fromIndexedPosition.index, toIndexedPosition.index), ABS(toIndexedPosition.index - fromIndexedPosition.index));
    
    return [P2MSIndexedRange indexedRangeWithRange:range];
}


- (UITextPosition *)positionFromPosition:(UITextPosition *)position offset:(NSInteger)offset
{
	// Generate IndexedPosition instance, and increment index by offset.
    P2MSIndexedPosition *indexedPosition = (P2MSIndexedPosition *)position;
    NSInteger end = indexedPosition.index + offset;
	// Verify position is valid in document.
    if (end > self.text.length || end < 0) {
        return nil;
    }
    return [P2MSIndexedPosition positionWithIndex:end];
}


/**
 UITextInput protocol required method.
 Returns the text position at a given offset in a specified direction from another text position using our implementation of UITextPosition.
 */
- (UITextPosition *)positionFromPosition:(UITextPosition *)position inDirection:(UITextLayoutDirection)direction offset:(NSInteger)offset
{
    // left-to-right text direction.
    P2MSIndexedPosition *indexedPosition = (P2MSIndexedPosition *)position;
    NSInteger newPosition = indexedPosition.index;
    switch ((NSInteger)direction) {
        case UITextLayoutDirectionRight:
            newPosition += offset;
            break;
        case UITextLayoutDirectionLeft:
            newPosition -= offset;
            break;
        UITextLayoutDirectionUp:
        UITextLayoutDirectionDown:
			// write code here to support vertical text directions.
            break;
    }
    // Verify new position valid in document.
    if (newPosition < 0)
        newPosition = 0;
    if (newPosition > self.text.length)
        newPosition = self.text.length;
    
    return [P2MSIndexedPosition positionWithIndex:newPosition];
}


#pragma mark UITextInput - Evaluating Text Positions

/**
 UITextInput protocol required method.
 Return how one text position compares to another text position.
 */
- (NSComparisonResult)comparePosition:(UITextPosition *)position toPosition:(UITextPosition *)other
{
    P2MSIndexedPosition *indexedPosition = (P2MSIndexedPosition *)position;
    P2MSIndexedPosition *otherIndexedPosition = (P2MSIndexedPosition *)other;
    
	// compare position index values.
    if (indexedPosition.index < otherIndexedPosition.index) {
        return NSOrderedAscending;
    }
    if (indexedPosition.index > otherIndexedPosition.index) {
        return NSOrderedDescending;
    }
    return NSOrderedSame;
}


/**
 UITextInput protocol required method.
 Return the number of visible characters between one text position and another text position.
 */
- (NSInteger)offsetFromPosition:(UITextPosition *)from toPosition:(UITextPosition *)toPosition
{
    P2MSIndexedPosition *fromIndexedPosition = (P2MSIndexedPosition *)from;
    P2MSIndexedPosition *toIndexedPosition = (P2MSIndexedPosition *)toPosition;
    return (toIndexedPosition.index - fromIndexedPosition.index);
}


#pragma mark UITextInput - Text Layout, writing direction and position related methods
// assume left-to-right text direction.
- (UITextPosition *)positionWithinRange:(UITextRange *)range farthestInDirection:(UITextLayoutDirection)direction
{
    P2MSIndexedRange *indexedRange = (P2MSIndexedRange *)range;
    NSInteger position;
    switch (direction) {
        case UITextLayoutDirectionUp:
        case UITextLayoutDirectionLeft:
            position = indexedRange.range.location;
            break;
        case UITextLayoutDirectionRight:
        case UITextLayoutDirectionDown:
            position = indexedRange.range.location + indexedRange.range.length;
            break;
    }
    
	// Return text position using our UITextPosition implementation.
	// Note that position is not currently checked against document range.
    return [P2MSIndexedPosition positionWithIndex:position];
}


/**
 UITextInput protocol required method.
 Return a text range from a given text position to its farthest extent in a certain direction of layout.
 */
// assume left-to-right text direction.
- (UITextRange *)characterRangeByExtendingPosition:(UITextPosition *)position inDirection:(UITextLayoutDirection)direction
{
    P2MSIndexedPosition *pos = (P2MSIndexedPosition *)position;
    NSRange result;
    
    switch (direction) {
        case UITextLayoutDirectionUp:
        case UITextLayoutDirectionLeft:
            result = NSMakeRange(pos.index - 1, 1);
            break;
        case UITextLayoutDirectionRight:
        case UITextLayoutDirectionDown:
            result = NSMakeRange(pos.index, 1);
            break;
    }
    
    // Return range using our UITextRange implementation.
	// Note that range is not currently checked against document range.
    return [P2MSIndexedRange indexedRangeWithRange:result];
}


/**
 UITextInput protocol required method.
 Return the base writing direction for a position in the text going in a specified text direction.
 */
// assume left-to-right text direction.
- (UITextWritingDirection)baseWritingDirectionForPosition:(UITextPosition *)position inDirection:(UITextStorageDirection)direction
{
    return UITextWritingDirectionLeftToRight;
}


/**
 UITextInput protocol required method.
 Set the base writing direction for a given range of text in a document.
 */
- (void)setBaseWritingDirection:(UITextWritingDirection)writingDirection forRange:(UITextRange *)range
{
}


#pragma mark UITextInput - Geometry methods

/**
 UITextInput protocol required method.
 Return the first rectangle that encloses a range of text in a document.
 */
- (CGRect)firstRectForRange:(UITextRange *)range
{
    P2MSIndexedRange *r = (P2MSIndexedRange *)range;
    CGRect rect = [self.textView firstRectForRange:r.range];
	// Convert rect to our view coordinates.
    return [self convertRect:rect fromView:self.textView];
}


/*
 UITextInput protocol required method.
 Return a rectangle used to draw the caret at a given insertion point.
 */
- (CGRect)caretRectForPosition:(UITextPosition *)position
{
    P2MSIndexedPosition *pos = (P2MSIndexedPosition *)position;
    
	// Get caret rect from underlying ContentView.
    CGRect rect =  [self.textView caretRectForIndex:pos.index];
	// Convert rect to our view coordinates.
    return [self convertRect:rect fromView:self.textView];
}


#pragma mark UITextInput - Hit testing

/*
 hit testing methods are not implemented and use the methods in P2MSContentView.
 */

/*
 UITextInput protocol required method.
 Return the position in a document that is closest to a specified point.
 */
- (UITextPosition *)closestPositionToPoint:(CGPoint)point
{
    //P2MSContentView:closestIndexToPoint:point.
    return nil;
}

/*
 UITextInput protocol required method.
 Return the position in a document that is closest to a specified point in a given range.
 */
- (UITextPosition *)closestPositionToPoint:(CGPoint)point withinRange:(UITextRange *)range
{
	// P2MSContentView:closestIndexToPoint:point.
    return nil;
}


/*
 UITextInput protocol required method.
 Return the character or range of characters that is at a given point in a document.
 */
- (UITextRange *)characterRangeAtPoint:(CGPoint)point
{
	// P2MSContentView:closestIndexToPoint:point.
    return nil;
}


/*
 UITextInput protocol required method.
 Return an array of UITextSelectionRects.
 */
- (NSArray *)selectionRectsForRange:(UITextRange *)range
{
    // Not implemented
    return nil;
}


#pragma mark UITextInput - Returning Text Styling Information

/*
 UITextInput protocol required method.
 Return a dictionary with properties that specify how text is to be style at a certain location in a document.
 */
- (NSDictionary *)textStylingAtPosition:(UITextPosition *)position inDirection:(UITextStorageDirection)direction
{
    P2MSIndexedPosition *pos = (P2MSIndexedPosition*)position;
    NSInteger index = MIN(MAX(pos.index, 0), _text.length-1);
    NSDictionary *attribs = [self.textView.attributedString attributesAtIndex:index effectiveRange:nil];
    CTFontRef ctFont = (__bridge CTFontRef)([attribs valueForKey:(NSString*)kCTFontAttributeName]);
    return @{ UITextInputTextFontKey : [UIFont fontWithName:(__bridge NSString*)CTFontCopyFamilyName(ctFont) size:CTFontGetSize(ctFont)] };
}


#pragma mark UIKeyInput methods

/**
 UIKeyInput protocol required method.
 A Boolean value that indicates whether the text-entry objects have any text.
 */
- (BOOL)hasText
{
    return (self.text.length != 0);
}

- (void)replaceTextFormatAtRange:(NSRange)range withText:(NSString *)text andSelectedRange:(NSRange)selectedNSRange{
    NSUInteger length = text.length;
    if (range.length > 0) {
        //delete selected range
        NSMutableArray *newAttributes = [NSMutableArray array];
        [self saveCurrentAttributes];
        curActionRange = NSMakeRange(NSNotFound, 0);
        NSUInteger prevLoc = 0; NSInteger curLength = 0;
        for (P2MSTextFormat *curFormat in curAttributes) {
            NSRange curFormatRange = curFormat.formatRange;
            NSRange intersectRange = NSIntersectionRange(range, curFormat.formatRange);
            curLength = curFormatRange.length;
            if (intersectRange.length > 0) {
                curLength = curLength-(NSInteger)intersectRange.length;
                if (curLength < 0)curLength = 0;
                if (NSLocationInRange(range.location, curFormatRange)) {
                    curTextFormat = curFormat.txtFormat;
                    curActionRange = NSMakeRange(curFormatRange.location, curLength);
                }else if (intersectRange.length == curFormatRange.length) {
                    //remove whole range
                }else{
                    curFormat.formatRange = NSMakeRange(prevLoc, curLength);
                    [newAttributes addObject:curFormat];
                }
            }else{
                curFormat.formatRange = NSMakeRange(prevLoc, curLength);
                [newAttributes addObject:curFormat];
            }
            prevLoc += curLength;
        }
        
        curAttributes = newAttributes;
        if (curActionRange.location == NSNotFound) {
            if (curAttributes.count) {
                [self forceReflectFormatForLocationChange:range.location];
            }else{//no text and set to default
                curActionRange = NSMakeRange(0, 0);
            }
        }
    }
    
    NSInteger loc = range.location;
    for (P2MSTextFormat *curFmt in curAttributes) {
        NSRange curARange = curFmt.formatRange;
        if (loc <= curARange.location) {
            curFmt.formatRange = NSMakeRange(curARange.location +length, curARange.length);
        }
    }
    
    BOOL isEnter = [text isEqualToString:@"\n"];
    //treat it as a new insert
    if (curSetTextFormat != TEXT_FORMAT_NOT_SET && !isEnter) {
        if ( curSetTextFormat != curTextFormat) {
            NSRange insetRange = NSIntersectionRange(curActionRange, NSMakeRange(curSetActionRange.location, (curSetActionRange.length==0)?1:curSetActionRange.length));
            if (insetRange.length != 0) {//cursor is set inside the curret setting and split into two attribs
                P2MSTextFormat *firstPart = [[P2MSTextFormat alloc]init];
                firstPart.formatRange = NSMakeRange(curActionRange.location, insetRange.location-curActionRange.location);
                firstPart.txtFormat = curTextFormat;
                [curAttributes addObject:firstPart];
                
                P2MSTextFormat *secondPart = [[P2MSTextFormat alloc]init];
                secondPart.formatRange = NSMakeRange(curSetActionRange.location+length, curActionRange.length-firstPart.formatRange.length-curSetActionRange.length);
                secondPart.txtFormat = curTextFormat;
                [curAttributes addObject:secondPart];
                [curAttributes sortWithOptions:NSBinarySearchingFirstEqual usingComparator:globalSortBlock];
            }else{
                [self saveCurrentAttributes];
            }
            curActionRange = NSMakeRange(curSetActionRange.location, length);
            curTextFormat = curSetTextFormat;
        }
        curSetTextFormat = TEXT_FORMAT_NOT_SET;
        curSetActionRange = NSMakeRange(NSNotFound, 0);
    }else{
        if(isEnter) {
            if (_text.length > 1 && [_text characterAtIndex:range.location] == '\n') {
                if (range.location+1 < _text.length && [_text characterAtIndex:range.location+1] == '\n') {
                    [self saveCurrentAttributes];
                    curActionRange = NSMakeRange(selectedNSRange.location, 1);
                }else if (selectedNSRange.location != curActionRange.location && NSLocationInRange(selectedNSRange.location, curActionRange)){
                    curActionRange.length += 1;
                    NSInteger oldLength = curActionRange.length;
                    NSInteger newLength = selectedNSRange.location - curActionRange.location;
                    P2MSTextFormat *curtxtFmt = [[P2MSTextFormat alloc]init];
                    curtxtFmt.txtFormat = curTextFormat;
                    curtxtFmt.formatRange = NSMakeRange(curParaRange.location, newLength);
                    [curAttributes addObject:curtxtFmt];
                    curActionRange = NSMakeRange(selectedNSRange.location, oldLength-newLength);
                }
                else{
                    curActionRange.length += 1;
                    [self saveCurrentAttributes];
                    curActionRange = NSMakeRange(selectedNSRange.location, 0);
                }
            }
        }else
            curActionRange.length += length;
    }
}

- (void)replaceParagraphFormatAtRange:(NSRange)affectedRange withText:(NSString *)text rangeAfter:(NSRange)selectedNSRange{
    NSUInteger textLength = text.length;
    
    if (affectedRange.length) {
        [self deleteParagraphFormatForRange:affectedRange withText:text rangeAfter:selectedNSRange];
    }
    
    //insert test inside links
    if (textLength) {
        for (P2MSLink *curLink in links) {
            if (affectedRange.location <= curLink.formatRange.location) {
                curLink.formatRange = NSMakeRange(curLink.formatRange.location+textLength, curLink.formatRange.length);
            }else if(NSLocationInRange(affectedRange.location, curLink.formatRange)){
                curLink.formatRange = NSMakeRange(curLink.formatRange.location, curLink.formatRange.length+textLength);
            }
        }
    }
    
    NSInteger loc = affectedRange.location;
    for (P2MSParagraph *curPara in curParagraphs) {
        NSRange curARange = curPara.formatRange;
        if (loc <= curARange.location) {
            curPara.formatRange = NSMakeRange(curARange.location+textLength, curARange.length);
        }
    }
    
    if(curParaRange.location != NSNotFound){
        if([text isEqualToString:@"\n"] && (curParagraphFormat == TEXT_SECTION || curParagraphFormat == TEXT_SUBSECTION)) {
            BOOL changetxtFormat = YES;
            if (_text.length > 1 && [_text characterAtIndex:affectedRange.location] == '\n') {
                if (affectedRange.location+1 < _text.length && [_text characterAtIndex:affectedRange.location+1] == '\n') {
                }else if (selectedNSRange.location != curParaRange.location && NSLocationInRange(selectedNSRange.location, curParaRange)){
                    curParaRange.length += 1;
                    NSInteger oldLength = curParaRange.length;
                    NSInteger newLength = selectedNSRange.location - curParaRange.location;
                    P2MSParagraph *curPara = [[P2MSParagraph alloc]init];
                    curPara.paraFormat = curParagraphFormat;
                    curPara.formatRange = NSMakeRange(curParaRange.location, newLength);
                    [curParagraphs addObject:curPara];
                    curParaRange = NSMakeRange(selectedNSRange.location, oldLength-newLength);
                    changetxtFormat = NO;
                }
                else{
                    curParaRange.length += 1;
                }
            }
            if (curParaRange.length > 0) {
                P2MSParagraph *curPara = [[P2MSParagraph alloc]init];
                curPara.paraFormat = curParagraphFormat;
                curPara.formatRange = NSMakeRange(curParaRange.location, curParaRange.length);
                [curParagraphs addObject:curPara];
            }
            if (changetxtFormat) {
                curTextFormat = TEXT_FORMAT_NONE;
                [self reflectIconForActionChange];
            }
            curParagraphFormat = TEXT_PARAGRAPH;
            curParaRange = NSMakeRange(NSNotFound, 0);
        }else
            curParaRange.length += text.length;
    }
    
    if (curParaRange.location != NSNotFound && curParaRange.length > 0) {
        P2MSParagraph *curPara = [[P2MSParagraph alloc]init];
        curPara.paraFormat = curParagraphFormat;
        curPara.formatRange = curParaRange;
        [curParagraphs addObject:curPara];
        curParaRange = NSMakeRange(NSNotFound, 0);
    }
    
    [self rearrangeParagraphsWithSelectedRange:selectedNSRange];
    
    if (curParaRange.location == NSNotFound) {
        NSUInteger indexToConsider = selectedNSRange.location;
        if (selectedNSRange.location > 0 && selectedNSRange.location == _text.length) {
            indexToConsider = selectedNSRange.location-1;
            if ([_text characterAtIndex:indexToConsider] == '\n') {
                indexToConsider++;
                for (P2MSParagraph *curPara in curParagraphs) {
                    if (NSLocationInRange(indexToConsider-1, curPara.formatRange)) {
                        if (curPara.paraFormat != TEXT_SUBSECTION && curPara.paraFormat != TEXT_SECTION) {
                            indexToConsider--;
                        }
                        break;
                    }
                }
                
            }
        }
        for (P2MSParagraph *curPara in curParagraphs) {
            NSUInteger index = indexToConsider;
            if ([text isEqualToString:@"\n"] && (curPara.paraFormat == TEXT_SECTION || curPara.paraFormat == TEXT_SUBSECTION)) {
                index = selectedNSRange.location;
            }
            if (NSLocationInRange(index, curPara.formatRange)) {
                curParagraphFormat = curPara.paraFormat;
                curParaRange = curPara.formatRange;
                [curParagraphs removeObject:curPara];break;
            }
        }
    }
}


/**
 UIKeyInput protocol required method.
 Insert a character into the displayed text. Called by the text system when the user has entered simple text.
 */
- (void)insertText:(NSString *)text
{
    //    NSLog(@"Insert Text is called with text \"%@\"", text);
    NSRange selectedNSRange = self.textView.selectedTextRange;
    NSRange markedTextRange = self.textView.markedTextRange;
    NSRange correctionRange = self.textView.correctionRange;

    if (selectedNSRange.location == NSNotFound) {return;}
    NSRange affectedRange;
    if (correctionRange.location != NSNotFound && correctionRange.length > 0){
        affectedRange =  correctionRange;
        [self.text replaceCharactersInRange:correctionRange withString:text];
        selectedNSRange.length = 0;
        selectedNSRange.location = (correctionRange.location+text.length);
        self.textView.correctionRange = NSMakeRange(NSNotFound, 0);
    }else if (markedTextRange.location != NSNotFound) {
        affectedRange = markedTextRange;
		// There is marked text -- replace marked text with user-entered text.
        [self.text replaceCharactersInRange:markedTextRange withString:text];
        selectedNSRange.location = markedTextRange.location + text.length;
        selectedNSRange.length = 0;
        markedTextRange = NSMakeRange(NSNotFound, 0);
    } else if (selectedNSRange.length > 0) {
        affectedRange = selectedNSRange;
		// Replace selected text with user-entered text.
        [self.text replaceCharactersInRange:selectedNSRange withString:text];
        selectedNSRange.length = 0;
        selectedNSRange.location += text.length;
    } else {
        affectedRange = selectedNSRange;
		// Insert user-entered text at current insertion point.
        [self.text insertString:text atIndex:selectedNSRange.location];
        selectedNSRange.location += text.length;
    }
    //working with document
    [self replaceTextFormatAtRange:affectedRange withText:text andSelectedRange:selectedNSRange];
    [self replaceParagraphFormatAtRange:affectedRange withText:text rangeAfter:selectedNSRange];
    
	// Update underlying ContextTextView.
    [self.textView setContentText:self.text];
    self.textView.markedTextRange = markedTextRange;
    self.textView.selectedTextRange = selectedNSRange;
    [self adjustScrollView];
}

- (void)deleteFormatAtRange:(NSRange)range{
    //retriev overlap formattings
    if (!range.length)return;
    NSMutableArray *newAttributes = [NSMutableArray array];
    [self saveCurrentAttributes];
    curActionRange = NSMakeRange(NSNotFound, 0);
    curTextFormat = TEXT_FORMAT_NONE;
    NSUInteger prevLoc = 0; NSInteger curLength = 0;
    for (P2MSTextFormat *curFormat in curAttributes) {
        NSRange curFormatRange = curFormat.formatRange;
        NSRange intersectRange = NSIntersectionRange(range, curFormat.formatRange);
        curLength = 0;
        if (intersectRange.length == curFormatRange.length) {
            if (range.location == curFormatRange.location) {
                curActionRange = NSMakeRange(curFormatRange.location, 0);
                curTextFormat = curFormat.txtFormat;
            }
        }else{
            curLength = (intersectRange.length > 0)?(NSInteger)curFormatRange.length-(NSInteger)intersectRange.length:curFormatRange.length;
            if (curLength >= 0) {
                curFormat.formatRange = NSMakeRange(prevLoc, curLength);
                [newAttributes addObject:curFormat];
            }
        }
        prevLoc += curLength;
    }
    curAttributes = newAttributes;
    if (curActionRange.location == NSNotFound) {
        //reset curFormatRange and currentFormat
        if (curAttributes.count) {
            [self forceReflectFormatForLocationChange:(range.location>=1)?range.location-1:0];
        }else{//no text and set to default
            curActionRange = NSMakeRange(0, 0);
        }
    }
}

/**
 UIKeyInput protocol required method.
 Delete a character from the displayed text. Called by the text system when the user is invoking a delete (e.g. pressing the delete software keyboard key).
 */
- (void)deleteBackward
{
    curSetActionRange = NSMakeRange(NSNotFound, 0);
    curSetTextFormat = TEXT_FORMAT_NOT_SET;
    
    NSRange selectedNSRange = self.textView.selectedTextRange;
    NSRange markedTextRange = self.textView.markedTextRange;
    NSRange correctionRange = _textView.correctionRange;

    NSRange affectedRange = NSMakeRange(NSNotFound, 0);
    if (correctionRange.location != NSNotFound && correctionRange.length > 0) {
        affectedRange = correctionRange;
        [self.text deleteCharactersInRange:correctionRange];
        [self deleteFormatAtRange:correctionRange];
        selectedNSRange.location = correctionRange.location;
        selectedNSRange.length = 0;
        [self setCorrectionRange:NSMakeRange(NSNotFound, 0)];
    }else if (markedTextRange.location != NSNotFound) {
		// There is marked text, so delete it.
        [self.text deleteCharactersInRange:markedTextRange];
        affectedRange = markedTextRange;
        [self deleteFormatAtRange:markedTextRange];//added by P2MS
        selectedNSRange.location = markedTextRange.location;
        selectedNSRange.length = 0;
        markedTextRange = NSMakeRange(NSNotFound, 0);
    }
    else if (selectedNSRange.length > 0) {
		// Delete the selected text.
        [self deleteFormatAtRange:selectedNSRange];//added by P2MS
        affectedRange = selectedNSRange;
        [self.text deleteCharactersInRange:selectedNSRange];
        selectedNSRange.length = 0;
    }
    else if (selectedNSRange.location > 0) {
		// Delete one char of text at the current insertion point.
        selectedNSRange.location--;
        selectedNSRange.length = 1;
        [self deleteFormatAtRange:selectedNSRange];//added by P2MS
        affectedRange = selectedNSRange;
        [self.text deleteCharactersInRange:selectedNSRange];
        selectedNSRange.length = 0;
    }
    [self deleteParagraphFormatForRange:affectedRange withText:@"" rangeAfter:selectedNSRange];
    
    [self.textView setContentText:self.text];
    self.textView.markedTextRange = markedTextRange;
    self.textView.selectedTextRange = selectedNSRange;
    
    [self adjustScrollView];
}

- (void)deleteParagraphFormatForRange:(NSRange)affectedRange withText:(NSString *)text rangeAfter:(NSRange)selectedNSRange{
    if (affectedRange.location == NSNotFound)return;
    //delete links
    NSMutableSet *linkToDelete = [NSMutableSet set];
    for (P2MSLink *curLink in links) {
        NSRange intersetRange = NSIntersectionRange(curLink.formatRange, affectedRange);
        if (intersetRange.length == curLink.formatRange.length) {
            [linkToDelete addObject:curLink];
        }else if (intersetRange.length){
            if (intersetRange.location > curLink.formatRange.location) {
                curLink.formatRange = NSMakeRange(curLink.formatRange.location, curLink.formatRange.length-intersetRange.length);
            }else{
                curLink.formatRange = NSMakeRange(affectedRange.location, curLink.formatRange.length-intersetRange.length);
            }
        }else{
            NSUInteger affectedLoc = affectedRange.location + affectedRange.length;
            if (affectedLoc <= curLink.formatRange.location) {
                curLink.formatRange = NSMakeRange(curLink.formatRange.location-affectedRange.length, curLink.formatRange.length);
            }
        }
    }
    for (P2MSLink *link in linkToDelete) {
        [links removeObject:link];
    }
    
    //delete paragraphs
    if (curParaRange.location != NSNotFound && curParaRange.length > 0) {
        P2MSParagraph *para = [[P2MSParagraph alloc]init];
        para.paraFormat = curParagraphFormat;
        para.formatRange = curParaRange;
        [curParagraphs addObject:para];
    }
    curParaRange = NSMakeRange(NSNotFound, 0);
    NSMutableSet *paraToDele = [NSMutableSet set];
    curParagraphFormat = TEXT_PARAGRAPH;
    for (P2MSParagraph *curPara in curParagraphs) {
        NSRange paraInsideRange = curPara.formatRange;
        NSRange intersetRange = NSIntersectionRange(curPara.formatRange, affectedRange);
        if (intersetRange.length > 0) {
            if (intersetRange.length == paraInsideRange.length) {
                [paraToDele addObject:curPara];
            }else{
                if (curPara.formatRange.location <= affectedRange.location) {
                    curPara.formatRange = NSMakeRange(curPara.formatRange.location, curPara.formatRange.length-intersetRange.length);
                }else{
                    BOOL releasePreNewLine = (affectedRange.location > 0) && ([_text characterAtIndex:affectedRange.location] == '\n') && ([_text characterAtIndex:affectedRange.location-1] != '\n');
                    NSInteger finalLength = curPara.formatRange.length - intersetRange.length - releasePreNewLine;
                    if (finalLength > 0) {
                        curPara.formatRange = NSMakeRange(affectedRange.location+releasePreNewLine, finalLength);
                    }else{
                        [paraToDele addObject:curPara];
                    }
                }
                if (curPara.formatRange.length <= 0) {
                    [paraToDele addObject:curPara];
                }
            }
        }else if (curPara.formatRange.location > affectedRange.location){
            curPara.formatRange = NSMakeRange(curPara.formatRange.location - affectedRange.length, curPara.formatRange.length);
        }
    }
    for (P2MSParagraph *curP in paraToDele) {
        [curParagraphs removeObject:curP];
    }
    
    //extend to new line
    CGFloat textLength = _text.length;
    for (P2MSParagraph *curPara in curParagraphs) {
        CGFloat lastPos = curPara.formatRange.location + curPara.formatRange.length;
        if (lastPos < textLength && [_text characterAtIndex:lastPos-1] != '\n') {
            NSRange newLineRange = [_text rangeOfString:@"\n" options:NSLiteralSearch range:NSMakeRange(lastPos-1, textLength-lastPos-1)];
            if (newLineRange.location != NSNotFound) {
                curPara.formatRange = NSMakeRange(curPara.formatRange.location, newLineRange.location+newLineRange.length - curPara.formatRange.location - text.length);
            }else{
                curPara.formatRange = NSMakeRange(curPara.formatRange.location, textLength-curPara.formatRange.location - text.length);
            }
        }
    }
    
    //readjust it to remove overlap
    [paraToDele removeAllObjects];
    NSSortDescriptor *sort = [[NSSortDescriptor alloc]initWithKey:@"self" ascending:YES comparator:globalSortBlock];
    NSMutableArray *arr = [[curParagraphs sortedArrayUsingDescriptors:[NSArray arrayWithObject:sort]]mutableCopy];
    [curParagraphs removeAllObjects];
    int paraCountM1 = arr.count-1;
    for (int i = 0; i < paraCountM1; i++) {
        P2MSParagraph *curPara = [arr objectAtIndex:i];
        P2MSParagraph *nextPara = [arr objectAtIndex:i+1];
        NSRange intersectRange = NSIntersectionRange(curPara.formatRange, nextPara.formatRange);
        if (intersectRange.length > 0) {
            NSInteger newLoc = intersectRange.location + intersectRange.length;
            NSInteger newLength = nextPara.formatRange.location + nextPara.formatRange.length - newLoc;
            if (newLength > 0) {
                nextPara.formatRange = NSMakeRange(newLoc, newLength);
            }else{
                [paraToDele addObject:nextPara]; i++;
            }
        }
    }
    
    for (P2MSParagraph *curParaToDelete in paraToDele) {
        [arr removeObject:curParaToDelete];
    }
    [curParagraphs addObjectsFromArray:arr];
    
    //select current active paragraph
    if (curParaRange.location == NSNotFound) {
        NSInteger locToFind = affectedRange.location;
        if (textLength == selectedNSRange.location+selectedNSRange.length) {
            locToFind = textLength - text.length-1;
        }
        locToFind += (locToFind < 0);
        for (P2MSParagraph *curPara in curParagraphs) {
            if (NSLocationInRange(locToFind, curPara.formatRange)) {
                curParagraphFormat = curPara.paraFormat;
                curParaRange = curPara.formatRange;
                [curParagraphs removeObject:curPara];break;
            }
        }
    }
}

- (void)thinkaboutPrevParaGroup:(P2MSParagraph **)curParaT{
    P2MSParagraph *curPara = *curParaT;
    if (curParagraphFormat == TEXT_NUMBERING || curParagraphFormat == TEXT_BULLET || curParagraphFormat == TEXT_BLOCK_QUOTE) {
        //@"NEed to combine with next one"
        NSRange newLineRange = [_text rangeOfString:@"\n" options:NSBackwardsSearch range:curPara.formatRange];
        if (newLineRange.length > 0) {
            //save existing one
            NSInteger afterLength = curPara.formatRange.location+curPara.formatRange.length;
            NSInteger afterStartLenght =  newLineRange.location+newLineRange.length;
            afterLength -= afterStartLenght;
            if (afterLength > 0) {
                P2MSParagraph *curPara1 = [[P2MSParagraph alloc]init];
                curPara1.paraFormat = curPara.paraFormat;
                curPara1.formatRange = NSMakeRange(curPara.formatRange.location, curPara.formatRange.length-afterLength);
                [curParagraphs addObject:curPara1];
                curPara.formatRange = NSMakeRange(afterStartLenght, afterLength);
            }
        }
    }
}

- (void)thinkaboutNextParaGroup:(P2MSParagraph **)curParaT{
    P2MSParagraph *curPara = *curParaT;
    if (curParagraphFormat == TEXT_NUMBERING || curParagraphFormat == TEXT_BULLET || curParagraphFormat == TEXT_BLOCK_QUOTE) {
        //@"NEed to combine with next one"
        NSRange newLineRange = [_text rangeOfString:@"\n" options:NSLiteralSearch range:curPara.formatRange];
        if (newLineRange.length > 0) {
            //save existing one
            NSInteger afterLength = curPara.formatRange.location+curPara.formatRange.length;
            NSInteger afterStartLenght =  newLineRange.location+newLineRange.length;
            afterLength -= afterStartLenght;
            if (afterLength > 0) {
                P2MSParagraph *curPara1 = [[P2MSParagraph alloc]init];
                curPara1.paraFormat = curPara.paraFormat;
                curPara1.formatRange = NSMakeRange(afterStartLenght, afterLength);
                [curParagraphs addObject:curPara1];
                curPara.formatRange = NSMakeRange(curPara.formatRange.location, curPara.formatRange.length-afterLength);
            }
        }
    }
}

/**
 UIKeyInput protocol required method.
 An input tokenizer that provide information about the granularity of text units
 */
- (id <UITextInputTokenizer>)tokenizer {
    return tokenizer;
}

- (void)setFrame:(CGRect)frame{
    if (!CGRectEqualToRect(self.frame, frame)) {
        [super setFrame:frame];
        [_textView setFrame:CGRectMake(8, 8, frame.size.width-16, frame.size.height-16)];
        [_textView refreshView];
        [self adjustScrollView];
    }
}

- (void)adjustScrollView{
    self.contentSize = CGSizeMake(self.frame.size.width, self.textView.frame.size.height+10);
    CGRect finalRect = [self convertRect:_textView.caretView.frame toView:_textView];
    finalRect.origin = CGPointMake(finalRect.origin.x+8, finalRect.origin.y+8);
    [self scrollRectToVisible:finalRect animated:YES];
}

#pragma mark KB
- (UIView *)inputView{
    if (!_editable) {
        return [[UIView alloc]initWithFrame:CGRectZero];
    }
    if (_showKeyboard) {
        return [super inputView];
    }
    CGSize kbSize;
    UIInterfaceOrientation orientation = [[UIApplication sharedApplication]statusBarOrientation];
    BOOL isPortrait = UIInterfaceOrientationIsPortrait(orientation);
    BOOL isIPAD = [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad;
    kbSize = (isPortrait)?CGSizeMake([[UIScreen mainScreen]bounds].size.width, (isIPAD)?264:216):CGSizeMake([[UIScreen mainScreen]bounds].size.height, (isIPAD)?352:162);
    
    if (!styleBaseView){
        styleBaseView = [[UIView alloc]initWithFrame:CGRectMake(0, 0, kbSize.width, kbSize.height)];
        styleBaseView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
        styleBaseView.backgroundColor = [UIColor colorWithRed:0.9137 green:0.9137 blue:0.9137 alpha:1.0];
        styleBaseView.layer.shadowColor = [UIColor lightGrayColor].CGColor;
        styleBaseView.layer.shadowOpacity = 0.7;
        styleBaseView.layer.shadowOffset = CGSizeMake(0, -1);
        styleBaseView.layer.shadowRadius = 1;
        [self populateCustomInputView];
    }
    return styleBaseView;
}

- (void)orientationChanged:(NSNotification *)notification{
    if (_editable && styleBaseView) {
        for (UIView *view in styleBaseView.subviews) {
            [view removeFromSuperview];
        }
        [self performSelector:@selector(populateCustomInputView) withObject:nil afterDelay:0.01f];
    }
}

- (void)populateCustomInputView{
    CGSize kbSize;
    UIInterfaceOrientation orientation = [[UIApplication sharedApplication]statusBarOrientation];
    BOOL isPortrait = UIInterfaceOrientationIsPortrait(orientation);
    BOOL isIPAD = [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad;
    CGSize btnSize, gutterSize;
    CGRect fitRect;
    if (isIPAD) {
        if (isPortrait) {
            kbSize = CGSizeMake([[UIScreen mainScreen]bounds].size.width, 264);
            gutterSize = CGSizeMake(7, 10);
            fitRect = CGRectMake(25, 10, kbSize.width-50, kbSize.height-20);
            btnSize = CGSizeMake(83, 48);
        }else{
            kbSize = CGSizeMake([[UIScreen mainScreen]bounds].size.height, 352);
            gutterSize = CGSizeMake(15, 10);
            fitRect = CGRectMake(100, 10, kbSize.width-200, kbSize.height-20);
            btnSize = CGSizeMake(88, 50);
        }
    }else{
        if (isPortrait) {
            kbSize = CGSizeMake([[UIScreen mainScreen]bounds].size.width, 216);
        }else
            kbSize = CGSizeMake([[UIScreen mainScreen]bounds].size.height, 162);
        btnSize = CGSizeMake(59, 35);
        gutterSize = CGSizeMake(3, 5);
        fitRect = CGRectMake(5, 10, kbSize.width-10, kbSize.height-20);
    }
    CGRect curRect = CGRectMake(fitRect.origin.x, fitRect.origin.y, btnSize.width, btnSize.height);
    [self createButtonForRect:curRect withImage:@"bold-icon" andAction:@selector(boldAction:)];
    
    curRect = [self nextRectFromCurrentRect:curRect withGutterSize:gutterSize fitToRect:fitRect];
    [self createButtonForRect:curRect withImage:@"italic-icon" andAction:@selector(italicAction:)];
    
    curRect = [self nextRectFromCurrentRect:curRect withGutterSize:gutterSize fitToRect:fitRect];
    [self createButtonForRect:curRect withImage:@"underline-icon" andAction:@selector(underlineAction:)];
    
    curRect = [self nextRectFromCurrentRect:curRect withGutterSize:gutterSize fitToRect:fitRect];
    [self createButtonForRect:curRect withImage:@"strike-icon" andAction:@selector(strikethroughAction:)];
    
    curRect = [self nextRectFromCurrentRect:curRect withGutterSize:gutterSize fitToRect:fitRect];
    [self createButtonForRect:curRect withImage:@"highlight-icon" andAction:@selector(highlightAction:)];
    
    curRect = [self nextRectFromCurrentRect:curRect withGutterSize:gutterSize fitToRect:fitRect];
    [self createButtonForRect:curRect withImage:@"bullet" andAction:@selector(bulletAction:)];
    
    curRect = [self nextRectFromCurrentRect:curRect withGutterSize:gutterSize fitToRect:fitRect];
    [self createButtonForRect:curRect withImage:@"numbering" andAction:@selector(numberingAction:)];
    
    curRect = [self nextRectFromCurrentRect:curRect withGutterSize:gutterSize fitToRect:fitRect];
    [self createButtonForRect:curRect withImage:@"link" andAction:@selector(linkAction:)];
    
    UIView *paneView = [[UIView alloc]initWithFrame:CGRectMake(10, curRect.origin.y+curRect.size.height+(gutterSize.height*2), 300, 100)];
    paneView.layer.borderColor = [UIColor colorWithWhite:0.7 alpha:1.0].CGColor;
    paneView.layer.borderWidth = 1.0;
    paneView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleBottomMargin;
    paneView.layer.cornerRadius = 5;
    paneView.tag = 19;
    paneView.clipsToBounds = YES;
    [styleBaseView addSubview:paneView];
    paneView.center = CGPointMake(kbSize.width/2, paneView.center.y);
    
    curRect = CGRectMake(0, 0, 151, 51);
    UIButton *sectionBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    sectionBtn.frame = curRect;
    [sectionBtn setBackgroundImage:[[UIImage imageNamed:@"rectangle-background"]stretchableImageWithLeftCapWidth:11.5 topCapHeight:15.5] forState:UIControlStateNormal];
    [sectionBtn setImage:[UIImage imageNamed:@"section-icon"] forState:UIControlStateNormal];
    [sectionBtn addTarget:self action:@selector(sectionAction:) forControlEvents:UIControlEventTouchUpInside];
    [paneView addSubview:sectionBtn];
    
    curRect.origin.x += curRect.size.width-1;
    UIButton *subSection = [UIButton buttonWithType:UIButtonTypeCustom];
    subSection.frame = curRect;
    [subSection setBackgroundImage:[[UIImage imageNamed:@"rectangle-background"]stretchableImageWithLeftCapWidth:11.5 topCapHeight:15.5] forState:UIControlStateNormal];
    [subSection setImage:[UIImage imageNamed:@"subsection-icon"] forState:UIControlStateNormal];
    [subSection addTarget:self action:@selector(subSectionAction:) forControlEvents:UIControlEventTouchUpInside];
    [paneView addSubview:subSection];
    
    curRect.origin.x = 0;
    curRect.origin.y += curRect.size.height-1;
    UIButton *paragraph = [UIButton buttonWithType:UIButtonTypeCustom];
    paragraph.frame = curRect;
    [paragraph setBackgroundImage:[[UIImage imageNamed:@"rectangle-background"]stretchableImageWithLeftCapWidth:11.5 topCapHeight:15.5] forState:UIControlStateNormal];
    [paragraph setImage:[UIImage imageNamed:@"paragraph-icon"] forState:UIControlStateNormal];
    [paragraph addTarget:self action:@selector(paragraphAction:) forControlEvents:UIControlEventTouchUpInside];
    [paneView addSubview:paragraph];
    
    curRect.origin.x += curRect.size.width-1;
    UIButton *blockquote = [UIButton buttonWithType:UIButtonTypeCustom];
    blockquote.frame = curRect;
    [blockquote setBackgroundImage:[[UIImage imageNamed:@"rectangle-background"]stretchableImageWithLeftCapWidth:11.5 topCapHeight:15.5] forState:UIControlStateNormal];
    [blockquote setImage:[UIImage imageNamed:@"blockquote-icon"] forState:UIControlStateNormal];
    [blockquote addTarget:self action:@selector(blockquoteAction:) forControlEvents:UIControlEventTouchUpInside];
    [paneView addSubview:blockquote];
    
    [self reflectIconForActionChange];
}

- (CGRect)nextRectFromCurrentRect:(CGRect)curRect withGutterSize:(CGSize)gutterSize fitToRect:(CGRect)fitRect {
    int NewX = curRect.origin.x+curRect.size.width+gutterSize.width;
    if (NewX+curRect.size.width <= fitRect.origin.x+fitRect.size.width) {
        return CGRectMake(curRect.origin.x+curRect.size.width+gutterSize.width, curRect.origin.y, curRect.size.width, curRect.size.height);
    }else{
        return CGRectMake(fitRect.origin.x, curRect.origin.y+curRect.size.height+gutterSize.height, curRect.size.width, curRect.size.height);
    }
}

- (UIButton *)createButtonForRect:(CGRect)curRect withImage:(NSString *)imageName andAction:(SEL)action{
    UIButton *underline = [UIButton buttonWithType:UIButtonTypeCustom];
    underline.frame = curRect;
    [underline setBackgroundImage:[[UIImage imageNamed:@"round-corner-button"]stretchableImageWithLeftCapWidth:12 topCapHeight:15] forState:UIControlStateNormal];
    [underline setImage:[UIImage imageNamed:imageName] forState:UIControlStateNormal];
    [underline addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [styleBaseView addSubview:underline];
    return underline;
}

- (UIView *)inputAccessoryView{
    return (_editable)?_inputAccessoryView:nil;
}

- (void)setInputAccessoryView:(UIView *)inputAccessoryView{
    _inputAccessoryView = inputAccessoryView;
}


NSComparisonResult (^globalSortBlock)(id,id) = ^(id lhs, id rhs) {
    NSUInteger firstLoc = ((P2MSFormat *)lhs).formatRange.location;
    NSUInteger secondLoc = ((P2MSFormat *)rhs).formatRange.location;
    if(firstLoc < secondLoc) {
        return (NSComparisonResult)NSOrderedAscending;
    } else if(firstLoc > secondLoc) {
        return (NSComparisonResult)NSOrderedDescending;
    }
    return (NSComparisonResult)NSOrderedSame;
};

- (void)saveCurrentAttributes{
    if (curActionRange.length <= 0)return;
    P2MSTextFormat *txtFormat = [[P2MSTextFormat alloc]init];
    txtFormat.txtFormat = curTextFormat;
    txtFormat.formatRange = curActionRange;
    [curAttributes addObject:txtFormat];
    [curAttributes sortWithOptions:NSBinarySearchingFirstEqual usingComparator:globalSortBlock];
}

- (void)applyFormat:(TEXT_FORMAT)txtFormat toRange:(NSRange)selectedRange{
    [self saveCurrentAttributes];
    BOOL willApply = NO;
    NSUInteger finalSelPos = selectedRange.location + selectedRange.length;
    if (finalSelPos < _text.length && [_text characterAtIndex:finalSelPos] == '\n') {
        selectedRange = NSMakeRange(selectedRange.location, selectedRange.length+1);
    }
    NSMutableArray *affectedRange = [NSMutableArray array];
    NSMutableArray *newAttributes = [NSMutableArray array];
    for (P2MSTextFormat *curFmt in curAttributes) {
        NSRange curFmtRange = curFmt.formatRange;
        TEXT_FORMAT curFormat = curFmt.txtFormat;
        NSRange intersetRange = NSIntersectionRange(curFmtRange, selectedRange);
        if (intersetRange.length > 0) {
            if (!willApply) {
                willApply = !(curFormat & txtFormat);
            }
            if (intersetRange.length != curFmt.formatRange.length) {
                if (curFmtRange.location < intersetRange.location) {
                    P2MSTextFormat *firstFmt = [[P2MSTextFormat alloc]init];
                    firstFmt.txtFormat = curFormat;
                    firstFmt.formatRange = NSMakeRange(curFmtRange.location, intersetRange.location-curFmtRange.location);
                    [newAttributes addObject:firstFmt];
                    if (intersetRange.location+intersetRange.length < curFmtRange.location+curFmtRange.length) {
                        P2MSTextFormat *lastFmt = [[P2MSTextFormat alloc]init];
                        lastFmt.txtFormat = curFormat;
                        lastFmt.formatRange = NSMakeRange(intersetRange.location+intersetRange.length, (curFmtRange.location+curFmtRange.length)-(intersetRange.location+intersetRange.length));
                        [newAttributes addObject:lastFmt];
                    }
                }else{
                    P2MSTextFormat *lastFmt = [[P2MSTextFormat alloc]init];
                    lastFmt.txtFormat = curFormat;
                    lastFmt.formatRange = NSMakeRange(intersetRange.location+intersetRange.length, (curFmtRange.location+curFmtRange.length)-(intersetRange.location+intersetRange.length));
                    [newAttributes addObject:lastFmt];
                }
                P2MSTextFormat *middleFmt = [[P2MSTextFormat alloc]init];
                middleFmt.formatRange = intersetRange;
                middleFmt.txtFormat = curFormat;
                [affectedRange addObject:middleFmt];
            }else{
                [affectedRange addObject:curFmt];
            }
        }else{
            [newAttributes addObject:curFmt];
        }
    }
    
    for (P2MSTextFormat *modifiedFmt in affectedRange) {
        if (willApply) {
            modifiedFmt.txtFormat |= txtFormat;
        }else{
            modifiedFmt.txtFormat &= (127 ^ txtFormat);
        }
        modifiedFmt.txtFormat += (modifiedFmt.txtFormat == TEXT_FORMAT_NOT_SET);
        [newAttributes addObject:modifiedFmt];
    }
    [newAttributes sortWithOptions:NSBinarySearchingFirstEqual usingComparator:globalSortBlock];
    
    [curAttributes removeAllObjects];
    
    //combine same
    P2MSTextFormat *tempFormat = nil;
    for (P2MSTextFormat *curFmt in newAttributes) {
        if (tempFormat && tempFormat.formatRange.length > 0) {
            NSUInteger lastChar = tempFormat.formatRange.location + tempFormat.formatRange.length - 1;
            if (tempFormat.txtFormat == curFmt.txtFormat && [_text characterAtIndex:lastChar] != '\n') {
                tempFormat.formatRange = NSMakeRange(tempFormat.formatRange.location, tempFormat.formatRange.length+curFmt.formatRange.length);
            }else{
                [curAttributes addObject:tempFormat];
                tempFormat = curFmt;
            }
        }else
            tempFormat = curFmt;
    }
    if (tempFormat) {
        [curAttributes addObject:tempFormat];
    }
    
    //need to check for current Action and format
    [self forceReflectFormatForLocationChange:selectedRange.location];
    
    curSetTextFormat = TEXT_FORMAT_NOT_SET;
    [_textView refreshView];
}

- (void)setAction:(TEXT_FORMAT)txtFormat{
    NSRange selectedRange = _textView.selectedTextRange;
    if (selectedRange.length) {
        [self applyFormat:txtFormat toRange:selectedRange];
    }else{
        curSetTextFormat = (curSetTextFormat!=TEXT_FORMAT_NOT_SET)?curSetTextFormat^txtFormat:curTextFormat^txtFormat;
        curSetTextFormat += curSetTextFormat == TEXT_FORMAT_NOT_SET;
        curSetActionRange = selectedRange;
    }
    [self reflectIconForActionChange];
}

- (void)setAction:(TEXT_FORMAT)txtFormat withButton:(UIButton *)sender{
    NSInteger isActionOn = ((UIView *)sender).tag;
    isActionOn = !isActionOn;
    ((UIView *)sender).tag = isActionOn;
    [self setAction:txtFormat];
}

- (IBAction)boldAction:(id)sender{
    [self setAction:TEXT_BOLD withButton:sender];
}

- (IBAction)italicAction:(id)sender{
    [self setAction:TEXT_ITALIC withButton:sender];
}

- (IBAction)underlineAction:(id)sender{
    [self setAction:TEXT_UNDERLINE withButton:sender];
}

- (IBAction)strikethroughAction:(id)sender{
    [self setAction:TEXT_STRIKE_THROUGH withButton:sender];
}

- (IBAction)highlightAction:(id)sender{
    [self setAction:TEXT_HIGHLIGHT withButton:sender];
}

- (IBAction)linkAction:(id)sender{
    P2MSLinkViewController *linkVC = [[P2MSLinkViewController alloc]initWithStyle:UITableViewStyleGrouped];
    if (self.textViewDelegate) {
        linkVC.delegate = self;
        linkVC.linkRange = NSMakeRange(NSNotFound, 0);
        NSUInteger locToSearch = _textView.selectedTextRange.location;
        locToSearch -= (locToSearch > 0);
        NSRange rangeToSearch = NSMakeRange(locToSearch, (_textView.selectedTextRange.length > 0)?_textView.selectedTextRange.length:1);
        for (P2MSLink *link in links) {
            if (NSIntersectionRange(rangeToSearch, link.formatRange).length > 0) {
                linkVC.linkURL = link.linkURL;
                linkVC.linkRange = link.formatRange;
            }
        }
        if (linkVC.linkRange.location == NSNotFound && _textView.selectedTextRange.length) {
            linkVC.linkRange = _textView.selectedTextRange;
        }
        [((UIViewController *)self.textViewDelegate) presentModalViewController:linkVC animated:YES];
    }
}

- (void)applyParaFormat:(PARAGRAPH_FORMAT)paraFormat toRange:(NSRange)rawSelectedRange{
    if (rawSelectedRange.location == NSNotFound) {
        return;
    }
    NSUInteger finalSelPos = rawSelectedRange.location + rawSelectedRange.length;
    if (finalSelPos < _text.length && [_text characterAtIndex:finalSelPos] == '\n') {
        rawSelectedRange = NSMakeRange(rawSelectedRange.location, rawSelectedRange.length+1);
    }
    NSRange selectedRange = rawSelectedRange;
    
    if (selectedRange.length == 0) {
        if (rawSelectedRange.location > 0){
            if([self.text characterAtIndex:rawSelectedRange.location-1] == '\n') {
                if (rawSelectedRange.location < self.text.length) {
                    selectedRange = NSMakeRange(rawSelectedRange.location, 1);
                }
            }else{
                selectedRange = NSMakeRange(rawSelectedRange.location-1, 1);
            }
        }else if (self.text.length > 0){
            selectedRange = NSMakeRange(rawSelectedRange.location, 1);
        }
    }
    
    NSUInteger textLength = _text.length;
    NSUInteger locStart = selectedRange.location, locEnd = selectedRange.location + selectedRange.length;
    if (locStart > 0 && [_text characterAtIndex:locStart-1] != '\n') {
        NSRange prevRange = [self.text rangeOfString:@"\n" options:NSBackwardsSearch range:NSMakeRange(0, locStart)];
        if (prevRange.length > 0) {
            locStart = prevRange.location + prevRange.length;
        }else
            locStart = 0;
    }
    
    if (locEnd > 0 && locEnd < _text.length && [_text characterAtIndex:locEnd-1] != '\n') {
        NSRange nextRange = [self.text rangeOfString:@"\n" options:NSLiteralSearch range:NSMakeRange(locEnd, textLength - locEnd)];
        if (nextRange.length > 0) {
            locEnd = nextRange.location + nextRange.length;
        }
    }
    
    //new range to apply
    NSInteger newSelectedLength = locEnd - locStart;
    NSRange newRangeToApply = NSMakeRange(locStart, newSelectedLength);
    NSMutableSet *paraToRemove = [NSMutableSet set];
    
    if (curParaRange.length > 0 && curParagraphFormat != TEXT_PARAGRAPH) {
        P2MSParagraph *paraToSave = [[P2MSParagraph alloc]init];
        paraToSave.paraFormat = curParagraphFormat;
        paraToSave.formatRange = curParaRange;
        [curParagraphs addObject:paraToSave];
    }
    
    curParaRange = NSMakeRange(NSNotFound, 0);
    curParagraphFormat = paraFormat;
    NSMutableArray *newParagraphs = [NSMutableArray array];
    for (P2MSParagraph *curPara in curParagraphs) {
        if (curPara.paraFormat == TEXT_PARAGRAPH || curPara.formatRange.length == 0) {
            [paraToRemove addObject:curPara];continue;
        }
        NSRange intersectRange = NSIntersectionRange(curPara.formatRange, newRangeToApply);
        if (intersectRange.length > 0) {
            [paraToRemove addObject:curPara];
            NSInteger paraFinalPos = curPara.formatRange.location + curPara.formatRange.length;
            
            NSRange beforeRange = [_text rangeOfString:@"\n" options:NSBackwardsSearch range:NSMakeRange(curPara.formatRange.location, intersectRange.location - curPara.formatRange.location)];
            if (beforeRange.location != NSNotFound) {
                P2MSParagraph *paraToAdd = [[P2MSParagraph alloc]init];
                paraToAdd.paraFormat = curPara.paraFormat;
                NSUInteger newLength =  beforeRange.location - curPara.formatRange.location + 1;
                paraToAdd.formatRange = NSMakeRange(curPara.formatRange.location, newLength);
                [newParagraphs addObject:paraToAdd];
            }else if (curPara.formatRange.location < intersectRange.location){
                P2MSParagraph *paraToAdd = [[P2MSParagraph alloc]init];
                paraToAdd.paraFormat = curPara.paraFormat;
                paraToAdd.formatRange = NSMakeRange(curPara.formatRange.location, intersectRange.location-curPara.formatRange.location);
                [newParagraphs addObject:paraToAdd];
            }
            
            
            NSInteger newLocToSearch = intersectRange.location + intersectRange.length;
            NSInteger newLengthFromSearch = paraFinalPos - newLocToSearch;
            if (newLengthFromSearch < 0) {
                newLengthFromSearch = 0;
            }
            
            if (newLocToSearch > 0 && [_text characterAtIndex:newLocToSearch-1] == '\n') {
                P2MSParagraph *paraToAdd = [[P2MSParagraph alloc]init];
                paraToAdd.paraFormat = curPara.paraFormat;
                paraToAdd.formatRange = NSMakeRange(newLocToSearch, newLengthFromSearch);
                [newParagraphs addObject:paraToAdd];
            }else{
                NSRange afterRange = [_text rangeOfString:@"\n" options:NSLiteralSearch range:NSMakeRange(newLocToSearch, newLengthFromSearch)];
                if (afterRange.location != NSNotFound) {
                    NSInteger afterLength = paraFinalPos;
                    NSInteger afterStartLenght = afterRange.location+afterRange.length;
                    afterLength -= afterStartLenght;
                    if (afterLength > 0) {
                        P2MSParagraph *paraToAdd = [[P2MSParagraph alloc]init];
                        paraToAdd.paraFormat = curPara.paraFormat;
                        paraToAdd.formatRange = NSMakeRange(afterStartLenght, afterLength);
                        [newParagraphs addObject:paraToAdd];
                    }
                }else if (newLocToSearch < curPara.formatRange.location+curPara.formatRange.length){
                    P2MSParagraph *paraToAdd = [[P2MSParagraph alloc]init];
                    paraToAdd.paraFormat = curPara.paraFormat;
                    paraToAdd.formatRange = NSMakeRange(newLocToSearch, paraFinalPos-newLocToSearch);
                    [newParagraphs addObject:paraToAdd];
                }
            }
        }
    }
    for (P2MSParagraph *paraDel in paraToRemove) {
        [curParagraphs removeObject:paraDel];
    }
    [curParagraphs addObjectsFromArray:newParagraphs];
    if (newSelectedLength > 0) {
        P2MSParagraph *paraToSave = [[P2MSParagraph alloc]init];
        paraToSave.paraFormat = paraFormat;
        paraToSave.formatRange = newRangeToApply;
        [curParagraphs addObject:paraToSave];
    }
    
    [newParagraphs removeAllObjects];
    newParagraphs = nil;
    
    [self rearrangeParagraphsWithSelectedRange:selectedRange];
}

- (void)rearrangeParagraphsWithSelectedRange:(NSRange)selectedRange{
    //remove unnecessory one
    NSMutableSet *paraToRemove = [NSMutableSet set];
    for (P2MSParagraph *curPara in curParagraphs) {
        if (curPara.paraFormat == TEXT_PARAGRAPH || curPara.formatRange.length == 0) {
            [paraToRemove addObject:curPara];
        }
    }
    for (P2MSParagraph *delPara in paraToRemove) {
        [curParagraphs removeObject:delPara];
    }
    
    NSSortDescriptor *sort = [[NSSortDescriptor alloc]initWithKey:@"self" ascending:YES comparator:globalSortBlock];
    NSArray *arr = [curParagraphs sortedArrayUsingDescriptors:[NSArray arrayWithObject:sort]];
    [curParagraphs removeAllObjects];
    
    P2MSParagraph *tempParagraph = nil;
    for (P2MSParagraph *curPara in arr) {
        if (tempParagraph) {
            NSRange intersetRange = NSIntersectionRange(tempParagraph.formatRange, curPara.formatRange);
            if (intersetRange.length > 0 || tempParagraph.formatRange.location+tempParagraph.formatRange.length == curPara.formatRange.location) {
                if (tempParagraph.paraFormat == curPara.paraFormat && (tempParagraph.paraFormat != TEXT_SECTION && tempParagraph.paraFormat != TEXT_SUBSECTION)) {
                    tempParagraph.formatRange = NSMakeRange(tempParagraph.formatRange.location, tempParagraph.formatRange.length+curPara.formatRange.length-intersetRange.length);
                }else if(NSLocationInRange(selectedRange.location, tempParagraph.formatRange)){
                    curParaRange = tempParagraph.formatRange;
                    tempParagraph = curPara;
                }
                else{
                    [curParagraphs addObject:tempParagraph];
                    tempParagraph = curPara;
                }
            }
            else{
                [curParagraphs addObject:tempParagraph];
                tempParagraph = curPara;
            }
        }else{
            tempParagraph = curPara;
        }
        
    }
    if (tempParagraph) {
        [curParagraphs addObject:tempParagraph];
    }
}

- (IBAction)sectionAction:(id)sender{
    if (curActionRange.length == 0) {
        curTextFormat = TEXT_BOLD;
        curActionRange = NSMakeRange(_textView.selectedTextRange.location, 0);
    }
    [self applyParaFormat:TEXT_SECTION toRange:self.textView.selectedTextRange];
    if (curParaRange.location == NSNotFound) {
        curParaRange = _textView.selectedTextRange;
    }
    [self.textView refreshView];
    self.contentSize = CGSizeMake(self.frame.size.width, self.textView.frame.size.height+20);
    [self reflectIconForActionChange];
}

- (IBAction)subSectionAction:(id)sender{
    if (curActionRange.length == 0) {
        curTextFormat = TEXT_BOLD;
        curActionRange = NSMakeRange(_textView.selectedTextRange.location, 0);
    }
    [self applyParaFormat:TEXT_SUBSECTION toRange:self.textView.selectedTextRange];
    if (curParaRange.location == NSNotFound) {
        curParaRange = _textView.selectedTextRange;
    }
    [self.textView refreshView];
    self.contentSize = CGSizeMake(self.frame.size.width, self.textView.frame.size.height+20);
    [self reflectIconForActionChange];
}

- (IBAction)paragraphAction:(id)sender{
    [self applyParaFormat:TEXT_PARAGRAPH toRange:self.textView.selectedTextRange];
    [self.textView refreshView];
    self.contentSize = CGSizeMake(self.frame.size.width, self.textView.frame.size.height+20);
    [self reflectIconForActionChange];
}

- (IBAction)blockquoteAction:(id)sender{
    if (curActionRange.length == 0) {
        curTextFormat = TEXT_ITALIC;
        curActionRange = NSMakeRange(_textView.selectedTextRange.location, 0);
    }
    [self applyParaFormat:TEXT_BLOCK_QUOTE toRange:self.textView.selectedTextRange];
    if (curParaRange.location == NSNotFound) {
        curParaRange = _textView.selectedTextRange;
    }
    [self.textView refreshView];
    self.contentSize = CGSizeMake(self.frame.size.width, self.textView.frame.size.height+20);
    [self reflectIconForActionChange];
}

//just think about at of the line case first
- (IBAction)bulletAction:(id)sender{
    PARAGRAPH_FORMAT newStyle = (curParagraphFormat == TEXT_BULLET)?TEXT_PARAGRAPH:TEXT_BULLET;
    [self applyParaFormat:newStyle toRange:self.textView.selectedTextRange];
    
    if (curParaRange.location == NSNotFound) {
        curParaRange = _textView.selectedTextRange;
    }
    [self.textView refreshView];
    self.contentSize = CGSizeMake(self.frame.size.width, self.textView.frame.size.height+20);
    [self reflectIconForActionChange];
}

- (IBAction)numberingAction:(id)sender{
    PARAGRAPH_FORMAT newStyle = (curParagraphFormat == TEXT_NUMBERING)?TEXT_PARAGRAPH:TEXT_NUMBERING;
    [self applyParaFormat:newStyle toRange:self.textView.selectedTextRange];
    if (curParaRange.location == NSNotFound) {
        curParaRange = _textView.selectedTextRange;
    }
    [self.textView refreshView];
    self.contentSize = CGSizeMake(self.frame.size.width, self.textView.frame.size.height+20);
    [self reflectIconForActionChange];
}

- (void)toggleNormalKeyboard{
    [self toggleKeyboard:YES];
}

- (void)toggleFormattingKeyboard{
    [self toggleKeyboard:NO];
}

- (void)toggleKeyboard:(BOOL)isNormalKeyboard{
    if (_textView.editing && isNormalKeyboard == _showKeyboard) {
        _showKeyboard = YES;    //default to normal keyboard
        [self resignFirstResponder];
    }else{
        _showKeyboard = isNormalKeyboard;
        [self resignFirstResponder];
        self.textView.editing = YES;
        [self becomeFirstResponder];
    }    
}

#pragma mark UIGestureREcognizer
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer{
    P2MSSelectionView *selectionView = [_textView selectionView];
    if (gestureRecognizer == _longPressGR) {
        if (_textView.selectedTextRange.length>0 && selectionView!=nil) {
            return CGRectContainsPoint(CGRectInset([_textView convertRect:selectionView.frame toView:self], -20.0f, -20.0f) , [gestureRecognizer locationInView:self]);
        }
    }
    return YES;
}

#pragma mark UIMenuController
- (void)showMenu {
    UIMenuController *menuController = [UIMenuController sharedMenuController];
    if ([menuController isMenuVisible]) {
        [menuController setMenuVisible:NO animated:NO];
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [menuController setMenuItems:nil];
        CGRect rect = [self menuPresentationRect];
        rect.origin.x += 8;
        rect.origin.y += 8;
        [menuController setTargetRect:rect inView:self];
        [menuController update];
        [menuController setMenuVisible:YES animated:YES];
    });
}

- (void)showCorrectionMenu {
    if (_textView.isEditing) {
        NSRange outRange = [_textView characterRangeAtIndex:_textView.selectedTextRange.location];
        if (outRange.location!=NSNotFound && outRange.length>1) {
            NSRange range = [textChecker rangeOfMisspelledWordInString:self.text range:outRange startingAt:0 wrap:YES language:language];
            if (NSEqualRanges(range, _textView.correctionRange) && range.location == NSNotFound && range.length == 0) {
                //no correction found
                [self setCorrectionRange:range];
                return;
            }
            [self setCorrectionRange:range];
        }
    }
}

- (void)setCorrectionRange:(NSRange)range{
    if (NSEqualRanges(range, _textView.correctionRange) && range.location == NSNotFound && range.length == 0) {
        _textView.correctionRange = range;
        return;
    }
    _textView.correctionRange = range;
    if (range.location != NSNotFound && range.length > 0) {
        if (!_textView.caretView.hidden) {
            _textView.caretView.hidden = YES;
        }
        [self showCorrectionForRange:range];
    } else {
        if (_textView.caretView.hidden) {
            _textView.caretView.hidden = NO;
            [_textView.caretView delayBlink];
        }
    }
    [_textView setNeedsDisplay];
}

- (void)showRelevantMenu {
    if (_textView.isEditing) {
        NSRange outRange = [_textView characterRangeAtIndex:_textView.selectedTextRange.location];
        if (outRange.location!=NSNotFound && outRange.length>1) {
            NSRange range = [textChecker rangeOfMisspelledWordInString:self.text range:outRange startingAt:0 wrap:YES language:language];
            if (NSEqualRanges(range, _textView.correctionRange) && range.location == NSNotFound && range.length == 0) {
                //no correction found and show normal menu
                [self setCorrectionRange:range];
                [self showMenu];
                return;
            }
            [self setCorrectionRange:range];
        }else{
            [self showMenu];
        }
    }
}


- (void)setEditable:(BOOL)editable{
    if (editable) {
        if (_textView.caretView==nil) {
            _textView.caretView = [[P2MSCaretView alloc] initWithFrame:CGRectZero];
        }
        _textView.caretView.hidden = NO;
        tokenizer = [[UITextInputStringTokenizer alloc] initWithTextInput:self];
        textChecker = [[UITextChecker alloc] init];
    } else {
        _textView.caretView.hidden = YES;
        textChecker = nil;
        tokenizer = nil;
    }
    _editable = editable;
}

- (void)showCorrectionForRange:(NSRange)range {
    range.location = MAX(0, range.location);
    range.length = MIN(_text.length, range.length);
    UIMenuController *menuController = [UIMenuController sharedMenuController];
    if ([menuController isMenuVisible]) {
        [menuController setMenuVisible:NO animated:NO];
    }
    _showingCorrectionMenu = YES;
    
    NSArray *guesses = [textChecker guessesForWordRange:range inString:_text language:language];
    NSMutableArray *items = nil;
    if (guesses && [guesses count]>0) {
        items = [[NSMutableArray alloc] init];
        if (menuItemActions==nil) {
            menuItemActions = [NSMutableDictionary dictionary];
        }
        for (NSString *word in guesses){
            NSString *selString = [NSString stringWithFormat:@"spellCheckMenu_%i:", [word hash]];
            SEL sel = sel_registerName([selString UTF8String]);
            [menuItemActions setObject:word forKey:NSStringFromSelector(sel)];
            class_addMethod([self class], sel, [[self class] instanceMethodForSelector:@selector(correctSpelling:)], "v@:@");
            UIMenuItem *item = [[UIMenuItem alloc] initWithTitle:word action:sel];
            [items addObject:item];
            if ([items count]>=4) {
                break;
            }
        }
    } else {
        UIMenuItem *item = [[UIMenuItem alloc] initWithTitle:@"No Replacements Found" action:@selector(spellCheckMenuEmpty:)];
        items = [NSMutableArray arrayWithObject:item];
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [menuController setMenuItems:items];
        CGRect rect = [self menuPresentationRect];
        rect.origin.x += 8;
        rect.origin.y += 8;
        [menuController setTargetRect:rect inView:self];
        [menuController update];
        [menuController setMenuVisible:YES animated:YES];
    });
}

- (void)correctSpelling:(UIMenuController*)sender {
    NSRange replacementRange = _textView.correctionRange;
    
    if (replacementRange.location==NSNotFound || replacementRange.length==0) {
        replacementRange = [_textView characterRangeAtIndex:_textView.selectedTextRange.location];
    }
    if (replacementRange.location!=NSNotFound && replacementRange.length!=0) {
        NSString *text = [menuItemActions objectForKey:NSStringFromSelector(_cmd)];
        [self.inputDelegate textWillChange:self];
        [self replaceRange:[P2MSIndexedRange indexedRangeWithRange:replacementRange] withText:text];
        [self.inputDelegate textDidChange:self];
        replacementRange.length = text.length;
    }
    [self setCorrectionRange:NSMakeRange(NSNotFound, 0)];
    menuItemActions = nil;
    [sender setMenuItems:nil];
}

- (void)spellCheckMenuEmpty:(id)sender {
    [UIMenuController sharedMenuController].menuVisible = YES;
}

- (CGRect)menuPresentationRect {
    CGRect rect = [self.textView convertRect:_textView.caretView.frame toView:self];
    if (_textView.selectedTextRange.location != NSNotFound && _textView.selectedTextRange.length > 0) {
        rect = (_textView.selectionView!=nil)?[self.textView convertRect:[_textView selectionView].frame toView:self]:[_textView firstRectForRange:_textView.selectedTextRange];
    }else if (_textView.editing && _textView.correctionRange.location != NSNotFound && _textView.correctionRange.length > 0) {
        rect = [_textView firstRectForRange:_textView.correctionRange];
    }
    return rect;
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    if (_textView.correctionRange.length>0 || _showingCorrectionMenu) {
        if ([NSStringFromSelector(action) hasPrefix:@"spellCheckMenu"]) {
            return YES;
        }
        return NO;
    }
    if (action==@selector(cut:)) {
        return (_textView.selectedTextRange.length>0 && _textView.isEditing);
    } else if (action==@selector(copy:)) {
        return ((_textView.selectedTextRange.length>0));
    } else if ((action == @selector(select:) || action == @selector(selectAll:))) {
        return (_textView.selectedTextRange.length==0 && [self hasText]);
    } else if (action == @selector(paste:)) {
        return (_textView.isEditing && [[UIPasteboard generalPasteboard] containsPasteboardTypes:[NSArray arrayWithObjects:@"public.text", @"public.utf8-plain-text", nil]]);
    } else if (action == @selector(delete:)) {
        return NO;
    }
    return [super canPerformAction:action withSender:sender];
}

- (NSMutableDictionary *)getAttributes{
    NSMutableArray *paraArr = [NSMutableArray arrayWithArray:[curParagraphs allObjects]];
    NSMutableDictionary *styles = [NSMutableDictionary dictionaryWithCapacity:2];
    if (curParaRange.location != NSNotFound) {
        P2MSParagraph *curPar = [[P2MSParagraph alloc]init];
        curPar.formatRange = curParaRange;//NSMakeRange(curParaRange.location, curParaRange.length);
        curPar.paraFormat = curParagraphFormat;
        [paraArr addObject:curPar];
    }
    NSMutableArray *arr = [NSMutableArray arrayWithArray:curAttributes];
    if (curActionRange.location != NSNotFound && curActionRange.length > 0) {
        P2MSTextFormat *tempFormat = [[P2MSTextFormat alloc]init];
        tempFormat.formatRange = curActionRange;
        tempFormat.txtFormat = curTextFormat;
        [arr addObject:tempFormat];
        [arr sortWithOptions:NSBinarySearchingFirstEqual usingComparator:globalSortBlock];
        NSUInteger prevLoc = 0;
        for (P2MSTextFormat *curFormat in arr) {
            curFormat.formatRange = NSMakeRange(prevLoc, curFormat.formatRange.length);
            prevLoc += curFormat.formatRange.length;
        }
        P2MSTextFormat *lastFormat = [arr lastObject];
        if (lastFormat) {
            lastFormat.formatRange = NSMakeRange(lastFormat.formatRange.location, _text.length-lastFormat.formatRange.location);
        }
    }
    [styles setObject:paraArr forKey:@"paragraphs"];
    [styles setObject:arr forKey:@"attributes"];
    [styles setObject:[NSMutableArray arrayWithArray:[links allObjects]] forKey:@"links"];
    return styles;
}

- (void)cut:(id)sender {
    NSRange selectedNSRange = _textView.selectedTextRange;
    if (selectedNSRange.length) {
        NSString *string = [_text substringWithRange:selectedNSRange];
        [[UIPasteboard generalPasteboard] setValue:string forPasteboardType:@"public.utf8-plain-text"];
        [self deleteBackward];
    }
}

- (void)copy:(id)sender {
    NSRange selectedNSRange = _textView.selectedTextRange;
    if (selectedNSRange.length > 0) {
        NSString *string = [_text substringWithRange:_textView.selectedTextRange];
        [[UIPasteboard generalPasteboard] setValue:string forPasteboardType:@"public.utf8-plain-text"];
    }
}

- (void)delete:(id)sender {
    NSRange selectedNSRange = _textView.selectedTextRange;
    if (selectedNSRange.length) {
        [self deleteBackward];
    }
}

- (void)replace:(id)sender {
}

- (void)paste:(id)sender {
    NSString *pasteText = [[UIPasteboard generalPasteboard] valueForPasteboardType:@"public.utf8-plain-text"];
    if (!pasteText) {
        pasteText = [[UIPasteboard generalPasteboard] valueForPasteboardType:@"public.text"];
    }
    if (pasteText!=nil) {
        NSArray *arr = [pasteText componentsSeparatedByString:@"\n"];
        if (arr.count > 1) {
            int i = 0;
            for (;  i < arr.count-1; i++) {
                [self insertText:[arr objectAtIndex:i]];
                [self insertText:@"\n"];
            }
            [self insertText:[arr objectAtIndex:i]];
        }else
            [self insertText:pasteText];
    }
}

- (void)select:(id)sender{
    NSRange outRange = [_textView characterRangeAtIndex:_textView.selectedTextRange.location];
    _textView.selectedTextRange = outRange;
    [self performSelector:@selector(showMenu) withObject:nil afterDelay:0.2];
}

- (void)selectAll:(id)sender {
    _textView.selectedTextRange = NSMakeRange(0, _text.length);
    [self performSelector:@selector(showMenu) withObject:nil afterDelay:0.2];
}

#pragma mark HTML Related
- (NSString *)exportHTMLString{
    NSMutableString *finalString = [NSMutableString string];
    NSMutableDictionary *attribs = [self getAttributes];
    NSMutableArray *attrArr = [attribs objectForKey:@"attributes"];
    NSMutableArray *paragraphs = [attribs objectForKey:@"paragraphs"];
    NSMutableArray *hyperLinks = [attribs objectForKey:@"links"];
    
    [hyperLinks sortUsingComparator:globalSortBlock];
    
    NSMutableArray *intersectFormats = [NSMutableArray array];
    NSMutableSet *arrToRemove = [NSMutableSet set];
    
    NSRange intersectRange;
    for (P2MSTextFormat *txtFmt in attrArr) {
        NSUInteger finalLoc = txtFmt.formatRange.location + txtFmt.formatRange.length;
        
        NSUInteger curLoc = txtFmt.formatRange.location;
        for (P2MSLink *curLink in hyperLinks){
            intersectRange = NSIntersectionRange(txtFmt.formatRange, curLink.formatRange);
            if (intersectRange.length == curLink.formatRange.length && curLink.formatRange.length <=  txtFmt.formatRange.length)break;
            if (intersectRange.length){
                [arrToRemove addObject:txtFmt];
                if (curLoc < intersectRange.location) {
                    P2MSTextFormat *fmtToAdd = [[P2MSTextFormat alloc]init];
                    fmtToAdd.formatRange = NSMakeRange(curLoc, intersectRange.location-curLoc);;
                    fmtToAdd.txtFormat = txtFmt.txtFormat;
                    [intersectFormats addObject:fmtToAdd];
                }
                P2MSTextFormat *fmtToAdd = [[P2MSTextFormat alloc]init];
                fmtToAdd.formatRange = intersectRange;
                fmtToAdd.txtFormat = txtFmt.txtFormat;
                [intersectFormats addObject:fmtToAdd];
                curLoc = intersectRange.location + intersectRange.length;
            }
        }
        if (curLoc > txtFmt.formatRange.location && curLoc < finalLoc) {
            P2MSTextFormat *fmtToAdd = [[P2MSTextFormat alloc]init];
            fmtToAdd.formatRange = NSMakeRange(curLoc, finalLoc - curLoc);
            fmtToAdd.txtFormat = txtFmt.txtFormat;
            [intersectFormats addObject:fmtToAdd];
        }
    }
    
    for (P2MSTextFormat *txtFormat in arrToRemove) {
        [attrArr removeObject:txtFormat];
    }
    for (P2MSTextFormat *txtFmt in intersectFormats) {
        [attrArr addObject:txtFmt];
    }
    
    [attrArr sortUsingComparator:globalSortBlock];
    
    PARAGRAPH_FORMAT prevParaFormat = TEXT_PARAGRAPH;
    NSRange prevParaRange = NSMakeRange(NSNotFound, 0);
    NSMutableString *paraString = [NSMutableString string];
    NSRange prevLinkRange = NSMakeRange(NSNotFound, 0);
    NSRange linkIntersectRange;
    
    BOOL isPrevOpen = NO;
    for (P2MSTextFormat *txtFmt in attrArr) {
        NSString *curPartString = [_text substringWithRange:txtFmt.formatRange];
        BOOL isEndWithNewLine = [curPartString hasSuffix:@"\n"];
        NSMutableString *curTextStr = [NSMutableString string];
        NSRange insideLinkRange = NSMakeRange(NSNotFound, 0);
        NSUInteger finalLoc = txtFmt.formatRange.location;
        P2MSLink *curLinkToThink = nil;
        for (P2MSLink *curLink in hyperLinks) {
            if ((linkIntersectRange = NSIntersectionRange(curLink.formatRange, txtFmt.formatRange)).length) {
                insideLinkRange = curLink.formatRange;
                if (linkIntersectRange.length == insideLinkRange.length && insideLinkRange.length <= txtFmt.formatRange.length){
                    NSRange firstPart = NSMakeRange(finalLoc, linkIntersectRange.location-finalLoc);
                    NSRange secondPart = linkIntersectRange;
                    NSString *firstStr = [_text substringWithRange:firstPart];
                    NSString *secondStr = [_text substringWithRange:secondPart];
                    [curTextStr appendFormat:@"%@<a href=\"%@\">%@</a>",[firstStr gtm_stringByEscapingForHTML], curLink.linkURL, [secondStr gtm_stringByEscapingForHTML]];
                    finalLoc = linkIntersectRange.location + linkIntersectRange.length;
                }else{
                    curLinkToThink = curLink;
                }
            }
        }
        
        [curTextStr appendString:[_text substringWithRange:NSMakeRange(finalLoc, txtFmt.formatRange.location+txtFmt.formatRange.length-finalLoc)]];
        NSString *textFormat = [self APPLYHTMLTEXTFORMAT:txtFmt.txtFormat toString:curTextStr];
        
        if (prevLinkRange.location != NSNotFound) {
            if (!curLinkToThink) {//no more link and add closing tag
                textFormat = [NSString stringWithFormat:@"</a>%@", textFormat];
                prevLinkRange = NSMakeRange(NSNotFound, 0);
            }else if (curLinkToThink.formatRange.location != prevLinkRange.location){
                textFormat = [NSString stringWithFormat:@"%@</a><a href=\"%@\">", textFormat, curLinkToThink.linkURL];
                prevLinkRange = curLinkToThink.formatRange;
            }
        }else if (curLinkToThink){
            textFormat = [NSString stringWithFormat:@"<a href=\"%@\">%@", curLinkToThink.linkURL, textFormat];
            prevLinkRange = insideLinkRange;
        }
        
        PARAGRAPH_FORMAT insideParaFormat = TEXT_PARAGRAPH;
        NSRange insideParaRange = NSMakeRange(NSNotFound, 0);
        
        for (P2MSParagraph *paraFmt in paragraphs) {
            if (NSIntersectionRange(paraFmt.formatRange, txtFmt.formatRange).length) {
                insideParaFormat = paraFmt.paraFormat;
                insideParaRange = paraFmt.formatRange;break;
            }
        }
        
        if (prevParaRange.location != NSNotFound) {
            if (prevParaFormat == insideParaFormat) {
                if (prevParaFormat == TEXT_BULLET || prevParaFormat == TEXT_NUMBERING) {
                    if (isEndWithNewLine){
                        [paraString appendFormat:(isPrevOpen)?@"%@</li>":@"<li>%@</li>", textFormat];
                        isPrevOpen = NO;
                    }else{
                        if (isPrevOpen) {
                            [paraString appendString:textFormat];
                        }else{
                            [paraString appendFormat:@"<li>%@", textFormat];
                            isPrevOpen = YES;
                        }
                    }
                }else
                    [paraString appendString:textFormat];
            }else{
                if (isPrevOpen){
                    [paraString appendString:@"</li>"];
                    isPrevOpen = NO;
                }
                [finalString appendString:[self APPLY_PARAGRAPHFORMAT:prevParaFormat toString:paraString]];
                if (insideParaFormat != TEXT_PARAGRAPH) {
                    prevParaFormat = insideParaFormat;
                    prevParaRange = insideParaRange;
                    if (prevParaFormat == TEXT_BULLET || prevParaFormat == TEXT_NUMBERING) {
                        if (isEndWithNewLine) {
                            paraString = [NSMutableString stringWithFormat:@"<li>%@</li>", textFormat];
                            isPrevOpen = NO;
                        }else{
                            paraString = [NSMutableString stringWithFormat:@"<li>%@", textFormat];
                            isPrevOpen = YES;
                        }
                    }else
                        paraString = [NSMutableString stringWithString:textFormat];
                }else{
                    [finalString appendString:textFormat];
                    paraString = [NSMutableString string];
                    prevParaFormat = TEXT_PARAGRAPH;
                    prevParaRange = NSMakeRange(NSNotFound, 0);
                }
            }
        }else if(insideParaFormat != TEXT_PARAGRAPH && insideParaRange.location != NSNotFound){
            if (insideParaFormat == TEXT_BULLET || insideParaFormat == TEXT_NUMBERING) {
                if (isEndWithNewLine) {
                    [paraString appendFormat:@"<li>%@</li>", textFormat];
                    isPrevOpen = NO;
                }else{
                    [paraString appendFormat:@"<li>%@", textFormat];
                    isPrevOpen = YES;
                }
            }else
                paraString = [NSMutableString stringWithString:textFormat];
            prevParaRange = insideParaRange;
            prevParaFormat = insideParaFormat;
        }else
            [finalString appendString:textFormat];
    }
    if (prevLinkRange.location != NSNotFound)[finalString appendString:@"</a>"];
    if (isPrevOpen) { [paraString appendString:@"</li>"];isPrevOpen = NO; }
    if (paraString.length) {
        [finalString appendString:[self APPLY_PARAGRAPHFORMAT:prevParaFormat toString:paraString]];
    }
    //    [finalString replaceOccurrencesOfString:@"\n" withString:@"<br>" options:NSLiteralSearch range:NSMakeRange(0, finalString.length)];
    return finalString;
}

- (NSString *)APPLYHTMLTEXTFORMAT:(TEXT_FORMAT)txtFmt toString:(NSString *)finalString{
    if (txtFmt & TEXT_BOLD) {
        finalString =  [NSString stringWithFormat:@"<b>%@</b>", finalString];
    }
    if (txtFmt & TEXT_ITALIC) {
        finalString =  [NSString stringWithFormat:@"<i>%@</i>", finalString];
    }
    if (txtFmt & TEXT_UNDERLINE) {
        finalString =  [NSString stringWithFormat:@"<u>%@</u>", finalString];
    }
    if (txtFmt & TEXT_STRIKE_THROUGH) {
        finalString =  [NSString stringWithFormat:@"<strike>%@</strike>", finalString];
    }
    if (txtFmt & TEXT_HIGHLIGHT) {
        finalString =  [NSString stringWithFormat:@"<mark>%@</mark>", finalString];
    }
    return finalString;
}

- (NSString *)APPLY_PARAGRAPHFORMAT:(PARAGRAPH_FORMAT)paraFmt toString:(NSString *)str{
    NSString *finalString = str;
    if (paraFmt == TEXT_SECTION) {
        finalString =  [NSString stringWithFormat:@"<h3>%@</h3>", finalString];
    }
    if (paraFmt == TEXT_SUBSECTION) {
        finalString =  [NSString stringWithFormat:@"<h5>%@</h5>", finalString];
    }
    if (paraFmt == TEXT_BLOCK_QUOTE) {
        finalString =  [NSString stringWithFormat:@"<blockquote>%@</blockquote>", finalString];
    }
    if (paraFmt == TEXT_BULLET) {
        finalString =  [NSString stringWithFormat:@"<ul>%@</ul>", finalString];
    }
    if (paraFmt == TEXT_NUMBERING) {
        finalString =  [NSString stringWithFormat:@"<ol>%@</ol>", finalString];
    }
    return finalString;
}

- (void)importHTMLString:(NSString *)htmlString{
//    NSString *newhtmlString = [P2MSTextView addExtraNewLines:htmlString];
//    NSArray *htmlNodes = [P2MSTextView getHTMLNodes:newhtmlString];
    NSArray *htmlNodes = [P2MSTextView getHTMLNodes:htmlString];
    NSMutableString *finalStr = [NSMutableString string];
    NSUInteger lastIndex = 0, curLength = 0;
    for (P2MSHTMLNode *curNode in htmlNodes) {
        curLength = curNode.content.length;
        curNode.range = NSMakeRange(lastIndex, curLength);
        [finalStr appendString:curNode.content];
        lastIndex += curLength;
    }
    
    NSMutableArray *attrArr = [NSMutableArray array];
    NSMutableSet *paraSet = [NSMutableSet set];
    NSMutableSet *allLinks = [NSMutableSet set];
    
    NSDictionary *txtFmtReferenceTable = [NSMutableDictionary dictionaryWithObjects:
                                          [NSArray arrayWithObjects:
                                           [NSNumber numberWithInt:TEXT_BOLD],
                                           [NSNumber numberWithInt:TEXT_ITALIC],
                                           [NSNumber numberWithInt:TEXT_UNDERLINE],
                                           [NSNumber numberWithInt:TEXT_STRIKE_THROUGH],
                                           [NSNumber numberWithInt:TEXT_HIGHLIGHT],
                                           [NSNumber numberWithInt:TEXT_BULLET],
                                           [NSNumber numberWithInt:TEXT_NUMBERING],
                                           [NSNumber numberWithInt:TEXT_SECTION],
                                           [NSNumber numberWithInt:TEXT_SUBSECTION],
                                           [NSNumber numberWithInt:TEXT_BLOCK_QUOTE],
                                           [NSNumber numberWithInt:TEXT_PARAGRAPH],
                                           [NSNumber numberWithInt:TEXT_FORMAT_NONE],
                                           [NSNumber numberWithInt:TEXT_PARAGRAPH],
                                           nil] forKeys:
                                          [NSArray arrayWithObjects:@"b", @"i", @"u", @"strike", @"mark", @"ul", @"ol", @"h3", @"h5", @"blockquote", @"li", @"NO_HTML", @"a",
                                           nil]];
    
    for (P2MSHTMLNode *curNode in htmlNodes) {
        P2MSHTMLNode *internalNode = curNode;
        [P2MSTextView convertNode:&internalNode toParaAttributes:&paraSet toAttributes:&attrArr andLinks:&allLinks refDict:txtFmtReferenceTable];
    }
    
    [curParagraphs removeAllObjects];
    [curAttributes removeAllObjects];
    [links removeAllObjects];
    curParaRange = NSMakeRange(NSNotFound, 0);
    curParagraphFormat = TEXT_PARAGRAPH;
    curActionRange = NSMakeRange(NSNotFound, 0);
    curSetTextFormat = TEXT_FORMAT_NOT_SET;
    curTextFormat = TEXT_FORMAT_NONE;
    
    curParagraphs = paraSet;
    curAttributes = attrArr;
    links = allLinks;
    _text = finalStr;
    
    NSUInteger curIndex = 0;
    for (P2MSParagraph *curPara in curParagraphs) {
        if (NSLocationInRange(curIndex, curPara.formatRange)) {
            curParagraphFormat = curPara.paraFormat;
            curParaRange = curPara.formatRange;
            [curParagraphs removeObject:curPara];break;
        }
    }
    [curAttributes sortUsingComparator:globalSortBlock];
    [self forceReflectFormatForLocationChange:0];
    
    self.textView.markedTextRange = NSMakeRange(NSNotFound, 0);
    self.textView.selectedTextRange = NSMakeRange(0, 0);
    [self.textView setContentText:self.text];
    [self adjustScrollView];
}

#pragma mark LinkViewDelegate
- (void)linkViewDidCancel:(P2MSLinkViewController *)viewController{
    [((UIViewController *)self.textViewDelegate) dismissModalViewControllerAnimated:YES];
}

- (void)linkViewDidClose:(P2MSLinkViewController *)viewController{
    _textView.markedTextRange = NSMakeRange(NSNotFound, 0);
    NSString *linkName = viewController.linkTitle;
    NSString *linkURL = viewController.linkURL;
    NSRange linkRange = viewController.linkRange;
    if (linkURL && linkURL.length) {
        if (!(linkName || linkName.length)) {
            linkName = linkURL;
        }
        if (linkRange.location == NSNotFound) {
            linkRange = NSMakeRange(_textView.selectedTextRange.location, linkName.length);
            [self insertText:linkName];
        }
        P2MSLink *link = [[P2MSLink alloc]init];
        link.formatRange = linkRange;
        link.linkURL = linkURL;
        [links addObject:link];
    }
    [((UIViewController *)self.textViewDelegate) dismissModalViewControllerAnimated:YES];
}

+ (void)convertNode:(P2MSHTMLNode **)passNode toParaAttributes:(NSMutableSet **)paraSet toAttributes:(NSMutableArray **)attrArr andLinks:(NSMutableSet **)allLinks refDict:(NSDictionary *)dict{
    P2MSHTMLNode *node = *passNode;
    NSRange strRange = node.range;
    //calculate child range
    if (node.children) {
        NSUInteger lastIndex = strRange.location, curLength = 0;
        for (P2MSHTMLNode *myNode in node.children) {
            curLength = myNode.content.length;
            myNode.range = NSMakeRange(lastIndex, curLength);
            lastIndex += curLength;
        }
    }
    
    NSString *htmlTag = node.htmlTag;
    if (![htmlTag isEqualToString:@"NO_HTML"]) {
        if (strRange.location != NSNotFound && strRange.length > 0) {
            NSNumber *refFmt = [dict objectForKey:htmlTag];
            if (refFmt) {
                int format = [refFmt intValue];
                if (format >= 100) {
                    if ([htmlTag isEqualToString:@"li"] || [htmlTag isEqualToString:@"a"]) {
                        if (node.children && node.children.count) {
                            if (format != TEXT_PARAGRAPH) {
                                [self addParaFormat:format forRange:strRange toArr:paraSet];
                            }
                        }else{
                            [self addTextFormat:TEXT_FORMAT_NONE forRange:strRange toArr:attrArr];
                        }
                        if ([htmlTag isEqualToString:@"a"]) {
                            P2MSLink *link = [[P2MSLink alloc]init];
                            link.linkURL = [node.attributes objectForKey:@"href"];
                            link.formatRange = node.range;
                            [(*allLinks) addObject:link];
                        }
                    }else{
                        [self addParaFormat:format forRange:strRange toArr:paraSet];
                        if (node.children && node.children.count) {}//nothing to do in this case
                        else//it occurs only when there is no text formatting applied on it
                            [self addTextFormat:TEXT_FORMAT_NONE forRange:strRange toArr:attrArr];
                    }
                    
                }else{
                    [self addTextFormat:format forRange:strRange toArr:attrArr];
                }
            }
        }
        if (node.children) {
            for (P2MSHTMLNode *curNode in node.children) {
                P2MSHTMLNode *internalNode = curNode;
                [self convertNode:&internalNode toParaAttributes:paraSet toAttributes:attrArr andLinks:allLinks refDict:dict];
            }
        }
    }else{
        [self addTextFormat:TEXT_FORMAT_NONE forRange:strRange toArr:attrArr];
    }
}

+ (void)addTextFormat:(TEXT_FORMAT)txtFmt forRange:(NSRange)range toArr:(NSMutableArray **)attrArr{
    BOOL isNew = YES;
    for (P2MSTextFormat *txtFormat in *attrArr) {
        if (NSIntersectionRange(txtFormat.formatRange, range).length > 0) {
            txtFormat.txtFormat |= txtFmt;
            isNew = NO;break;
        }
    }
    if (isNew) {
        P2MSTextFormat *curFmt = [[P2MSTextFormat alloc]init];
        curFmt.txtFormat = txtFmt;
        curFmt.formatRange = range;
        [(*attrArr) addObject:curFmt];
    }
}

+ (void)addParaFormat:(PARAGRAPH_FORMAT)paraFmt forRange:(NSRange)range toArr:(NSMutableSet **)arr{
    P2MSParagraph *curFmt = [[P2MSParagraph alloc]init];
    curFmt.paraFormat = paraFmt;
    curFmt.formatRange = range;
    [(*arr) addObject:curFmt];
}

+ (NSString *)stripHTML:(NSString *)inString{
    NSRange r;
    while ((r = [inString rangeOfString:@"<[^>]+>" options:NSRegularExpressionSearch]).location != NSNotFound)
        inString = [inString stringByReplacingCharactersInRange:r withString:@""];
    NSString *s = [inString gtm_stringByUnescapingFromHTML];
    return s;
}

+ (NSMutableArray *)getHTMLNodes:(NSString *)htmlString{
    NSMutableArray *nodes = [NSMutableArray array];
    NSScanner *theScanner= [NSScanner scannerWithString:htmlString];
    theScanner.charactersToBeSkipped = nil;
    BOOL canScan;
    NSUInteger strLength = htmlString.length;
    do {
        canScan = NO;
        NSString *replace_text = nil, *initialString = nil;
        BOOL first;
        NSUInteger curLoc =[theScanner scanLocation];
        if (curLoc < strLength && [htmlString characterAtIndex:curLoc] == '<') {
            first = YES;
        }else{
            first = [theScanner scanUpToString: @"<" intoString:&initialString];
        }
        
        if (initialString && initialString.length) {
            [self processNewLineInNoHTML:initialString intoArray:&nodes];
            initialString = nil;
        }else if (!first){
            NSUInteger nextLocation = [theScanner scanLocation];
            if (nextLocation < htmlString.length) {
                [self processNewLineInNoHTML:[htmlString substringFromIndex:nextLocation] intoArray:&nodes];
            }
        }
        if (first  && [theScanner scanUpToString: @">" intoString:&replace_text]) {
            NSString *htmlTagRaw = [replace_text substringFromIndex:1];
            NSArray *htmlTagAndAttrArr = [htmlTagRaw componentsSeparatedByString:@" "];
            NSString *htmlTag = [htmlTagAndAttrArr objectAtIndex:0];
            NSString *finalStr = [NSString stringWithFormat:@"</%@>", htmlTag];
            NSString *content = nil;
            if ((canScan = [theScanner scanUpToString:finalStr intoString:&content])) {
                P2MSHTMLNode *oneNode = [[P2MSHTMLNode alloc]init];
                oneNode.htmlTag = htmlTag;
                NSString *contentToSave = [content substringFromIndex:1];
                NSString *htmlStripped = [self stripHTML:contentToSave];
                
                oneNode.content = htmlStripped;
                if (htmlStripped && ![htmlStripped isEqualToString:contentToSave]) {
                    oneNode.children = [self getHTMLNodes:contentToSave];
                }else{
                    NSArray *children = [self stripNewLine:htmlStripped];
                    if (children.count > 1) {
                        NSMutableArray *childrenNodes = [NSMutableArray array];
                        for (NSString *inStr in children) {
                            P2MSHTMLNode *oneNode = [[P2MSHTMLNode alloc]init];
                            oneNode.htmlTag = @"NO_HTML";
                            oneNode.content = inStr;
                            [childrenNodes addObject:oneNode];
                        }
                        oneNode.children = childrenNodes;
                    }
                }
                //add attributes
                for (int i = 1; i < htmlTagAndAttrArr.count; i++) {
                    NSString *str = [htmlTagAndAttrArr objectAtIndex:i];
                    NSArray *valuePair = [str componentsSeparatedByString:@"="];
                    if (valuePair.count == 2) {
                        NSString *keyPart = [NSString stringWithFormat:@"%@", [valuePair objectAtIndex:0]];
                        [oneNode.attributes setObject:[[valuePair objectAtIndex:1] stringByReplacingOccurrencesOfString:@"\"" withString:@""] forKey:keyPart];
                    }
                }
                [nodes addObject:oneNode];
                [theScanner setScanLocation:[theScanner scanLocation]+finalStr.length];
            }
        }
    } while (canScan);
    return (nodes.count)?nodes:nil;
}

+ (void)processNewLineInNoHTML:(NSString *)strChunk intoArray:(NSMutableArray **)nodesContainer{
    NSString *strippedStr = [self stripHTML:strChunk];
    NSArray *children = [self stripNewLine:strippedStr];
    for (NSString *inStr in children) {
        P2MSHTMLNode *oneNode = [[P2MSHTMLNode alloc]init];
        oneNode.htmlTag = @"NO_HTML";
        oneNode.content = inStr;
        [*nodesContainer addObject:oneNode];
    }
}

+ (NSArray *)stripNewLine:(NSString *)strChunk{
    NSMutableArray *arr = [NSMutableArray array];
    NSUInteger lastIndex = 0;
    NSRange curRange;
    NSUInteger finalLoc = strChunk.length;
    while ((curRange = [strChunk rangeOfString:@"\n" options:NSLiteralSearch range:NSMakeRange(lastIndex, finalLoc-lastIndex)]).location != NSNotFound) {
        NSString *subAction =  [strChunk substringWithRange:NSMakeRange(lastIndex, (curRange.location+curRange.length)-lastIndex)];
        [arr addObject:subAction];
        lastIndex = curRange.location+curRange.length;
    }
    if (lastIndex < finalLoc) {
        NSString *subAction =  [strChunk substringWithRange:NSMakeRange(lastIndex, finalLoc-lastIndex)];
        [arr addObject:subAction];
    }
    return arr;
}


+ (CGFloat)suggestHeightForHTMLText:(NSString *)htmlText Width:(CGFloat)widthConstraint withFonts:(NSDictionary *)fonts{
    UIFont *normalFont = [fonts objectForKey:kNormalFont];
    UIFont *boldFont = [fonts objectForKey:kBoldFont];
    UIFont *italicFont = [fonts objectForKey:kItalicFont];
    UIFont *boldItalicFont = [fonts objectForKey:kBoldItalicFont];
    
    if (!normalFont) {
        normalFont = [UIFont fontWithName:@"HelveticaNeue" size:12];
    }
    CGFloat normalFontSize = normalFont.pointSize;
    CGFloat subSectionFontSize = normalFontSize+8;
    CGFloat sectionFontSize = normalFontSize+17;
    
    if (!boldFont) {
        boldFont = [UIFont fontWithName:[NSString stringWithFormat:@"%@-Bold", normalFont.fontName] size:normalFontSize];
    }
    if (!italicFont) {
        italicFont = [UIFont fontWithName:[NSString stringWithFormat:@"%@-Italic", normalFont.fontName] size:normalFontSize];
    }
    if (!boldItalicFont) {
        boldItalicFont = [UIFont fontWithName:[NSString stringWithFormat:@"%@-BoldItalic", normalFont.fontName] size:normalFontSize];
    }
    
    
    NSArray *htmlNodes = [P2MSTextView getHTMLNodes:htmlText];
    NSMutableString *finalStr = [NSMutableString string];
    NSUInteger lastIndex = 0, curLength = 0;
    for (P2MSHTMLNode *curNode in htmlNodes) {
        curLength = curNode.content.length;
        curNode.range = NSMakeRange(lastIndex, curLength);
        [finalStr appendString:curNode.content];
        lastIndex += curLength;
    }
    
    NSMutableArray *attrArr = [NSMutableArray array];
    NSMutableSet *paraSet = [NSMutableSet set];
    NSMutableSet *allLinks = nil;
    
    NSDictionary *txtFmtReferenceTable = [NSMutableDictionary dictionaryWithObjects:
                                          [NSArray arrayWithObjects:
                                           [NSNumber numberWithInt:TEXT_BOLD],
                                           [NSNumber numberWithInt:TEXT_ITALIC],
                                           [NSNumber numberWithInt:TEXT_UNDERLINE],
                                           [NSNumber numberWithInt:TEXT_STRIKE_THROUGH],
                                           [NSNumber numberWithInt:TEXT_HIGHLIGHT],
                                           [NSNumber numberWithInt:TEXT_BULLET],
                                           [NSNumber numberWithInt:TEXT_NUMBERING],
                                           [NSNumber numberWithInt:TEXT_SECTION],
                                           [NSNumber numberWithInt:TEXT_SUBSECTION],
                                           [NSNumber numberWithInt:TEXT_BLOCK_QUOTE],
                                           [NSNumber numberWithInt:TEXT_PARAGRAPH],
                                           [NSNumber numberWithInt:TEXT_FORMAT_NONE],
                                           [NSNumber numberWithInt:TEXT_PARAGRAPH],
                                           nil] forKeys:
                                          [NSArray arrayWithObjects:@"b", @"i", @"u", @"strike", @"mark", @"ul", @"ol", @"h3", @"h5", @"blockquote", @"li", @"NO_HTML", @"a", nil]];
    
    for (P2MSHTMLNode *curNode in htmlNodes) {
        P2MSHTMLNode *internalNode = curNode;
        [P2MSTextView convertNode:&internalNode toParaAttributes:&paraSet toAttributes:&attrArr andLinks:&allLinks refDict:txtFmtReferenceTable];
    }
    [attrArr sortUsingComparator:globalSortBlock];
    
    NSDictionary *attributes;
    
    CTFontRef ctFont = CTFontCreateWithName((__bridge CFStringRef) normalFont.fontName, normalFontSize, NULL);
    // Set CTFont instance in our attributes dictionary, to be set on our attributed string.
    attributes = @{ (NSString *)kCTFontAttributeName : (__bridge id)ctFont };
    NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:[P2MSTextView stripHTML:htmlText] attributes:attributes];
    CGFloat fontLineHeight = 0;
    fontLineHeight += CTFontGetAscent(ctFont);
    fontLineHeight += CTFontGetDescent(ctFont);
    fontLineHeight += CTFontGetLeading(ctFont);
    
    CFRelease(ctFont);
    
    for (P2MSParagraph *curPara in paraSet) {
        NSRange paraRange = curPara.formatRange;
        int paraFormat = curPara.paraFormat;
        if (paraFormat == TEXT_PARAGRAPH)continue;
        switch (paraFormat) {
            case TEXT_SECTION:{
                CTFontRef ctFont = CTFontCreateWithName((__bridge CFStringRef) normalFont.fontName, sectionFontSize, NULL);
                [attributedString addAttribute:(NSString *)kCTFontAttributeName value:(__bridge id)ctFont range:paraRange];
                CFRelease(ctFont);
            }break;
            case TEXT_SUBSECTION:{
                CTFontRef ctFont = CTFontCreateWithName((__bridge CFStringRef) normalFont.fontName, subSectionFontSize, NULL);
                [attributedString addAttribute:(NSString *)kCTFontAttributeName value:(__bridge id)ctFont range:paraRange];
                CFRelease(ctFont);
            }break;
            case TEXT_BLOCK_QUOTE:{
                [P2MSTextView applyParagraphStyleForString:&attributedString ToRange:paraRange withLeftPadding:26.0];
            }break;
            case TEXT_BULLET:{
                [P2MSTextView applyParagraphStyleForString:&attributedString ToRange:paraRange withLeftPadding:25.0];
            }break;
            case TEXT_NUMBERING:{
                [P2MSTextView applyParagraphStyleForString:&attributedString ToRange:paraRange withLeftPadding:28.0];
            }break;
            default:break;
        }
    }
    if (attrArr.count) {
        for (P2MSTextFormat *curFormat in attrArr) {
            int num = curFormat.txtFormat;
            if (num == TEXT_FORMAT_NONE)continue;
            NSRange curRange = curFormat.formatRange;
            if (curRange.location+curRange.length > htmlText.length) {
                NSInteger newLength = htmlText.length;
                newLength -= curRange.location;
                curRange = NSMakeRange(curRange.location, (newLength>0)?newLength:0);
            }
            int pointSize = normalFontSize;
            for (P2MSParagraph *curPara in paraSet) {
                NSRange paraRange = curPara.formatRange;
                if (NSLocationInRange(curRange.location, paraRange) ) {
                    int paraFormat = curPara.paraFormat;
                    switch (paraFormat) {
                        case TEXT_SECTION:pointSize = sectionFontSize;break;
                        case TEXT_SUBSECTION:pointSize = subSectionFontSize;break;
                        case TEXT_BLOCK_QUOTE:
                        default:pointSize = normalFontSize;break;
                    }
                    break;
                }
            }
            if (num & TEXT_BOLD && num & TEXT_ITALIC) {
                CTFontRef ctFont = CTFontCreateWithName((__bridge CFStringRef) boldItalicFont.fontName, pointSize, NULL);
                [attributedString addAttribute:(NSString *)kCTFontAttributeName value:(__bridge id)ctFont range:curRange];
                CFRelease(ctFont);
            }else if (num & TEXT_BOLD) {
                CTFontRef ctFont = CTFontCreateWithName((__bridge CFStringRef) boldFont.fontName, pointSize, NULL);
                [attributedString addAttribute:(NSString *)kCTFontAttributeName value:(__bridge id)ctFont range:curRange];
                CFRelease(ctFont);
            }else if (num & TEXT_ITALIC) {
                CTFontRef ctFont = CTFontCreateWithName((__bridge CFStringRef) italicFont.fontName, pointSize, NULL);
                [attributedString addAttribute:(NSString *)kCTFontAttributeName value:(__bridge id)ctFont range:curRange];
                CFRelease(ctFont);
            }
        }
    }
    
    CTFramesetterRef framesetter;
    framesetter = CTFramesetterCreateWithAttributedString((__bridge CFAttributedStringRef)attributedString);
    
    CGSize suggestedSize = CTFramesetterSuggestFrameSizeWithConstraints(framesetter, CFRangeMake(0, 0), NULL, CGSizeMake(widthConstraint, CGFLOAT_MAX), NULL);
    CFRelease(framesetter);
    return suggestedSize.height+fontLineHeight;
}

+ (void)applyParagraphStyleForString:(NSMutableAttributedString **)string ToRange:(NSRange)range withLeftPadding:(CGFloat)leftPadding{
    NSDictionary *paraAttrib = [P2MSContentView getParagraphFormatWithLeftPadding:leftPadding];
    [*string addAttributes:paraAttrib range:range];
}


//+ (NSString *)addExtraNewLines:(NSString *)htmlString{
//    NSMutableString *newString = [NSMutableString string];
//    NSScanner *theScanner= [NSScanner scannerWithString:htmlString];
//    theScanner.charactersToBeSkipped = nil;
//    NSUInteger htmlStrLength = htmlString.length;
//    NSString *replace_text = nil;
//    BOOL canScan = [theScanner scanUpToString:@"</" intoString:&replace_text];
//    NSDictionary *recognizeHTMLTags = [NSDictionary dictionaryWithObjectsAndKeys:@"y", @"h3", @"y", @"h5", @"y", @"bl", @"y", @"li", nil];
//    while (canScan){
//        NSUInteger scanLoc = theScanner.scanLocation;
//        if (canScan) {
//            if (scanLoc < htmlStrLength) {
//                NSString *strToCheck = [htmlString substringWithRange:NSMakeRange(scanLoc+2, 2)];
//                BOOL isSupported = [recognizeHTMLTags objectForKey:strToCheck] != nil;
//                if ([replace_text hasSuffix:@"\n"] || !isSupported) {
//                    [newString appendFormat:@"%@</", replace_text];
//                }else{
//                    [newString appendFormat:@"%@\n</", replace_text];
//                }
//                [theScanner setScanLocation:scanLoc+2];
//            }else
//                [newString appendString:replace_text];
//        }
//        replace_text = nil;
//        canScan = [theScanner scanUpToString:@"</" intoString:&replace_text];
//    };
//    return newString;
//}

- (CGFloat)getTextViewHeight{
    return _textView.frame.size.height;
}

@end
