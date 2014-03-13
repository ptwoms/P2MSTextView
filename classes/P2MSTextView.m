//
//  P2MSTextView.m
//  P2MSTextView
//
//  Created by PYAE PHYO MYINT SOE on 3/12/13.
//  Copyright (c) 2013 PYAE PHYO MYINT SOE. All rights reserved.
//

#import "P2MSTextView.h"
#import <QuartzCore/QuartzCore.h>
#import <objc/objc-runtime.h>
#import "P2MSIndexedRange.h"
#import "P2MSIndexedPosition.h"
#import "P2MSHTMLNode.h"
#import "GTMNSString+HTML.h"

typedef enum {
    MENU_TYPE_CORRECTION,
    MENU_TYPE_ACTION
}MENU_TYPE;


@interface P2MSTextView()<UIGestureRecognizerDelegate>{

    NSRange curActionRange;
    NSRange curSetActionRange;

    TEXT_ATTRIBUTE curSetTextFormat;
    
    NSMutableArray *curAttributes;
    NSMutableSet *links;
    
    //Custom KB
    UIView *styleBaseView;
    
    //delegate method test
    BOOL responseToDidSelectionChange, responseToDidChange;
    BOOL willHandleLink;
    
    P2MSTextWindow *textWindow;
    
    UITextInputStringTokenizer *tokenizer;
    UITextChecker *textChecker;
    
    NSMutableDictionary *menuItemActions;
    NSString *language;
}

@property (nonatomic) P2MSContentView *textView;
@property (nonatomic) NSMutableString *text;

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
        _activeKeyboardType = KEYBOARD_TYPE_DEFAULT;
        _canDisplayCustomKeyboard = YES;
        
        curAttributes = [NSMutableArray array];
        links = [NSMutableSet set];
        
        self.autocorrectionType = UITextAutocorrectionTypeNo;
        _text = [[NSMutableString alloc] init];
        _paragraphs = [[P2MSParagraphs alloc]init];
        _paragraphs.text = _text;
        
        self.editable = YES;
        self.userInteractionEnabled = YES;
        self.autoresizesSubviews = YES;
        
        curActionRange = NSMakeRange(0, 0);
        _curTextStyle = TEXT_FORMAT_NONE;
        
        _selectedRange = NSMakeRange(0, 0);
        _markedRange = NSMakeRange(NSNotFound, 0);
        _correctionRange = NSMakeRange(NSNotFound, 0);
        
        _fontNames = @{@"regular":@"HelveticaNeue", @"bold":@"HelveticaNeue-Bold", @"italic":@"HelveticaNeue-Italic", @"bold_italic":@"HelveticaNeue-BoldItalic" };
        _fontSizes = @{@"normal": [NSNumber numberWithFloat:15], @"section":[NSNumber numberWithFloat:32], @"subsection":[NSNumber numberWithFloat:23]};
        _fontColors = @{@"selection": [UIColor colorWithRed:0.25 green:0.50 blue:1.0 alpha:0.3], @"spelling":[UIColor colorWithRed:1.000f green:0.851f blue:0.851f alpha:1.0f], @"highlight": [UIColor yellowColor], @"caret":[UIColor colorWithRed:0.3176 green:0.41568 blue:0.9294 alpha:0.9], @"link":[UIColor blueColor] };

        //=============== setup display ===============
        _edgeInsets = UIEdgeInsetsMake(8, 8, 8, 8);
        _textView = [[P2MSContentView alloc] initWithFrame:CGRectMake(_edgeInsets.top, _edgeInsets.left, frame.size.width-_edgeInsets.left-_edgeInsets.right,0)];
        _textView.fontNames = _fontNames;
        _textView.fontSizes = _fontSizes;
        _textView.fontColors = _fontColors;
        [self addSubview:_textView];
        _textView.userInteractionEnabled = NO;
        
        //=============== setup gesture recognizers ===============
         _tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tap:)];
        [self addGestureRecognizer:_tapGestureRecognizer];
        _tapGestureRecognizer.delegate = self;
        
        _longPressGestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPress:)];
        _longPressGestureRecognizer.delegate = (id<UIGestureRecognizerDelegate>)self;
        [self addGestureRecognizer:_longPressGestureRecognizer];
        
        _doubleTapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(doubleTap:)];
        [_doubleTapGestureRecognizer setNumberOfTapsRequired:2];
        [self addGestureRecognizer:_doubleTapGestureRecognizer];
        
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

- (void)setPlainText:(NSString *)plainText{
    if (!plainText) {
        plainText = @"";
    }
    _selectedRange = NSMakeRange(0, 0);
    _markedRange = NSMakeRange(NSNotFound, 0);
    _correctionRange = NSMakeRange(NSNotFound, 0);
    [curAttributes removeAllObjects];
    [links removeAllObjects];
    
    curActionRange = NSMakeRange(0, 0);
    _curTextStyle = TEXT_FORMAT_NONE;
    
    if ([[UIMenuController sharedMenuController]isMenuVisible]) {
        [[UIMenuController sharedMenuController]setMenuVisible:NO animated:NO];
    }

    [self insertText:plainText];
}

- (NSString *)plainText{
    return _text;
}

- (void)setFontNames:(NSDictionary *)fontNames{
    _fontNames = fontNames;
    _textView.fontNames = fontNames;
}

- (void)setFontColors:(NSDictionary *)fontColors{
    _fontColors = fontColors;
    _textView.fontColors = fontColors;
}

- (void)setFontSizes:(NSDictionary *)fontSizes{
    _fontSizes = fontSizes;
    _textView.fontSizes = fontSizes;
}

- (void)setText:(NSMutableString *)text{
    if (text) {
        [self insertText:text];
    }
}

- (void)setTextViewDelegate:(id<P2MSTextViewDelegate>)textViewDelegate{
    _textViewDelegate = textViewDelegate;
    willHandleLink = [_textViewDelegate respondsToSelector:@selector(p2msTextViewLinkClicked:andLink:)];
    responseToDidChange = [_textViewDelegate respondsToSelector:@selector(p2msTextViewDidChange:)];
    responseToDidSelectionChange = [_textViewDelegate respondsToSelector:@selector(p2msTextViewDidChangeSelection:)];
}

- (void)adjustScrollView{
    self.contentSize = CGSizeMake(self.bounds.size.width, self.textView.bounds.size.height + self.edgeInsets.top + self.edgeInsets.bottom);
    CGRect finalRect = [self convertRect:_textView.caretView.frame toView:_textView];
    finalRect.origin = CGPointMake(finalRect.origin.x+_edgeInsets.left, finalRect.origin.y+_edgeInsets.top);
    [self scrollRectToVisible:finalRect animated:NO];
}

#pragma mark Ranges
- (void)setSelectedRange:(NSRange)selectedRange{
    _selectedRange = NSMakeRange(selectedRange.location == (NSNotFound)? NSNotFound : MAX(0, selectedRange.location), selectedRange.length);
    [self.textView updateSelection];
}

#pragma mark Format

- (void)saveCurrentAttributes{
    if (curActionRange.length <= 0)return;
    P2MSTextAttribute *txtFormat = [[P2MSTextAttribute alloc]init];
    txtFormat.txtAttrib = _curTextStyle;
    txtFormat.styleRange = curActionRange;
    [curAttributes addObject:txtFormat];
    [curAttributes sortWithOptions:NSBinarySearchingFirstEqual usingComparator:globalSortBlock];
}

- (void)applyFormat:(TEXT_ATTRIBUTE)txtFormat toRange:(NSRange)selectedRange{
    [self saveCurrentAttributes];
    BOOL willApply = NO;
    NSUInteger finalSelPos = selectedRange.location + selectedRange.length;
    if (finalSelPos < _text.length && [_text characterAtIndex:finalSelPos] == '\n') {
        selectedRange = NSMakeRange(selectedRange.location, selectedRange.length+1);
    }
    NSMutableArray *affectedRange = [NSMutableArray array];
    NSMutableArray *newAttributes = [NSMutableArray array];
    for (P2MSTextAttribute *curFmt in curAttributes) {
        NSRange curFmtRange = curFmt.styleRange;
        TEXT_ATTRIBUTE curFormat = curFmt.txtAttrib;
        NSRange intersetRange = NSIntersectionRange(curFmtRange, selectedRange);
        if (intersetRange.length > 0) {
            if (!willApply) {
                willApply = !(curFormat & txtFormat);
            }
            if (intersetRange.length != curFmt.styleRange.length) {
                if (curFmtRange.location < intersetRange.location) {
                    P2MSTextAttribute *firstFmt = [[P2MSTextAttribute alloc]init];
                    firstFmt.txtAttrib = curFormat;
                    firstFmt.styleRange = NSMakeRange(curFmtRange.location, intersetRange.location-curFmtRange.location);
                    [newAttributes addObject:firstFmt];
                    if (intersetRange.location+intersetRange.length < curFmtRange.location+curFmtRange.length) {
                        P2MSTextAttribute *lastFmt = [[P2MSTextAttribute alloc]init];
                        lastFmt.txtAttrib = curFormat;
                        lastFmt.styleRange = NSMakeRange(intersetRange.location+intersetRange.length, (curFmtRange.location+curFmtRange.length)-(intersetRange.location+intersetRange.length));
                        [newAttributes addObject:lastFmt];
                    }
                }else{
                    P2MSTextAttribute *lastFmt = [[P2MSTextAttribute alloc]init];
                    lastFmt.txtAttrib = curFormat;
                    lastFmt.styleRange = NSMakeRange(intersetRange.location+intersetRange.length, (curFmtRange.location+curFmtRange.length)-(intersetRange.location+intersetRange.length));
                    [newAttributes addObject:lastFmt];
                }
                P2MSTextAttribute *middleFmt = [[P2MSTextAttribute alloc]init];
                middleFmt.styleRange = intersetRange;
                middleFmt.txtAttrib = curFormat;
                [affectedRange addObject:middleFmt];
            }else{
                [affectedRange addObject:curFmt];
            }
        }else{
            [newAttributes addObject:curFmt];
        }
    }
    
    for (P2MSTextAttribute *modifiedFmt in affectedRange) {
        if (willApply) {
            modifiedFmt.txtAttrib |= txtFormat;
        }else{
            modifiedFmt.txtAttrib &= (127 ^ txtFormat);
        }
        modifiedFmt.txtAttrib += (modifiedFmt.txtAttrib == TEXT_FORMAT_NOT_SET);
        [newAttributes addObject:modifiedFmt];
    }
    [newAttributes sortWithOptions:NSBinarySearchingFirstEqual usingComparator:globalSortBlock];
    [curAttributes removeAllObjects];
    
    //combine the adjacent ranges that have same attributes
    P2MSTextAttribute *tempFormat = nil;
    for (P2MSTextAttribute *curFmt in newAttributes) {
        if (tempFormat && tempFormat.styleRange.length > 0) {
            NSUInteger lastChar = tempFormat.styleRange.location + tempFormat.styleRange.length - 1;
            if (tempFormat.txtAttrib == curFmt.txtAttrib && [_text characterAtIndex:lastChar] != '\n') {
                tempFormat.styleRange = NSMakeRange(tempFormat.styleRange.location, tempFormat.styleRange.length+curFmt.styleRange.length);
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
    
    //check for current Action and format
    [self forceReflectFormatForLocationChange:selectedRange.location];
    
    curSetTextFormat = TEXT_FORMAT_NOT_SET;
    [_textView refreshView];
}

- (void)reflectFormatForLocationChange:(NSUInteger)index{
    if (index == _text.length) {
        if (index != curActionRange.location+curActionRange.length) {
            P2MSTextAttribute *lastFormat = [curAttributes lastObject];
            if (lastFormat) {
                [self saveCurrentAttributes];
                [curAttributes removeObject:lastFormat];
                curActionRange = lastFormat.styleRange;
                _curTextStyle = lastFormat.txtAttrib;
            }
        }
    }else{
        if (index>0 && [_text characterAtIndex:index] != '\n') {
            index--;
        }
        if (!NSLocationInRange(index, curActionRange)) {
            [self saveCurrentAttributes];
            for (P2MSTextAttribute *curFormat in curAttributes) {
                if (NSLocationInRange(index, curFormat.styleRange)){
                    curActionRange = curFormat.styleRange;
                    _curTextStyle = curFormat.txtAttrib;
                    [curAttributes removeObject:curFormat];
                    break;
                }
            }
        }
    }
}

- (void)forceReflectFormatForLocationChange:(NSUInteger)index{
    if (index == _text.length) {
        P2MSTextAttribute *lastFormat = [curAttributes lastObject];
        if (lastFormat) {
            [curAttributes removeObject:lastFormat];
            curActionRange = lastFormat.styleRange;
            _curTextStyle = lastFormat.txtAttrib;
        }
    }else{
        for (P2MSTextAttribute *curFormat in curAttributes) {
            if (NSLocationInRange(index, curFormat.styleRange)){
                curActionRange = curFormat.styleRange;
                _curTextStyle = curFormat.txtAttrib;
                [curAttributes removeObject:curFormat];
                break;
            }
        }
    }
}

- (void)deleteFormatAtRange:(NSRange)range{
    //retriev overlap formattings
    if (!range.length)return;
    [self processLinkAtRange:range withText:nil];
    NSMutableArray *newAttributes = [NSMutableArray array];
    [self saveCurrentAttributes];
    curActionRange = NSMakeRange(NSNotFound, 0);
    _curTextStyle = TEXT_FORMAT_NONE;
    NSUInteger prevLoc = 0; NSInteger curLength = 0;
    for (P2MSTextAttribute *curFormat in curAttributes) {
        NSRange curFormatRange = curFormat.styleRange;
        NSRange intersectRange = NSIntersectionRange(range, curFormat.styleRange);
        curLength = 0;
        if (intersectRange.length == curFormatRange.length) {
            if (range.location == curFormatRange.location) {
                curActionRange = NSMakeRange(curFormatRange.location, 0);
                _curTextStyle = curFormat.txtAttrib;
            }
        }else{
            curLength = (intersectRange.length > 0)?(NSInteger)curFormatRange.length-(NSInteger)intersectRange.length:curFormatRange.length;
            if (curLength >= 0) {
                curFormat.styleRange = NSMakeRange(prevLoc, curLength);
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


#pragma mark Format Action
- (void)setAction:(TEXT_ATTRIBUTE)txtFormat{
    if (_selectedRange.length) {
        [self applyFormat:txtFormat toRange:_selectedRange];
    }else{
        curSetTextFormat = (curSetTextFormat!=TEXT_FORMAT_NOT_SET)?curSetTextFormat^txtFormat:_curTextStyle^txtFormat;
        curSetTextFormat += curSetTextFormat == TEXT_FORMAT_NOT_SET;
        curSetActionRange = _selectedRange;
    }
    [self reflectIconForActionChange];
}

- (void)setAction:(TEXT_ATTRIBUTE)txtFormat withButton:(UIButton *)sender{
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
        NSInteger locToSearch = _selectedRange.location;
        locToSearch -= (locToSearch > 0);
        NSRange rangeToSearch = NSMakeRange(locToSearch, (_selectedRange.length > 0)?_selectedRange.length:1);
        
        for (P2MSLink *link in links) {
            if (NSIntersectionRange(rangeToSearch, link.styleRange).length > 0) {
                linkVC.linkURL = link.linkURL;
                linkVC.linkRange = link.styleRange;
            }
        }
        if (linkVC.linkRange.location == NSNotFound && _selectedRange.length) {
            linkVC.linkRange = _selectedRange;
        }
        
        [((UIViewController *)self.textViewDelegate) presentModalViewController:linkVC animated:YES];
    }
}

- (void)apply_paragraph_style:(PARAGRAPH_STYLE)para_style{
    [_paragraphs applyParagraphStyle:para_style toRange:_selectedRange];
    [self.textView refreshView];
    self.contentSize = CGSizeMake(self.frame.size.width, self.textView.frame.size.height+_edgeInsets.top+_edgeInsets.bottom);
    [self reflectIconForActionChange];
}

- (void)setEdgeInsets:(UIEdgeInsets)edgeInsets{
    _edgeInsets = edgeInsets;
    self.textView.frame = CGRectMake(_edgeInsets.top, _edgeInsets.left, self.bounds.size.width-_edgeInsets.left-_edgeInsets.right,0);
    [self.textView refreshView];
    self.contentSize = CGSizeMake(self.frame.size.width, self.textView.frame.size.height+_edgeInsets.top+_edgeInsets.bottom);
}


- (IBAction)sectionAction:(id)sender{
    if (curActionRange.length == 0) {
        _curTextStyle = TEXT_BOLD;
        curActionRange = NSMakeRange(_selectedRange.location, 0);
    }
    [self apply_paragraph_style:PARAGRAPH_SECTION];
}


- (IBAction)subSectionAction:(id)sender{
    if (curActionRange.length == 0) {
        _curTextStyle = TEXT_BOLD;
        curActionRange = NSMakeRange(_selectedRange.location, 0);
    }
    [self apply_paragraph_style:PARAGRAPH_SUBSECTION];
}

- (IBAction)paragraphAction:(id)sender{
    [self apply_paragraph_style:PARAGRAPH_NORMAL];
}

- (IBAction)blockquoteAction:(id)sender{
    if (curActionRange.length == 0) {
        _curTextStyle = TEXT_ITALIC;
        curActionRange = NSMakeRange(_selectedRange.location, 0);
    }
    [self apply_paragraph_style:PARAGRAPH_BLOCK_QUOTE];
}

- (IBAction)bulletAction:(id)sender{
    [self apply_paragraph_style:PARAGRAPH_BULLET];
}

- (IBAction)numberingAction:(id)sender{
    [self apply_paragraph_style:PARAGRAPH_NUMBERING];
}

#pragma mark Styles

NSComparisonResult (^globalSortBlock)(id,id) = ^(id lhs, id rhs) {
    NSUInteger firstLoc = ((P2MSStyle *)lhs).styleRange.location;
    NSUInteger secondLoc = ((P2MSStyle *)rhs).styleRange.location;
    if(firstLoc < secondLoc) {
        return (NSComparisonResult)NSOrderedAscending;
    } else if(firstLoc > secondLoc) {
        return (NSComparisonResult)NSOrderedDescending;
    }
    return (NSComparisonResult)NSOrderedSame;
};

- (NSMutableDictionary *)getStyleAttributes{
    NSMutableArray *paraArr = _paragraphs.paragraphs;
    NSMutableDictionary *styles = [NSMutableDictionary dictionaryWithCapacity:2];
    NSMutableArray *arr = [NSMutableArray arrayWithArray:curAttributes];
    if (curActionRange.location != NSNotFound && curActionRange.length > 0) {
        P2MSTextAttribute *tempFormat = [[P2MSTextAttribute alloc]init];
        tempFormat.styleRange = curActionRange;
        tempFormat.txtAttrib = _curTextStyle;
        [arr addObject:tempFormat];
        [arr sortWithOptions:NSBinarySearchingFirstEqual usingComparator:globalSortBlock];
        NSUInteger prevLoc = 0;
        for (P2MSTextAttribute *curFormat in arr) {
            curFormat.styleRange = NSMakeRange(prevLoc, curFormat.styleRange.length);
            prevLoc += curFormat.styleRange.length;
        }
        P2MSTextAttribute *lastFormat = [arr lastObject];
        if (lastFormat) {
            lastFormat.styleRange = NSMakeRange(lastFormat.styleRange.location, _text.length-lastFormat.styleRange.location);
        }
    }
    [styles setObject:paraArr forKey:@"paragraphs"];
    [styles setObject:arr forKey:@"attributes"];
    [styles setObject:links forKey:@"links"];
    return styles;
}


- (void)replaceTextFormatAtRange:(NSRange)range withText:(NSString *)text andSelectedRange:(NSRange)selectedNSRange{
    if (range.location == NSNotFound)return;

    [self processLinkAtRange:range withText:text];
    
    if (range.length > 0) {
        //delete selected range
        NSMutableArray *newAttributes = [NSMutableArray array];
        [self saveCurrentAttributes];
        curActionRange = NSMakeRange(NSNotFound, 0);
        NSUInteger prevLoc = 0; NSInteger curLength = 0;
        for (P2MSTextAttribute *curFormat in curAttributes) {
            NSRange curFormatRange = curFormat.styleRange;
            NSRange intersectRange = NSIntersectionRange(range, curFormat.styleRange);
            curLength = curFormatRange.length;
            if (intersectRange.length > 0) {
                curLength = curLength-(NSInteger)intersectRange.length;
                if (curLength < 0)curLength = 0;
                if (NSLocationInRange(range.location, curFormatRange)) {
                    _curTextStyle = curFormat.txtAttrib;
                    curActionRange = NSMakeRange(curFormatRange.location, curLength);
                }else if (intersectRange.length == curFormatRange.length) {
                    //remove whole range
                }else{
                    curFormat.styleRange = NSMakeRange(prevLoc, curLength);
                    [newAttributes addObject:curFormat];
                }
            }else{
                curFormat.styleRange = NSMakeRange(prevLoc, curLength);
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
    NSUInteger length = text.length;
    
    NSInteger loc = range.location;
    for (P2MSTextAttribute *curFmt in curAttributes) {
        NSRange curARange = curFmt.styleRange;
        if (loc <= curARange.location) {
            curFmt.styleRange = NSMakeRange(curARange.location +length, curARange.length);
        }
    }
    
    BOOL isEnter = [text isEqualToString:@"\n"];
    //treat it as a new insert
    if (curSetTextFormat != TEXT_FORMAT_NOT_SET && !isEnter) {
        if ( curSetTextFormat != _curTextStyle) {
            NSRange insetRange = NSIntersectionRange(curActionRange, NSMakeRange(curSetActionRange.location, (curSetActionRange.length==0)?1:curSetActionRange.length));
            if (insetRange.length != 0) {//cursor is set inside the curret setting and split into two attribs
                P2MSTextAttribute *firstPart = [[P2MSTextAttribute alloc]init];
                firstPart.styleRange = NSMakeRange(curActionRange.location, insetRange.location-curActionRange.location);
                firstPart.txtAttrib = _curTextStyle;
                [curAttributes addObject:firstPart];
                
                P2MSTextAttribute *secondPart = [[P2MSTextAttribute alloc]init];
                secondPart.styleRange = NSMakeRange(curSetActionRange.location+length, curActionRange.length-firstPart.styleRange.length-curSetActionRange.length);
                secondPart.txtAttrib = _curTextStyle & (!TEXT_LINK);
                [curAttributes addObject:secondPart];
                [curAttributes sortWithOptions:NSBinarySearchingFirstEqual usingComparator:globalSortBlock];
            }else{
                [self saveCurrentAttributes];
            }
            curActionRange = NSMakeRange(curSetActionRange.location, length);
            _curTextStyle = curSetTextFormat;
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
                    P2MSTextAttribute *curtxtFmt = [[P2MSTextAttribute alloc]init];
                    curtxtFmt.txtAttrib = _curTextStyle;
                    curtxtFmt.styleRange = NSMakeRange(_paragraphs.current_paragraph.styleRange.location, newLength);
//                    curtxtFmt.styleRange = NSMakeRange(curParaRange.location, newLength);
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


#pragma mark UIKeyInput methods

/**
 UIKeyInput protocol required method.
 A Boolean value that indicates whether the text-entry objects have any text.
 */
- (BOOL)hasText
{
    return (self.text.length != 0);
}

/**
 UIKeyInput protocol required method.
 Insert a character into the displayed text. Called by the text system when the user has entered simple text.
 */
- (void)insertText:(NSString *)text
{
    NSRange selectedNSRange = _selectedRange;
    NSRange markedTextRange = _markedRange;
    NSRange correctionRange = _correctionRange;
    
    if (selectedNSRange.location == NSNotFound) {return;}
    NSRange affectedRange;
    if (correctionRange.location != NSNotFound && correctionRange.length > 0){
        affectedRange =  correctionRange;
        selectedNSRange.length = 0;
        selectedNSRange.location = (correctionRange.location+text.length);
        _correctionRange = NSMakeRange(NSNotFound, 0);
    }else if (markedTextRange.location != NSNotFound) {
        affectedRange = markedTextRange;
		// There is marked text -- replace marked text with user-entered text.
        selectedNSRange.location = markedTextRange.location + text.length;
        selectedNSRange.length = 0;
        markedTextRange = NSMakeRange(NSNotFound, 0);
    } else if (selectedNSRange.length > 0) {
        affectedRange = selectedNSRange;
		// Replace selected text with user-entered text.
        selectedNSRange.length = 0;
        selectedNSRange.location += text.length;
    } else {
        affectedRange = selectedNSRange;
		// Insert user-entered text at current insertion point.
        selectedNSRange.location += text.length;
    }
    //working with document
    [_paragraphs replaceParagraphStlyeAtRange:affectedRange withText:text];
    if (affectedRange.length > 0) {
        [self.text replaceCharactersInRange:affectedRange withString:text];
    }else{
        [self.text insertString:text atIndex:affectedRange.location];
    }

    [self replaceTextFormatAtRange:affectedRange withText:text andSelectedRange:selectedNSRange];
    
	// Update underlying ContextTextView.
    [self.textView setContentText:self.text];
    self.markedRange = markedTextRange;
    self.selectedRange = selectedNSRange;
    if (responseToDidChange) {
        [_textViewDelegate p2msTextViewDidChange:self];
    }
    [self adjustScrollView];
}

/**
 UIKeyInput protocol required method.
 Delete a character from the displayed text. Called by the text system when the user is invoking a delete (e.g. pressing the delete software keyboard key).
 */
- (void)deleteBackward
{
    curSetActionRange = NSMakeRange(NSNotFound, 0);
    curSetTextFormat = TEXT_FORMAT_NOT_SET;
    
    NSRange selectedNSRange = _selectedRange;
    NSRange markedTextRange = _markedRange;
    NSRange correctionRange = _correctionRange;
    
    NSRange affectedRange = NSMakeRange(NSNotFound, 0);
    if (correctionRange.location != NSNotFound && correctionRange.length > 0) {
        affectedRange = correctionRange;
        selectedNSRange.location = correctionRange.location;
        selectedNSRange.length = 0;
        [self setCorrectionRange:NSMakeRange(NSNotFound, 0)];
    }else if (markedTextRange.location != NSNotFound) {
		// There is marked text, so delete it.
        affectedRange = markedTextRange;
        selectedNSRange.location = markedTextRange.location;
        selectedNSRange.length = 0;
        markedTextRange = NSMakeRange(NSNotFound, 0);
    }
    else if (selectedNSRange.length > 0) {
		// Delete the selected text.
        affectedRange = selectedNSRange;
        selectedNSRange.length = 0;
    }
    else if (selectedNSRange.location > 0) {
		// Delete one char of text at the current insertion point.
        selectedNSRange.location--;
        selectedNSRange.length = 1;
        affectedRange = selectedNSRange;
        selectedNSRange.length = 0;
    }
    
    [_paragraphs replaceParagraphStlyeAtRange:affectedRange withText:@""];
    [self.text deleteCharactersInRange:affectedRange];
    [self deleteFormatAtRange:affectedRange];
    
    [self.textView setContentText:self.text];
    self.markedRange = markedTextRange;
    self.selectedRange = selectedNSRange;
    if (responseToDidChange) {
        [_textViewDelegate p2msTextViewDidChange:self];
    }
    [self adjustScrollView];
}

#pragma mark UITextInput - Geometry methods
/**
 UITextInput protocol required method.
 Return the first rectangle that encloses a range of text in a document.
 */
- (CGRect)firstRectForRange:(UITextRange *)range{
    CGRect rect = [self.textView firstRectForRange:((P2MSIndexedRange *)range).range];
    return [self convertRect:rect fromView:self.textView];
}

/*
 UITextInput protocol required method.
 Return a rectangle used to draw the caret at a given insertion point.
 */
- (CGRect)caretRectForPosition:(UITextPosition *)position
{
    CGRect rect =  [self.textView caretRectForIndex:((P2MSIndexedPosition *)position).index];
    return [self convertRect:rect fromView:self.textView];
}


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
    NSRange selectedNSRange = self.selectedRange;
    if ((indexedRange.range.location + indexedRange.range.length) <= selectedNSRange.location) {
        selectedNSRange.location -= (indexedRange.range.length - text.length);
    } else {
        // Need to also deal with overlapping ranges.
    }
    [_paragraphs replaceParagraphStlyeAtRange:indexedRange.range withText:text];
    [self.text replaceCharactersInRange:indexedRange.range withString:text];
    [self replaceTextFormatAtRange:indexedRange.range withText:text andSelectedRange:selectedNSRange];
    [self.textView setContentText:self.text];
    self.selectedRange = selectedNSRange;
    if (responseToDidChange) {
        [_textViewDelegate p2msTextViewDidChange:self];
    }
    [self adjustScrollView];
}


#pragma mark UITextInput - Marked and Selected Text

- (id <UITextInputTokenizer>)tokenizer {
    return tokenizer;
}

- (UITextRange *)selectedTextRange
{
    return [P2MSIndexedRange indexedRangeWithRange:self.selectedRange];
}


- (void)setSelectedTextRange:(UITextRange *)range
{
    P2MSIndexedRange *indexedRange = (P2MSIndexedRange *)range;
    self.selectedRange = indexedRange.range;
}

- (UITextRange *)markedTextRange
{
    NSRange markedTextRange = self.markedRange;
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
    NSRange selectedNSRange = self.selectedRange;
    NSRange markedTextRange = self.markedRange;
    NSRange affectedRange;
    if (markedTextRange.location != NSNotFound) {
        if (!markedText)
            markedText = @"";
		// Replace characters in text storage and update markedText range length.
        affectedRange = markedTextRange;
        [_paragraphs replaceParagraphStlyeAtRange:affectedRange withText:markedText];
        [self.text replaceCharactersInRange:affectedRange withString:markedText];
        markedTextRange.length = markedText.length;
    }
    else if (selectedNSRange.length > 0) {
		// There currently isn't a marked text range, but there is a selected range,
		// so replace text storage at selected range and update markedTextRange.
        affectedRange = selectedNSRange;
        [_paragraphs replaceParagraphStlyeAtRange:affectedRange withText:markedText];
        [self.text replaceCharactersInRange:affectedRange withString:markedText];
        markedTextRange.location = selectedNSRange.location;
        markedTextRange.length = markedText.length;
    }
    else {
		// There currently isn't marked or selected text ranges, so just insert
		// given text into storage and update markedTextRange.
        affectedRange = selectedNSRange;
        [_paragraphs replaceParagraphStlyeAtRange:affectedRange withText:markedText];
        [self.text insertString:markedText atIndex:selectedNSRange.location];
        markedTextRange.location = selectedNSRange.location;
        markedTextRange.length = markedText.length;
    }
	// Updated selected text range and underlying ContentView.
    selectedNSRange = NSMakeRange(selectedRange.location + markedTextRange.location, selectedRange.length);
    [self replaceTextFormatAtRange:affectedRange withText:markedText andSelectedRange:selectedNSRange];
    [self.textView setContentText:self.text];
    self.markedRange = markedTextRange;
    self.selectedRange = selectedNSRange;
    [self adjustScrollView];
}

/**
 UITextInput protocol required method.
 Unmark the currently marked text.
 */
- (void)unmarkText
{
    NSRange markedTextRange = self.markedRange;
    
    if (markedTextRange.location == NSNotFound) {
        return;
    }
    markedTextRange.location = NSNotFound;
    self.markedRange = markedTextRange;
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



#pragma mark UIGestureRecognizer Methods
- (IBAction)tap:(UITapGestureRecognizer *)gestureReg{
    curSetTextFormat = TEXT_FORMAT_NOT_SET;
    if ([self isFirstResponder]) {
        
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(showMenu) object:nil];
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(showCorrectionMenu) object:nil];
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(showRelevantMenu) object:nil];
        
        NSInteger index = [self.textView closestWhitespaceToPoint:[gestureReg locationInView:self.textView]];
        [self setCorrectionRange:NSMakeRange(NSNotFound, 0)];
        UIMenuController *menuController = [UIMenuController sharedMenuController];
        
        if (index == _selectedRange.location) {
            if ([menuController isMenuVisible]) {
                [menuController setMenuVisible:NO animated:NO];
            }else if (_editable){
                [self performSelector:@selector(showRelevantMenu) withObject:nil afterDelay:0.35f];
            }else{
                [self performSelector:@selector(showMenu) withObject:nil afterDelay:0.35f];
            }
        }else{
            if ([menuController isMenuVisible]) {
                [menuController setMenuVisible:NO animated:NO];
            }
            if(_editable)
                [self performSelector:@selector(showCorrectionMenu) withObject:nil afterDelay:0.35f];
        }
        [self.inputDelegate selectionWillChange:self];
        
        if (_editable) {
            [_paragraphs updateCurrentParagraphForPosition:index];
            [self reflectFormatForLocationChange:index];
            [self reflectIconForActionChange];
        }
        self.markedRange = NSMakeRange(NSNotFound, 0);
        self.selectedRange = NSMakeRange(index, 0);
        [self.inputDelegate selectionDidChange:self];
    }
    else {
        [self becomeFirstResponder];
        if (_editable) {
            self.textView.editing = YES;
        }
    }
    if (!_editable) {
        NSInteger index = [self.textView closestWhitespaceToPoint:[gestureReg locationInView:self.textView]];
        self.selectedRange= NSMakeRange(index, 0);
        for (P2MSLink *curLink in links) {
            if (NSLocationInRange(index, curLink.styleRange)) {
                if (willHandleLink) {
                    [_textViewDelegate p2msTextViewLinkClicked:self andLink:curLink];
                }
                break;
            }
        }
    }
}

- (IBAction)doubleTap:(UITapGestureRecognizer *)gestureReg{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(showMenu) object:nil];
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(showCorrectionMenu) object:nil];
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(showRelevantMenu) object:nil];
    
    NSRange range = [self.textView getWordRangeAtPoint:[gestureReg locationInView:self.textView]];
    NSRange oldRange = _selectedRange;
    if (range.location!=NSNotFound){
        self.selectedRange = range;
        [_paragraphs updateCurrentParagraphForPosition:_selectedRange.location];
        if (![[UIMenuController sharedMenuController] isMenuVisible]) {
            [self performSelector:@selector(showMenu) withObject:nil afterDelay:0.1f];
        }
    }
    if (responseToDidSelectionChange && !NSEqualRanges(oldRange, range)) {
        [self.textViewDelegate p2msTextViewDidChangeSelection:self];
    }
}

- (IBAction)longPress:(UILongPressGestureRecognizer*)gestureReg{
    curSetTextFormat = TEXT_FORMAT_NOT_SET;
    [self.textView responseToLongPress:gestureReg];

    if (gestureReg.state==UIGestureRecognizerStateBegan || gestureReg.state == UIGestureRecognizerStateChanged) {
        _correctionRange = NSMakeRange(NSNotFound, 0);
        NSInteger index = _selectedRange.location;
        [_paragraphs updateCurrentParagraphForPosition:index];
        [self reflectFormatForLocationChange:index];
        [self reflectIconForActionChange];

        UIMenuController *menuController = [UIMenuController sharedMenuController];
        if ([menuController isMenuVisible]) {
            [menuController setMenuVisible:NO animated:NO];
        }
    }else if (gestureReg.state == UIGestureRecognizerStateEnded) {
        if (_selectedRange.location!=NSNotFound) {
            [self showMenu];
        }
    }
}

#pragma mark UIGestureRecognizer Delegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gesture shouldReceiveTouch:(UITouch *)touch
{
    return (touch.view == self);
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer{
    P2MSSelectionView *selectionView = _textView.selectionView;
    if (gestureRecognizer == _longPressGestureRecognizer) {
        if (_selectedRange.length>0 && selectionView!=nil) {
            BOOL shouldBegin = CGRectContainsPoint(CGRectInset([_textView convertRect:selectionView.frame toView:self], -20.0f, -20.0f) , [gestureRecognizer locationInView:self]);
            return shouldBegin;
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
        CGRect rect = [self getRectForMenu];
        [menuController setTargetRect:rect inView:self];
        [menuController update];
        [menuController setMenuVisible:YES animated:YES];
    });
}


- (void)showCorrectionMenu {
    if (_textView.isEditing) {
        NSRange outRange = [_textView characterRangeAtIndex:_selectedRange.location];
        if (outRange.location!=NSNotFound && outRange.length>1) {
            [self setCorrectionRange:[textChecker rangeOfMisspelledWordInString:self.text range:outRange startingAt:0 wrap:YES language:language]];
        }
    }
}

- (void)showRelevantMenu {
    if (_textView.isEditing) {
        NSRange outRange = [_textView characterRangeAtIndex:_selectedRange.location];
        if (outRange.location!=NSNotFound && outRange.length>1) {
            NSRange range = [textChecker rangeOfMisspelledWordInString:self.text range:outRange startingAt:0 wrap:YES language:language];
            if (NSEqualRanges(range, _correctionRange) && range.location == NSNotFound && range.length == 0) {
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

- (void)setCorrectionRange:(NSRange)range{
    if (NSEqualRanges(range, _correctionRange) && range.location == NSNotFound && range.length == 0) {
        return;
    }
    _correctionRange = range;
    if (range.location != NSNotFound && range.length > 0) {
        if (!_textView.caretView.hidden) {
            _textView.caretView.hidden = YES;
        }
        [self showCorrectionForRange:range];
    } else {
        if (_textView.caretView.hidden) {
            _textView.caretView.hidden = NO;
            [_textView.caretView blinkCaret];
        }
    }
    [_textView setNeedsDisplay];
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
    _textView.showCorrectinMenu = YES;
    
    NSArray *guesses = [textChecker guessesForWordRange:range inString:_text language:language];
    NSMutableArray *items = nil;
    if (guesses && [guesses count]>0) {
        items = [[NSMutableArray alloc] init];
        if (menuItemActions==nil) {
            menuItemActions = [NSMutableDictionary dictionary];
        }else{
            [menuItemActions removeAllObjects];
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
        CGRect rect = [self getRectForMenu];
        [menuController setTargetRect:rect inView:self];
        [menuController update];
        [menuController setMenuVisible:YES animated:YES];
    });
}

- (void)correctSpelling:(UIMenuController*)sender {
    NSRange replacementRange = _correctionRange;
    
    if (replacementRange.location==NSNotFound || replacementRange.length==0) {
        replacementRange = [_textView characterRangeAtIndex:_selectedRange.location];
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

- (CGRect)getRectForMenu {
    CGRect rect = [self.textView convertRect:_textView.caretView.frame toView:self];
    if (_selectedRange.location != NSNotFound && _selectedRange.length > 0) {
        rect = (_textView.selectionView!=nil)?[self.textView convertRect:_textView.selectionView.frame toView:self]:[self.textView convertRect:[_textView firstRectForRange:_selectedRange] toView:self];
    }else if (_textView.editing && _correctionRange.location != NSNotFound && _correctionRange.length > 0) {
        rect = [_textView firstRectForRange:_correctionRange];
    }
    return rect;
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    if (_correctionRange.length>0 || _textView.showCorrectinMenu) {
        if ([NSStringFromSelector(action) hasPrefix:@"spellCheckMenu"]) {
            return YES;
        }
        return NO;
    }
    if (action==@selector(cut:)) {
        return (_selectedRange.length>0 && _textView.isEditing);
    } else if (action==@selector(copy:)) {
        return ((_selectedRange.length>0));
    } else if ((action == @selector(select:) || action == @selector(selectAll:))) {
        return (_selectedRange.length==0 && [self hasText]);
    } else if (action == @selector(paste:)) {
        return (_textView.isEditing && [[UIPasteboard generalPasteboard] containsPasteboardTypes:[NSArray arrayWithObjects:@"public.text", @"public.utf8-plain-text", nil]]);
    } else if (action == @selector(delete:)) {
        return NO;
    }
    return [super canPerformAction:action withSender:sender];
}

- (void)cut:(id)sender {
    if (_selectedRange.length) {
        NSString *string = [_text substringWithRange:_selectedRange];
        [[UIPasteboard generalPasteboard] setValue:string forPasteboardType:@"public.utf8-plain-text"];
        [self deleteBackward];
    }
}

- (void)copy:(id)sender {
    if (_selectedRange.length > 0) {
        NSString *string = [_text substringWithRange:_selectedRange];
        [[UIPasteboard generalPasteboard] setValue:string forPasteboardType:@"public.utf8-plain-text"];
    }
}

- (void)delete:(id)sender {
    if (_selectedRange.length) {
        [self deleteBackward];
    }
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
    NSRange outRange = [_textView characterRangeAtIndex:_selectedRange.location];
    self.selectedRange = outRange;
    [self performSelector:@selector(showMenu) withObject:nil afterDelay:0.2];

}

- (void)selectAll:(id)sender {
    _selectedRange = NSMakeRange(0, _text.length);
    [self performSelector:@selector(showMenu) withObject:nil afterDelay:0.2];
}

#pragma mark Custom Keyboard
- (UIView *)inputView{
    if (!_editable) {
        return [[UIView alloc]initWithFrame:CGRectZero];
    }
    if (_activeKeyboardType == KEYBOARD_TYPE_DEFAULT) {
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

- (void)toggleKeyboard{
    [self resignFirstResponder];
    _activeKeyboardType = !_activeKeyboardType;
    [self becomeFirstResponder];
}

- (void)showKeyboard:(KEYBOARD_TYPE)kbType{
    [self resignFirstResponder];
    if (_activeKeyboardType == kbType) {
        _activeKeyboardType = KEYBOARD_TYPE_DEFAULT;
        return;
    }
    _activeKeyboardType = kbType;
    [self becomeFirstResponder];
}

- (void)reflectIconForActionChange{
    if (styleBaseView) {
        UIButton *boldBtn = (UIButton *)[styleBaseView.subviews objectAtIndex:0];
        BOOL isToApply = (curSetTextFormat!=TEXT_FORMAT_NOT_SET)?curSetTextFormat&TEXT_BOLD:_curTextStyle&TEXT_BOLD;
        [boldBtn setImage:[UIImage imageNamed:(isToApply)?@"bold-icon-hover":@"bold-icon"] forState:UIControlStateNormal];
        
        UIButton *italicBtn = (UIButton *)[styleBaseView.subviews objectAtIndex:1];
        isToApply = (curSetTextFormat!=TEXT_FORMAT_NOT_SET)?curSetTextFormat&TEXT_ITALIC:_curTextStyle&TEXT_ITALIC;
        [italicBtn setImage:[UIImage imageNamed:(isToApply)?@"italic-icon-hover":@"italic-icon"] forState:UIControlStateNormal];
        
        UIButton *underline = (UIButton *)[styleBaseView.subviews objectAtIndex:2];
        isToApply = (curSetTextFormat!=TEXT_FORMAT_NOT_SET)?curSetTextFormat&TEXT_UNDERLINE:_curTextStyle&TEXT_UNDERLINE;
        [underline setImage:[UIImage imageNamed:(isToApply)?@"underline-icon-hover":@"underline-icon"] forState:UIControlStateNormal];
        
        UIButton *strikethrough = (UIButton *)[styleBaseView.subviews objectAtIndex:3];
        isToApply = (curSetTextFormat!=TEXT_FORMAT_NOT_SET)?curSetTextFormat&TEXT_STRIKE_THROUGH:_curTextStyle&TEXT_STRIKE_THROUGH;
        [strikethrough setImage:[UIImage imageNamed:(isToApply)?@"strike-icon-hover":@"strike-icon"] forState:UIControlStateNormal];
        
        UIButton *highlight = (UIButton *)[styleBaseView.subviews objectAtIndex:4];
        isToApply = (curSetTextFormat!=TEXT_FORMAT_NOT_SET)?curSetTextFormat&TEXT_HIGHLIGHT:_curTextStyle&TEXT_HIGHLIGHT;
        [highlight setImage:[UIImage imageNamed:(isToApply)?@"highlight-icon-hover":@"highlight-icon"] forState:UIControlStateNormal];
        
        UIButton *bullet = (UIButton *)[styleBaseView.subviews objectAtIndex:5];
        isToApply = _paragraphs.current_paragraph.style == PARAGRAPH_BULLET;
        [bullet setImage:[UIImage imageNamed:(isToApply)?@"bullet-hover":@"bullet"] forState:UIControlStateNormal];
        
        UIButton *numbering = (UIButton *)[styleBaseView.subviews objectAtIndex:6];
        isToApply = _paragraphs.current_paragraph.style == PARAGRAPH_NUMBERING;
        [numbering setImage:[UIImage imageNamed:(isToApply)?@"numbering-hover":@"numbering"] forState:UIControlStateNormal];
    }
}

#pragma mark UIResponder
- (BOOL)canBecomeFirstResponder
{
    if (_editable && [self.textViewDelegate respondsToSelector:@selector(p2msTextViewShouldBeginEditing:)]) {
            return [self.textViewDelegate p2msTextViewShouldBeginEditing:self];
    }
    return YES;
}

- (BOOL)becomeFirstResponder {
    BOOL val = [super becomeFirstResponder];
    if (val && _editable) {
        self.textView.editing = YES;
        if ([self.textViewDelegate respondsToSelector:@selector(p2msTextViewDidBeginEditing:)]) {
            [self.textViewDelegate p2msTextViewDidBeginEditing:self];
        }
    }
    return val;
}

- (BOOL)canResignFirstResponder{
    if ([self.textViewDelegate respondsToSelector:@selector(p2msTextViewShouldEndEditing:)]) {
        return [self.textViewDelegate p2msTextViewShouldEndEditing:self];
    }
    return YES;
}

- (BOOL)resignFirstResponder {
    if (_editable) {
        self.textView.editing = NO;
        if ([self.textViewDelegate respondsToSelector:@selector(p2msTextViewDidEndEditing:)]) {
            [self.textViewDelegate p2msTextViewDidEndEditing:self];
        }
        [self.textView updateSelection];
    }
	return [super resignFirstResponder];
}

#pragma mark Orientation Changed
- (void)orientationChanged:(NSNotification *)notification{
    if (_editable && styleBaseView) {
        for (UIView *view in styleBaseView.subviews) {
            [view removeFromSuperview];
        }
        [self performSelector:@selector(populateCustomInputView) withObject:nil afterDelay:0.01f];
    }
    double delayInSeconds = 0.01f;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        if (![[UIMenuController sharedMenuController]isMenuVisible]) {
            self.correctionRange = NSMakeRange(NSNotFound, 0);
        }
        [_textView refreshLayout];
        [self adjustScrollView];
    });
}

#pragma mark LinkViewDelegate
- (void)linkViewDidCancel:(P2MSLinkViewController *)viewController{
    [((UIViewController *)self.textViewDelegate) dismissModalViewControllerAnimated:YES];
}

- (void)linkViewDidClose:(P2MSLinkViewController *)viewController{
    _markedRange = NSMakeRange(NSNotFound, 0);
    NSString *linkName = viewController.linkTitle;
    NSString *linkURL = viewController.linkURL;
    NSRange linkRange = viewController.linkRange;
    if (linkURL && linkURL.length) {
        if (!linkName.length) {
            linkName = linkURL;
        }
        if (linkRange.location == NSNotFound) {
            linkRange = NSMakeRange(_selectedRange.location, linkName.length);
            [self insertText:linkName];
        }
        
        P2MSLink *link = [[P2MSLink alloc]init];
        link.styleRange = linkRange;
        link.linkURL = linkURL;
        [links addObject:link];
        
        [self applyFormat:TEXT_LINK toRange:linkRange];
        [_textView refreshView];
        
        if ([_textViewDelegate respondsToSelector:@selector(p2msTextViewLinkAdded:andLink:)]) {
            [_textViewDelegate p2msTextViewLinkAdded:self andLink:link];
        }
    }
    [((UIViewController *)self.textViewDelegate) dismissModalViewControllerAnimated:YES];
}

#pragma mark HTML Related

- (NSString *)exportHTMLString{
//    NSMutableString *finalString = [NSMutableString string];
//    NSMutableDictionary *attribs = [self getStyleAttributes];
//    NSMutableArray *attrArr = [attribs objectForKey:@"attributes"];
//    NSMutableArray *paragraphs = [attribs objectForKey:@"paragraphs"];
//    NSMutableArray *hyperLinks = [attribs objectForKey:@"links"];
//    
//    [hyperLinks sortUsingComparator:globalSortBlock];
//    
//    NSMutableArray *intersectFormats = [NSMutableArray array];
//    NSMutableSet *arrToRemove = [NSMutableSet set];
//    
//    NSRange intersectRange;
//    for (P2MSTextAttribute *txtFmt in attrArr) {
//        NSUInteger finalLoc = txtFmt.styleRange.location + txtFmt.styleRange.length;
//        
//        NSUInteger curLoc = txtFmt.styleRange.location;
//        for (P2MSLink *curLink in hyperLinks){
//            intersectRange = NSIntersectionRange(txtFmt.styleRange, curLink.styleRange);
//            if (intersectRange.length == curLink.styleRange.length && curLink.styleRange.length <=  txtFmt.styleRange.length)break;
//            if (intersectRange.length){
//                [arrToRemove addObject:txtFmt];
//                if (curLoc < intersectRange.location) {
//                    P2MSTextAttribute *fmtToAdd = [[P2MSTextAttribute alloc]init];
//                    fmtToAdd.styleRange = NSMakeRange(curLoc, intersectRange.location-curLoc);;
//                    fmtToAdd.txtAttrib = txtFmt.txtAttrib;
//                    [intersectFormats addObject:fmtToAdd];
//                }
//                P2MSTextAttribute *fmtToAdd = [[P2MSTextAttribute alloc]init];
//                fmtToAdd.styleRange = intersectRange;
//                fmtToAdd.txtAttrib = txtFmt.txtAttrib;
//                [intersectFormats addObject:fmtToAdd];
//                curLoc = intersectRange.location + intersectRange.length;
//            }
//        }
//        if (curLoc > txtFmt.styleRange.location && curLoc < finalLoc) {
//            P2MSTextAttribute *fmtToAdd = [[P2MSTextAttribute alloc]init];
//            fmtToAdd.styleRange = NSMakeRange(curLoc, finalLoc - curLoc);
//            fmtToAdd.txtAttrib = txtFmt.txtAttrib;
//            [intersectFormats addObject:fmtToAdd];
//        }
//    }
//    
//    for (P2MSTextAttribute *txtFormat in arrToRemove) {
//        [attrArr removeObject:txtFormat];
//    }
//    for (P2MSTextAttribute *txtFmt in intersectFormats) {
//        [attrArr addObject:txtFmt];
//    }
//    
//    [attrArr sortUsingComparator:globalSortBlock];
//    
//    PARAGRAPH_STYLE prevParaFormat = PARAGRAPH_NORMAL;
//    NSRange prevParaRange = NSMakeRange(NSNotFound, 0);
//    NSMutableString *paraString = [NSMutableString string];
//    NSRange prevLinkRange = NSMakeRange(NSNotFound, 0);
//    NSRange linkIntersectRange;
//    
//    BOOL isPrevOpen = NO;
//    for (P2MSTextAttribute *txtFmt in attrArr) {
//        NSString *curPartString = [_text substringWithRange:txtFmt.styleRange];
//        BOOL isEndWithNewLine = [curPartString hasSuffix:@"\n"];
//        NSMutableString *curTextStr = [NSMutableString string];
//        NSRange insideLinkRange = NSMakeRange(NSNotFound, 0);
//        NSUInteger finalLoc = txtFmt.styleRange.location;
//        P2MSLink *curLinkToThink = nil;
//        for (P2MSLink *curLink in hyperLinks) {
//            if ((linkIntersectRange = NSIntersectionRange(curLink.styleRange, txtFmt.styleRange)).length) {
//                insideLinkRange = curLink.styleRange;
//                if (linkIntersectRange.length == insideLinkRange.length && insideLinkRange.length <= txtFmt.styleRange.length){
//                    NSRange firstPart = NSMakeRange(finalLoc, linkIntersectRange.location-finalLoc);
//                    NSRange secondPart = linkIntersectRange;
//                    NSString *firstStr = [_text substringWithRange:firstPart];
//                    NSString *secondStr = [_text substringWithRange:secondPart];
//                    [curTextStr appendFormat:@"%@<a href=\"%@\">%@</a>",[firstStr gtm_stringByEscapingForHTML], curLink.linkURL, [secondStr gtm_stringByEscapingForHTML]];
//                    finalLoc = linkIntersectRange.location + linkIntersectRange.length;
//                }else{
//                    curLinkToThink = curLink;
//                }
//            }
//        }
//        
//        [curTextStr appendString:[_text substringWithRange:NSMakeRange(finalLoc, txtFmt.styleRange.location+txtFmt.styleRange.length-finalLoc)]];
//        NSString *textFormat = [self APPLYHTMLTEXTFORMAT:txtFmt.txtAttrib toString:curTextStr];
//        
//        if (prevLinkRange.location != NSNotFound) {
//            if (!curLinkToThink) {//no more link and add closing tag
//                textFormat = [NSString stringWithFormat:@"</a>%@", textFormat];
//                prevLinkRange = NSMakeRange(NSNotFound, 0);
//            }else if (curLinkToThink.styleRange.location != prevLinkRange.location){
//                textFormat = [NSString stringWithFormat:@"%@</a><a href=\"%@\">", textFormat, curLinkToThink.linkURL];
//                prevLinkRange = curLinkToThink.styleRange;
//            }
//        }else if (curLinkToThink){
//            textFormat = [NSString stringWithFormat:@"<a href=\"%@\">%@", curLinkToThink.linkURL, textFormat];
//            prevLinkRange = insideLinkRange;
//        }
//        
//        PARAGRAPH_STYLE insideParaFormat = PARAGRAPH_NORMAL;
//        NSRange insideParaRange = NSMakeRange(NSNotFound, 0);
        
//        for (P2MSParagraphStyle *paraFmt in paragraphs) {
//            if (NSIntersectionRange(paraFmt.styleRange, txtFmt.styleRange).length) {
//                insideParaFormat = paraFmt.paraStyle;
//                insideParaRange = paraFmt.styleRange;break;
//            }
//        }
//        
//        if (prevParaRange.location != NSNotFound) {
//            if (prevParaFormat == insideParaFormat) {
//                if (prevParaFormat == PARAGRAPH_BULLET || prevParaFormat == PARAGRAPH_NUMBERING) {
//                    if (isEndWithNewLine){
//                        [paraString appendFormat:(isPrevOpen)?@"%@</li>":@"<li>%@</li>", textFormat];
//                        isPrevOpen = NO;
//                    }else{
//                        if (isPrevOpen) {
//                            [paraString appendString:textFormat];
//                        }else{
//                            [paraString appendFormat:@"<li>%@", textFormat];
//                            isPrevOpen = YES;
//                        }
//                    }
//                }else
//                    [paraString appendString:textFormat];
//            }else{
//                if (isPrevOpen){
//                    [paraString appendString:@"</li>"];
//                    isPrevOpen = NO;
//                }
//                [finalString appendString:[self APPLY_PARAGRAPHFORMAT:prevParaFormat toString:paraString]];
//                if (insideParaFormat != PARAGRAPH_NORMAL) {
//                    prevParaFormat = insideParaFormat;
//                    prevParaRange = insideParaRange;
//                    if (prevParaFormat == PARAGRAPH_BULLET || prevParaFormat == PARAGRAPH_NUMBERING) {
//                        if (isEndWithNewLine) {
//                            paraString = [NSMutableString stringWithFormat:@"<li>%@</li>", textFormat];
//                            isPrevOpen = NO;
//                        }else{
//                            paraString = [NSMutableString stringWithFormat:@"<li>%@", textFormat];
//                            isPrevOpen = YES;
//                        }
//                    }else
//                        paraString = [NSMutableString stringWithString:textFormat];
//                }else{
//                    [finalString appendString:textFormat];
//                    paraString = [NSMutableString string];
//                    prevParaFormat = PARAGRAPH_NORMAL;
//                    prevParaRange = NSMakeRange(NSNotFound, 0);
//                }
//            }
//        }else if(insideParaFormat != PARAGRAPH_NORMAL && insideParaRange.location != NSNotFound){
//            if (insideParaFormat == PARAGRAPH_BULLET || insideParaFormat == PARAGRAPH_NUMBERING) {
//                if (isEndWithNewLine) {
//                    [paraString appendFormat:@"<li>%@</li>", textFormat];
//                    isPrevOpen = NO;
//                }else{
//                    [paraString appendFormat:@"<li>%@", textFormat];
//                    isPrevOpen = YES;
//                }
//            }else
//                paraString = [NSMutableString stringWithString:textFormat];
//            prevParaRange = insideParaRange;
//            prevParaFormat = insideParaFormat;
//        }else
//            [finalString appendString:textFormat];
//    }
//    if (prevLinkRange.location != NSNotFound)[finalString appendString:@"</a>"];
//    if (isPrevOpen) { [paraString appendString:@"</li>"];isPrevOpen = NO; }
//    if (paraString.length) {
//        [finalString appendString:[self APPLY_PARAGRAPHFORMAT:prevParaFormat toString:paraString]];
//    }
//    //    [finalString replaceOccurrencesOfString:@"\n" withString:@"<br>" options:NSLiteralSearch range:NSMakeRange(0, finalString.length)];
//    return finalString;
    return nil;
}

- (NSString *)APPLYHTMLTEXTFORMAT:(TEXT_ATTRIBUTE)txtFmt toString:(NSString *)finalString{
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

- (NSString *)APPLY_PARAGRAPHFORMAT:(PARAGRAPH_STYLE)paraFmt toString:(NSString *)str{
    NSString *finalString = str;
    if (paraFmt == PARAGRAPH_SECTION) {
        finalString =  [NSString stringWithFormat:@"<h3>%@</h3>", finalString];
    }
    if (paraFmt == PARAGRAPH_SUBSECTION) {
        finalString =  [NSString stringWithFormat:@"<h5>%@</h5>", finalString];
    }
    if (paraFmt == PARAGRAPH_BLOCK_QUOTE) {
        finalString =  [NSString stringWithFormat:@"<blockquote>%@</blockquote>", finalString];
    }
    if (paraFmt == PARAGRAPH_BULLET) {
        finalString =  [NSString stringWithFormat:@"<ul>%@</ul>", finalString];
    }
    if (paraFmt == PARAGRAPH_NUMBERING) {
        finalString =  [NSString stringWithFormat:@"<ol>%@</ol>", finalString];
    }
    return finalString;
}

- (void)addNormalParagraphsForString:(NSString *)finalStr withRange:(NSRange)overallRange appendParagraphs:(NSMutableArray **)parasToAdd{
    NSString *leftStr = [finalStr substringWithRange:overallRange];    
    NSUInteger curLocation = 0;
    NSInteger strLength = overallRange.length;
    while (curLocation < strLength) {
        NSRange occurrence = [leftStr rangeOfString:@"\n" options:NSLiteralSearch range:NSMakeRange(curLocation, strLength-curLocation)];
        if (occurrence.length) {
            P2MSParagraph *newParagraph = [[P2MSParagraph alloc]init];
            newParagraph.styleRange = NSMakeRange(curLocation, occurrence.location+1-curLocation);
            newParagraph.style = PARAGRAPH_NORMAL;
            [*parasToAdd addObject:newParagraph];
            curLocation = occurrence.location+1;
        }else{
            P2MSParagraph *newParagraph = [[P2MSParagraph alloc]init];
            newParagraph.styleRange = NSMakeRange(curLocation, strLength-curLocation);
            newParagraph.style = PARAGRAPH_NORMAL;
            [*parasToAdd addObject:newParagraph];
            break;
        }
    }
}

- (void)importHTMLString:(NSString *)htmlString{
//    NSString *newhtmlString = [P2MSTextView addExtraNewLines:htmlString];
    NSArray *htmlNodes = [P2MSHTMLOperation getHTMLNodes:htmlString withParent:nil];
    NSMutableString *finalStr = [NSMutableString string];
    NSUInteger lastIndex = 0, curLength = 0;
    for (P2MSHTMLNode *curNode in htmlNodes) {
        curLength = curNode.content.length;
        curNode.range = NSMakeRange(lastIndex, curLength);
        [finalStr appendString:curNode.content];
        lastIndex += curLength;
    }
    
    NSMutableArray *attrArr = [NSMutableArray array];
    NSMutableArray *paraSet = [NSMutableArray array];
    NSMutableSet *allLinks = [NSMutableSet set];
    
    for (P2MSHTMLNode *curNode in htmlNodes) {
        P2MSHTMLNode *internalNode = curNode;
        [P2MSHTMLOperation convertNode:&internalNode toParaAttributes:&paraSet toAttributes:&attrArr andLinks:&allLinks];
    }
    //add additional paragraphs
    NSInteger textLength = finalStr.length;
    NSInteger initalPos = 0;
    NSMutableArray *parasToAdd = [NSMutableArray array];
    for (P2MSParagraph *curPara in paraSet) {
        if (initalPos < curPara.styleRange.location) {
            //add New paragraph
            NSRange overallRange = NSMakeRange(initalPos, curPara.styleRange.location-initalPos);
            [self addNormalParagraphsForString:finalStr withRange:overallRange appendParagraphs:&parasToAdd];
            initalPos = initalPos + overallRange.length;
        }else{
            initalPos += curPara.styleRange.length;
        }
    }
    if (initalPos < textLength) {
        //add New paragraph
        [self addNormalParagraphsForString:finalStr withRange:NSMakeRange(initalPos, textLength-initalPos) appendParagraphs:&parasToAdd];
    }
    
    for (P2MSParagraph *paragraph_to_test in paraSet) {
        [self addNormalParagraphsForString:finalStr withRange:paragraph_to_test.styleRange appendParagraphs:&parasToAdd];
    }

    [paraSet removeAllObjects];
    
    [curAttributes removeAllObjects];
    [links removeAllObjects];
    [_paragraphs clearAll];
    [parasToAdd sortUsingComparator:globalSortBlock];
    
    _paragraphs.text = finalStr;
    _paragraphs.paragraphs = parasToAdd;
    if (parasToAdd.count) {
        [_paragraphs updateCurrentParagraphForPosition:0];
    }
    
    curActionRange = NSMakeRange(NSNotFound, 0);
    curSetTextFormat = TEXT_FORMAT_NOT_SET;
    _curTextStyle = TEXT_FORMAT_NONE;
    
    curAttributes = attrArr;
    links = allLinks;
    _text = finalStr;
    
    [curAttributes sortUsingComparator:globalSortBlock];
    [self forceReflectFormatForLocationChange:0];
    
    self.markedRange = NSMakeRange(NSNotFound, 0);
    self.selectedRange = NSMakeRange(0, 0);
    [self.textView setContentText:self.text];
    [self adjustScrollView];
}

#pragma mark -
#pragma mark TextView Additional Processings
- (void)processLinkAtRange:(NSRange)range withText:(NSString *)insertText{
    NSUInteger length = insertText.length;
    if (range.length) {
        NSMutableSet *linkToDelete = [NSMutableSet set];
        for (P2MSLink *curLink in links) {
            NSRange intersetRange = NSIntersectionRange(curLink.styleRange, range);
            if (intersetRange.length == curLink.styleRange.length) {
                [linkToDelete addObject:curLink];
            }else if (intersetRange.length){
                if (intersetRange.location > curLink.styleRange.location) {
                    curLink.styleRange = NSMakeRange(curLink.styleRange.location, curLink.styleRange.length-intersetRange.length+length);
                }else{
                    curLink.styleRange = NSMakeRange(range.location, curLink.styleRange.length-intersetRange.length+length);
                }
            }else{
                NSUInteger affectedLoc = range.location + range.length;
                if (affectedLoc <= curLink.styleRange.location) {
                    curLink.styleRange = NSMakeRange(curLink.styleRange.location-range.length+length, curLink.styleRange.length);
                }
            }
        }
        for (P2MSLink *link in linkToDelete) {
            [links removeObject:link];
        }
    }else if(length){
        for (P2MSLink *curLink in links) {
            if (range.location <= curLink.styleRange.location) {
                curLink.styleRange = NSMakeRange(curLink.styleRange.location+length, curLink.styleRange.length);
            }else if(NSLocationInRange(range.location, curLink.styleRange)){
                curLink.styleRange = NSMakeRange(curLink.styleRange.location, curLink.styleRange.length+length);
            }
        }
    }
}




@end
