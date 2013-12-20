//
//  P2MSContentView.m
//  P2MSTextView
//
//  Created by PYAE PHYO MYINT SOE on 18/5/13.
//  Copyright (c) 2013 Pyae Phyo MS. All rights reserved.
//
#import "P2MSContentView.h"
#import <QuartzCore/QuartzCore.h>
#import <CoreText/CoreText.h>
#import "P2MSTextView.h"
#import "P2MSDocument.h"
#import "P2MSConstants.h"

#define STRIKETHROUGH_KEY @"p2msTextView_strike_through_key"
#define HIGHLIGHT_KEY @"p2msTextView_highlight_key"

@interface P2MSContentView(){
    CGFloat sectionFontSize, subSectionFontSize;
    NSString *fontName, *boldFontName, *italicFontName, *boldItalicFontName;
    UIColor *selectionColor, *spellingColor, *highlightColor;
}
@property (nonatomic) NSDictionary *attributes;

@end

@implementation P2MSContentView{
    CTFramesetterRef _framesetter;
    CTFrameRef _ctFrame;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.userInteractionEnabled = NO;
        _contentText = @"";
        selectionColor = [P2MSConstants selectionColor];
        spellingColor = [P2MSConstants spellingColor];
        highlightColor = [P2MSConstants highlightColor];
        _caretView = [[P2MSCaretView alloc] initWithFrame:CGRectZero];
        [self addSubview:_caretView];
        _caretView.hidden = YES;
        [self setFontName:@"HelveticaNeue" withSize:15];
        self.layer.geometryFlipped = YES;
        self.backgroundColor = [UIColor clearColor];
        self.contentMode = UIViewContentModeRedraw;//change	to proper content modes if you want to do animation
        isDrawing = NO;
    }
    return self;
}


- (void)setFontSize:(CGFloat)fontSize{
    if (fontSize != _fontSize) {
        _fontSize = fontSize;
        subSectionFontSize = _fontSize+8;
        sectionFontSize = _fontSize+17;
        CTFontRef ctFont = CTFontCreateWithName((__bridge CFStringRef) fontName, _fontSize, NULL);
        self.attributes = @{ (NSString *)kCTFontAttributeName : (__bridge id)ctFont };
        CFRelease(ctFont);
        [self textChanged];
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [self textChanged];
}

- (void)setFontName:(NSString *)newFontName withSize:(CGFloat) newFontSize
{
    if (newFontSize != _fontSize || ![newFontName isEqualToString:fontName]) {
        fontName = newFontName;
        boldFontName = [NSString stringWithFormat:@"%@-Bold", fontName];
        italicFontName = [NSString stringWithFormat:@"%@-Italic", fontName];
        boldItalicFontName = [NSString stringWithFormat:@"%@-BoldItalic", fontName];
        _fontSize = newFontSize;
        subSectionFontSize = _fontSize+8;
        sectionFontSize = _fontSize+17;
        CTFontRef ctFont = CTFontCreateWithName((__bridge CFStringRef) fontName, _fontSize, NULL);
        self.attributes = @{ (NSString *)kCTFontAttributeName : (__bridge id)ctFont };
        CFRelease(ctFont);
//        [self textChanged];
    }
}

- (void)setContentText:(NSString *)text
{
    _contentText = [text copy];
    [self textChanged];
}

- (void)setSelectedTextRange:(NSRange)selectedTextRange{
    _selectedTextRange = NSMakeRange(selectedTextRange.location == (NSNotFound)? NSNotFound : MAX(0, selectedTextRange.location), selectedTextRange.length);
    [self selectionChanged];
}

- (void)drawFitTextHighLightForRange:(NSRange)selectionRange withColor:(UIColor *)color
{
    if (selectionRange.length == 0 || selectionRange.location == NSNotFound)return;
    [color setFill];
    CFArrayRef lines = CTFrameGetLines(_ctFrame);
    CFIndex linesCount = CFArrayGetCount(lines);
    for (CFIndex linesIndex = 0; linesIndex < linesCount; linesIndex++) {
        CTLineRef line = (CTLineRef) CFArrayGetValueAtIndex(lines, linesIndex);
        CFRange lineRange = CTLineGetStringRange(line);
        NSRange range = NSMakeRange(lineRange.location, lineRange.length);
        NSRange intersection = NSIntersectionRange(range, selectionRange);
        if (intersection.length > 0) {
            CGFloat xStart = CTLineGetOffsetForStringIndex(line, intersection.location, NULL);
            CGFloat xEnd = CTLineGetOffsetForStringIndex(line, intersection.location + intersection.length, NULL);
            CGPoint origin = CGPointZero;
            CTFrameGetLineOrigins(_ctFrame, CFRangeMake(linesIndex, 1), &origin);
            CGFloat ascent = 0, descent = 0;
            CTLineGetTypographicBounds(line, &ascent, &descent, NULL);
            CGRect selectionRect = CGRectMake(xStart+origin.x, origin.y - descent, xEnd - xStart, ascent + descent);
            UIRectFill(selectionRect);
        }
    }
}

- (void)drawFitWidthHighLightForRange:(NSRange)selectionRange withColor:(UIColor *)color
{
    if (selectionRange.length == 0 || selectionRange.location == NSNotFound)return;
    [color setFill];
    CFArrayRef lines = CTFrameGetLines(_ctFrame);
    CFIndex linesCount = CFArrayGetCount(lines);
    NSMutableArray *tempRects = [[NSMutableArray alloc] init];
    for (CFIndex linesIndex = 0; linesIndex < linesCount; linesIndex++) {
        CTLineRef line = (CTLineRef) CFArrayGetValueAtIndex(lines, linesIndex);
        CFRange lineRange = CTLineGetStringRange(line);
        NSRange range = NSMakeRange(lineRange.location, lineRange.length);
        NSRange intersection = NSIntersectionRange(range, selectionRange);
        if (intersection.length > 0) {
            CGFloat xStart = CTLineGetOffsetForStringIndex(line, intersection.location, NULL);
            CGFloat xEnd = CTLineGetOffsetForStringIndex(line, intersection.location + intersection.length, NULL);

            CGPoint origin = CGPointZero;
            CTFrameGetLineOrigins(_ctFrame, CFRangeMake(linesIndex, 1), &origin);
            CGFloat ascent = 0, descent = 0;
            CTLineGetTypographicBounds(line, &ascent, &descent, NULL);
            BOOL isStartSelection = selectionRange.location == intersection.location;
            
            if ([_contentText characterAtIndex:intersection.location + intersection.length-1] == '\n') {
                xEnd = self.bounds.size.width;
            }
            CGRect selectionRect = CGRectMake(xStart + (origin.x*isStartSelection), origin.y - descent, xEnd - xStart + (origin.x* !isStartSelection), ascent + descent);
            [tempRects addObject:[NSValue valueWithCGRect:selectionRect]];
        }
    }
    [self drawPath:tempRects];
}

- (void)drawPath:(NSArray *)paths{
    if (!paths.count) return;
    CGRect firstRect = [[paths lastObject]CGRectValue];
    CGRect lastRect = [[paths objectAtIndex:0]CGRectValue];
    if (paths.count>1) {
        lastRect.size.width = self.bounds.size.width-lastRect.origin.x;
    }
    CGMutablePathRef pathToDraw = CGPathCreateMutable();
    CGPathAddRect(pathToDraw, NULL, firstRect);
    CGPathAddRect(pathToDraw, NULL, lastRect);
    if (paths.count > 1) {
        CGRect pathRect;
        pathRect.origin.y = firstRect.origin.y + firstRect.size.height;
        pathRect.size.height = MAX(0.0f, lastRect.origin.y-pathRect.origin.y);
        if (paths.count == 2) {
            pathRect.origin.x = MIN(CGRectGetMinX(firstRect), CGRectGetMinX(lastRect));
            pathRect.size.width = pathRect.origin.x+MIN(CGRectGetMaxX(firstRect), CGRectGetMaxX(lastRect));
        }else{
            pathRect.origin.x = 0.0f;
            pathRect.size.width = self.bounds.size.width;
        }
        CGPathAddRect(pathToDraw, NULL, pathRect);
    }
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextAddPath(ctx, pathToDraw);
    CGContextFillPath(ctx);
    CGPathRelease(pathToDraw);
}

- (void)setEditing:(BOOL)editing
{
    _editing = editing;
    [self selectionChanged];
}

- (P2MSSelectionView *)selectionView{
    return selectionView;
}

- (void)responseToLongPress:(UILongPressGestureRecognizer*)gesture{
    if (gesture.state==UIGestureRecognizerStateBegan || gesture.state == UIGestureRecognizerStateChanged) {
        CGPoint point = [gesture locationInView:self];
        _correctionRange = NSMakeRange(NSNotFound, 0);
        BOOL _selection = (selectionView!=nil);
        if (!_selection && !self.caretView.hidden) {
            [self.caretView removeAnimations];
        }
        
        textWindow = [P2MSTextWindow getTextWindow:textWindow];
        textWindow.windowType = (_selection)?P2MS_TEXT_MAGNIFY:P2MS_TEXT_LOUPE;
        NSInteger index = [self closestIndexToPoint:point];
        if (_selection) {
            if (gesture.state == UIGestureRecognizerStateBegan) {
                selectionView.isSelectionLeft = !(index > (_selectedTextRange.location+(_selectedTextRange.length/2)));
            }
            CGRect rect = CGRectZero;
            if (selectionView.isSelectionLeft) {
                NSInteger begin = MAX(0, index);
                begin = MIN(_selectedTextRange.location+_selectedTextRange.length-1, begin);
                if (_contentText.length > begin+1 && [_contentText characterAtIndex:begin] == '\n') {
                    begin++;
                }
                
                NSInteger end = _selectedTextRange.location + _selectedTextRange.length;
                end = MIN(_contentText.length, end-begin);
                
                self.selectedTextRange = NSMakeRange(begin, end);
                index = _selectedTextRange.location;
            } else {
                NSInteger length = MIN(index-_selectedTextRange.location, _contentText.length-_selectedTextRange.location);
                length = MAX(1, length);
                
                self.selectedTextRange = NSMakeRange(_selectedTextRange.location, length);
                index = (_selectedTextRange.location+_selectedTextRange.length);
            }
            rect = [self caretRectForIndex:index];
            if (gesture.state == UIGestureRecognizerStateBegan) {
                [textWindow showTextWindowFromView:self rect:[self convertRect:rect toView:textWindow]];
            } else {
                [textWindow renderContentView:self fromRect:[self convertRect:rect toView:textWindow]];
            }
        } else {
            self.selectedTextRange = NSMakeRange(index, 0);
            CGPoint location = [gesture locationInView:textWindow];
            CGRect rect = CGRectMake(location.x, location.y, _caretView.bounds.size.width, _caretView.bounds.size.height);
            if (gesture.state == UIGestureRecognizerStateBegan) {
                [textWindow showTextWindowFromView:self rect:rect];
            } else {
                [textWindow renderContentView:self fromRect:rect];
            }
        }
    } else {
        if (!self.caretView.hidden) {
            [self.caretView delayBlink];
        }
        
        if (textWindow!=nil) {
            [textWindow hideTextWindow:YES];
            textWindow=nil;
        }
    }
}

- (void)refreshLayout{
    if (!self.editing) {
        _caretView.hidden = YES;
        return;
    }
    if (self.selectedTextRange.length == 0) {
        self.caretView.frame = [self caretRectForIndex:self.selectedTextRange.location];
        _caretView.hidden = NO;
        [self setNeedsDisplay];
        [self.caretView delayBlink];
    }
    else {
        if (_caretView && !_caretView.hidden) {
            _caretView.hidden = YES;
        }
        
        if (_selectedTextRange.length > 0) {
            [self showSelectionView];
        }
        [self setNeedsDisplay];
    }
}

- (void)refreshView{
    [self textChanged];
    [self refreshLayout];
}

- (void)selectionChanged
{
    _parentView.showingCorrectionMenu = NO;
    if (!self.editing) {
        _caretView.hidden = YES;
    }
    if (self.selectedTextRange.length == 0) {
        self.caretView.frame = [self caretRectForIndex:self.selectedTextRange.location];
        if (selectionView != nil) {
            [selectionView removeFromSuperview];
            selectionView = nil;
        }
        if (self.caretView.superview == nil) {
            [self addSubview:self.caretView];
        }
        _caretView.hidden = !_editing;
        [self setNeedsDisplay];
        [self.caretView delayBlink];
        _parentView.longPressGR.minimumPressDuration = 0.5f;
    }
    else {
        _parentView.longPressGR.minimumPressDuration = 0.0f;
        if (_caretView && !_caretView.hidden) {
            _caretView.hidden = YES;
        }
        if (selectionView==nil) {
            selectionView = [[P2MSSelectionView alloc] initWithFrame:self.bounds];
            [self addSubview:selectionView];
        }
        [self showSelectionView];
        [self setNeedsDisplay];
    }
}

- (void)showSelectionView{
    CFArrayRef lines = CTFrameGetLines(_ctFrame);
    CFIndex linesCount = CFArrayGetCount(lines);
    
    // Regular case, caret somewhere within our text content range.
    CGPoint *origins = (CGPoint*)malloc(linesCount * sizeof(CGPoint));
    CTFrameGetLineOrigins(_ctFrame, CFRangeMake(0, linesCount), origins);

    NSUInteger textLength = _contentText.length;
    NSUInteger beginIndex = _selectedTextRange.location, endIndex = _selectedTextRange.location+_selectedTextRange.length;
    CGRect beginRect = CGRectZero, endRect = CGRectZero;
    for (int linesIndex = 0; linesIndex < linesCount; linesIndex++) {
        CTLineRef line = (CTLineRef)CFArrayGetValueAtIndex(lines, linesIndex);
        CFRange range = CTLineGetStringRange(line);
        if (beginIndex >= range.location && beginIndex < range.location+range.length) {
            CGFloat ascent, descent, xPos;
            xPos = CTLineGetOffsetForStringIndex(line, beginIndex, NULL);
            CTLineGetTypographicBounds(line, &ascent, &descent, NULL);
            CGPoint origin = origins[linesIndex];
            beginRect = CGRectMake(xPos+origin.x,  origin.y - descent, 3, descent + ascent);
        }
        
        if (endIndex >= range.location && endIndex <= range.location+range.length) {
            CGFloat ascent, descent, xPos;
            xPos = CTLineGetOffsetForStringIndex(line, endIndex, NULL);
            CTLineGetTypographicBounds(line, &ascent, &descent, NULL);
            CGPoint origin = origins[linesIndex];
            if ([_contentText characterAtIndex:endIndex-1] == '\n') {
                xPos = self.bounds.size.width-3;
                if (endIndex != textLength) {
                    origin.y += descent + ascent;
                }
            }
            endRect = CGRectMake(xPos+origin.x,  origin.y - descent, 3, descent + ascent);
        }   
    }
    [selectionView beginCaretForRect:beginRect endCaretForRect:endRect];
    free(origins);
}

- (void)applyBlockquoteToRange:(NSRange)range{
    NSDictionary *format = [P2MSContentView getParagraphFormatWithLeftPadding:26.0f];
    [_attributedString addAttributes:format range:range];
}

- (void)applyBulletToRange:(NSRange)range{
    NSDictionary *format = [P2MSContentView getParagraphFormatWithLeftPadding:25.0f];
    [_attributedString addAttributes:format range:range];
}

- (void)applyNumberingToRange:(NSRange)range{
    NSDictionary *format = [P2MSContentView getParagraphFormatWithLeftPadding:28.0f];
    [_attributedString addAttributes:format range:range];
}

+ (NSDictionary *)getParagraphFormatWithLeftPadding:(CGFloat)leftPadding{
    CTTextAlignment alignment = kCTLeftTextAlignment;
    CGFloat paragraphSpacing = 2.0;
    CGFloat paragraphSpacingBefore = 2.0;
    CGFloat firstLineHeadIndent = leftPadding;//15.0;
    CGFloat headIndent = leftPadding;
    
    CGFloat firstTabStop = 15.0; // width of your indent
    CGFloat lineSpacing = 0.45;
    
    CTTextTabRef tabArray[] = { CTTextTabCreate(0, firstTabStop, NULL) };
    
    CFArrayRef tabStops = CFArrayCreate( kCFAllocatorDefault, (const void**) tabArray, 1, &kCFTypeArrayCallBacks );
    CFRelease(tabArray[0]);
    
    CTParagraphStyleSetting altSettings[] =
    {
        { kCTParagraphStyleSpecifierLineSpacing, sizeof(CGFloat), &lineSpacing},
        { kCTParagraphStyleSpecifierAlignment, sizeof(CTTextAlignment), &alignment},
        { kCTParagraphStyleSpecifierFirstLineHeadIndent, sizeof(CGFloat), &firstLineHeadIndent},
        { kCTParagraphStyleSpecifierHeadIndent, sizeof(CGFloat), &headIndent},
        { kCTParagraphStyleSpecifierTabStops, sizeof(CFArrayRef), &tabStops},
        { kCTParagraphStyleSpecifierParagraphSpacing, sizeof(CGFloat), &paragraphSpacing},
        { kCTParagraphStyleSpecifierParagraphSpacingBefore, sizeof(CGFloat), &paragraphSpacingBefore}
    };
    
    CTParagraphStyleRef style;
    style = CTParagraphStyleCreate( altSettings, sizeof(altSettings) / sizeof(CTParagraphStyleSetting) );
    
    if ( style == NULL )
    {
        NSLog(@"*** Unable To Create CTParagraphStyle in apply paragraph formatting" );
        return nil;
    }
    NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:(__bridge NSObject*)style,(NSString*) kCTParagraphStyleAttributeName, nil];
    CFRelease(tabStops);
    CFRelease(style);
    return dict;
}

- (void)textChanged{
    if (isDrawing) {
        return;
    }
    isDrawing = YES;
    if ([[UIMenuController sharedMenuController] isMenuVisible]) {
        [[UIMenuController sharedMenuController] setMenuVisible:NO animated:NO];
    }
    _attributedString = nil;
    _attributedString = [[NSMutableAttributedString alloc] initWithString:self.contentText attributes:self.attributes];
    NSMutableDictionary *attribs = [_parentView getAttributes];
    NSMutableArray *attrArr = [attribs objectForKey:@"attributes"];
    NSMutableArray *paragraphs = [attribs objectForKey:@"paragraphs"];
    NSMutableArray *links = [attribs objectForKey:@"links"];
    
    for (P2MSLink *link in links) {
        [_attributedString addAttribute:(NSString *)kCTForegroundColorAttributeName value:(id)[[UIColor blueColor] CGColor] range:link.formatRange];
    }
    
    for (P2MSParagraph *curPara in paragraphs) {
        NSRange paraRange = curPara.formatRange;
        int paraFormat = curPara.paraFormat;
        if (paraFormat == TEXT_PARAGRAPH)continue;
        switch (paraFormat) {
            case TEXT_SECTION:{
                CTFontRef ctFont = CTFontCreateWithName((__bridge CFStringRef)fontName, sectionFontSize, NULL);
                [_attributedString addAttribute:(NSString *)kCTFontAttributeName value:(__bridge id)ctFont range:paraRange];
                CFRelease(ctFont);
            }break;
            case TEXT_SUBSECTION:{
                CTFontRef ctFont = CTFontCreateWithName((__bridge CFStringRef)fontName, subSectionFontSize, NULL);
                [_attributedString addAttribute:(NSString *)kCTFontAttributeName value:(__bridge id)ctFont range:paraRange];
                CFRelease(ctFont);
            }break;
            case TEXT_BLOCK_QUOTE:{
                [self applyBlockquoteToRange:paraRange];
            }break;
            case TEXT_BULLET:{
                [self applyBulletToRange:paraRange];
            }break;
            case TEXT_NUMBERING:{
                [self applyNumberingToRange:paraRange];
            }break;
            default:break;
        }
    }
    if (attrArr.count) {
        for (P2MSTextFormat *curFormat in attrArr) {
            int num = curFormat.txtFormat;
            if (num == TEXT_FORMAT_NONE)continue;
            NSRange curRange = curFormat.formatRange;
            if (curRange.location+curRange.length > _contentText.length) {
                NSInteger newLength = _contentText.length;
                newLength -= curRange.location;
                curRange = NSMakeRange(curRange.location, (newLength>0)?newLength:0);
            }
            int pointSize = _fontSize;
            for (P2MSParagraph *curPara in paragraphs) {
                NSRange paraRange = curPara.formatRange;
                if (NSLocationInRange(curRange.location, paraRange) ) {
                    int paraFormat = curPara.paraFormat;
                    switch (paraFormat) {
                        case TEXT_SECTION:pointSize = sectionFontSize;break;
                        case TEXT_SUBSECTION:pointSize = subSectionFontSize;break;
                        case TEXT_BLOCK_QUOTE:
                        default:pointSize = _fontSize;break;
                    }
                    break;
                }
            }
            if (num & TEXT_BOLD && num & TEXT_ITALIC) {
                CTFontRef ctFont = CTFontCreateWithName((__bridge CFStringRef) boldItalicFontName, pointSize, NULL);
                [_attributedString addAttribute:(NSString *)kCTFontAttributeName value:(__bridge id)ctFont range:curRange];
                CFRelease(ctFont);
            }else if (num & TEXT_BOLD) {
                CTFontRef ctFont = CTFontCreateWithName((__bridge CFStringRef) boldFontName, pointSize, NULL);
                [_attributedString addAttribute:(NSString *)kCTFontAttributeName value:(__bridge id)ctFont range:curRange];
                CFRelease(ctFont);
            }else if (num & TEXT_ITALIC) {
                CTFontRef ctFont = CTFontCreateWithName((__bridge CFStringRef) italicFontName, pointSize, NULL);
                [_attributedString addAttribute:(NSString *)kCTFontAttributeName value:(__bridge id)ctFont range:curRange];
                CFRelease(ctFont);
            }
            if (num & TEXT_UNDERLINE) {
                [_attributedString addAttribute:(NSString *)kCTUnderlineStyleAttributeName value:[NSNumber numberWithInteger:kCTUnderlineStyleSingle] range:curRange];
            }
            if (num & TEXT_STRIKE_THROUGH) {
                [_attributedString addAttribute:STRIKETHROUGH_KEY value:[NSNumber numberWithBool:YES] range:curRange];
            }
            if (num & TEXT_HIGHLIGHT) {
                [_attributedString addAttribute:HIGHLIGHT_KEY value:[NSNumber numberWithBool:YES] range:curRange];
            }
        }
    }
    
    if (_framesetter!=NULL) {
        CFRelease(_framesetter);
        _framesetter = NULL;
    }
    _framesetter = CTFramesetterCreateWithAttributedString((__bridge CFAttributedStringRef)_attributedString);
    
    CGRect rect = self.frame;
    CGSize suggestedSize = CTFramesetterSuggestFrameSizeWithConstraints(_framesetter, CFRangeMake(0, 0), NULL, CGSizeMake(rect.size.width, CGFLOAT_MAX), NULL);
    rect.size.height = suggestedSize.height+_fontSize; //self.font.lineHeight (or) _fontSize/1.618
    self.frame = rect;
    
    [self updateCTFrame];
    [self setNeedsDisplay];
    isDrawing = NO;
}

- (void)updateCTFrame
{
    // Create the Core Text frame using our current view rect bounds.
    UIBezierPath *path = [UIBezierPath bezierPathWithRect:self.bounds];
    
    if (_ctFrame != NULL) {
        CFRelease(_ctFrame);
        _ctFrame = NULL;
    }
    _ctFrame =  CTFramesetterCreateFrame(_framesetter, CFRangeMake(0, 0), [path CGPath], NULL);
}

-(void)setFrame:(CGRect)frame
{
    [super setFrame:frame];
    if (_ctFrame != NULL) {
        [self updateCTFrame];
    }
    [self setNeedsDisplay];
}

-(void)setBounds:(CGRect)bounds
{
    [super setBounds:bounds];
    if(_ctFrame) {
        [self updateCTFrame];
    }
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect {    
    CGContextRef context = UIGraphicsGetCurrentContext();

    CFArrayRef lines = CTFrameGetLines(_ctFrame);
    CFIndex linesCount = CFArrayGetCount(lines);
    
    //draw highlights
    CGContextSaveGState(context);
    [highlightColor setFill];

    for (CFIndex linesIndex = 0; linesIndex < linesCount; linesIndex++) {
        CTLineRef line = (CTLineRef) CFArrayGetValueAtIndex(lines, linesIndex);
        CGPoint origin = CGPointMake(0, 0);
        CTFrameGetLineOrigins(_ctFrame, CFRangeMake(linesIndex, 1), &origin);
        CFArrayRef runs = CTLineGetGlyphRuns(line);
        CGFloat lineAscent = 0, lineDescent = 0;
        CTLineGetTypographicBounds(line, &lineAscent, &lineDescent, NULL);
        CGFloat offset = 0;
        for (id oneRun in (__bridge NSArray *)runs){
            CGFloat ascent = 0;
            CGFloat descent = 0;
            CGFloat width = CTRunGetTypographicBounds((__bridge CTRunRef) oneRun, CFRangeMake(0, 0), &ascent, &descent, NULL);
            
            CFDictionaryRef attributes = CTRunGetAttributes((__bridge CTRunRef)(oneRun));
            NSNumber *curVal = CFDictionaryGetValue(attributes , HIGHLIGHT_KEY);
            if (curVal && [curVal boolValue])
            {
                CGRect bounds = CGRectMake(origin.x + offset, origin.y-descent, width, ascent + descent);
                UIRectFill(bounds);
            }
            offset += width;
        }
    }
    CGContextRestoreGState(context);

    [self drawFitTextHighLightForRange:_markedTextRange withColor:selectionColor];
    [self drawFitWidthHighLightForRange:_selectedTextRange withColor:selectionColor];
    [self drawFitTextHighLightForRange:_correctionRange withColor:spellingColor];
    
    //bullet specific
    CFStringRef keys[] = { kCTFontAttributeName };
    CTFontRef bulletFont = CTFontCreateWithName((__bridge CFStringRef) fontName, 25, NULL);
    CFTypeRef values[] = { (bulletFont) };
    CFDictionaryRef attributes =
    CFDictionaryCreate(kCFAllocatorDefault, (const void**)&keys,
                       (const void**)&values, sizeof(keys) / sizeof(keys[0]),
                       &kCFTypeDictionaryKeyCallBacks,
                       &kCFTypeDictionaryValueCallBacks);
    NSString *bulletString = @"•";
    CFAttributedStringRef attrString =
    CFAttributedStringCreate(kCFAllocatorDefault, (__bridge CFStringRef)(bulletString), attributes);
    CFRelease(bulletFont);
    
    //numbering specific
    CFStringRef keys1[] = { kCTFontAttributeName };
    UIFont *numFont = [UIFont boldSystemFontOfSize:14];
    CTFontRef numFont1 = CTFontCreateWithName((__bridge CFStringRef) fontName, 14, NULL);
    CFTypeRef values1[] = { (numFont1) };
    CFDictionaryRef numAttributes =
    CFDictionaryCreate(kCFAllocatorDefault, (const void**)&keys1,
                       (const void**)&values1, sizeof(keys1) / sizeof(keys1[0]),
                       &kCFTypeDictionaryKeyCallBacks,
                       &kCFTypeDictionaryValueCallBacks);
    CFRelease(numFont1);
    
    
    CGContextSaveGState(context);
    NSInteger curNumberIndex = 0;
    for (CFIndex linesIndex = 0; linesIndex < linesCount; linesIndex++) {
        CTLineRef line = (CTLineRef) CFArrayGetValueAtIndex(lines, linesIndex);
        CGPoint origin = CGPointMake(0, 0);
        CTFrameGetLineOrigins(_ctFrame, CFRangeMake(linesIndex, 1), &origin);
        CFArrayRef runs = CTLineGetGlyphRuns(line);
        CGFloat lineAscent = 0, lineDescent = 0;
        CTLineGetTypographicBounds(line, &lineAscent, &lineDescent, NULL);
        //append numbering/bullets based on padding
        if(origin.x > 0){
            CFRange lineRange = CTLineGetStringRange(line);
            if (lineRange.location == 0 || (lineRange.location > 0 && [_contentText characterAtIndex:lineRange.location-1] == '\n')) {
                if (origin.x >= 28) {
                    curNumberIndex++;
                    NSString *numString = [NSString stringWithFormat:@"%d.", curNumberIndex];
                    CFAttributedStringRef numAttrString = CFAttributedStringCreate(kCFAllocatorDefault, (__bridge CFStringRef)(numString), numAttributes);
                    CTLineRef line = CTLineCreateWithAttributedString(numAttrString);
                    // Set text position and draw the line into the graphics context
                    CGSize fontSize = [numString sizeWithFont:numFont constrainedToSize:CGSizeMake(28, 100)];
                    CGContextSetTextPosition(context, origin.x-fontSize.width-5, origin.y);
                    CTLineDraw(line, context);
                    CFRelease(numAttrString);
                    CFRelease(line);
                }else if(origin.x < 26){
                    curNumberIndex = 0;
                    CTLineRef line = CTLineCreateWithAttributedString(attrString);
                    // Set text position and draw the line into the graphics context
                    CGContextSetTextPosition(context, origin.x-15, origin.y-lineDescent);
                    CTLineDraw(line, context);
                    CFRelease(line);
                }
            }
        }else
            curNumberIndex = 0;
        
        //draw strikethrough
        CGFloat offset = 0;
        for (id oneRun in (__bridge NSArray *)runs){
            CGFloat ascent = 0;
            CGFloat descent = 0;
            CGFloat width = CTRunGetTypographicBounds((__bridge CTRunRef) oneRun, CFRangeMake(0, 0), &ascent, &descent, NULL);
            
            CFDictionaryRef attributes = CTRunGetAttributes((__bridge CTRunRef)(oneRun));
            NSNumber *curVal = CFDictionaryGetValue(attributes , STRIKETHROUGH_KEY);
            if (curVal && [curVal boolValue])
            {
                CGRect bounds = CGRectMake(origin.x + offset, origin.y-descent, width, ascent + descent);
                CGContextSetGrayStrokeColor(context, 0, 1.0);
                CGFloat y = roundf(bounds.origin.y + (bounds.size.height * 0.45));
                CGContextMoveToPoint(context, bounds.origin.x, y);
                CGContextSetLineWidth(context, 1 + bounds.size.height/25.0f);
                CGContextAddLineToPoint(context, bounds.origin.x + bounds.size.width, y);
                CGContextStrokePath(context);
            }
            offset += width;
        }
    }
    CGContextRestoreGState(context);
    CFRelease(numAttributes);
    CFRelease(attributes);
    CFRelease(attrString);
    CTFrameDraw(_ctFrame, UIGraphicsGetCurrentContext());
}

- (UIFont *)getFontForFormat:(PARAGRAPH_FORMAT)curPFmt{
    CGFloat mfontSize = _fontSize;
    if (curPFmt == TEXT_SECTION)mfontSize = sectionFontSize;
    else if (curPFmt == TEXT_SUBSECTION)mfontSize = subSectionFontSize;
    return [UIFont fontWithName:fontName size:mfontSize];
}

- (CGFloat)getLeadPaddingForParagraphFormat:(PARAGRAPH_FORMAT)curParagraphFormat{
    switch (curParagraphFormat) {
        case TEXT_BULLET:return 25;break;
        case TEXT_NUMBERING:return 28;break;
        case TEXT_BLOCK_QUOTE:return 26;break;
        default:return 0;break;
    }
}

- (CGRect)adjustRectWithParagraphStyle:(CGRect) curRect xPos:(CGFloat)xPos backToTop:(BOOL)lineBack{
    PARAGRAPH_FORMAT curPFmt = [_parentView getCurParagraphFormat];
    UIFont *curFont = [self getFontForFormat:curPFmt];
    if (lineBack) {
        curRect.origin.y -= curFont.lineHeight;
        if(curPFmt <= TEXT_PARAGRAPH)curRect.origin.x = xPos;
    }
    curRect.size.height = curFont.ascender - curFont.descender;
    return curRect;
}


#pragma mark get Char Range
//get the index of character at the tapped position
- (NSInteger)closestIndexToPoint:(CGPoint)point{
    CFArrayRef lines = CTFrameGetLines(_ctFrame);
    CFIndex linesCount = CFArrayGetCount(lines);
    CGPoint origins[linesCount];
    
    CTFrameGetLineOrigins(_ctFrame, CFRangeMake(0, linesCount), origins);
    for (CFIndex linesIndex = 0; linesIndex < linesCount; linesIndex++) {
        if (point.y + 7 > origins[linesIndex].y) {
            CTLineRef line = (CTLineRef)CFArrayGetValueAtIndex(lines, linesIndex);
            point.x -= origins[linesIndex].x;
            NSUInteger index = CTLineGetStringIndexForPosition(line, point);
            if (index != NSNotFound) {
                CFRange cfRange = CTLineGetStringRange(line);
                index -= ((index > 0 && index < _contentText.length && index >= cfRange.location+cfRange.length) || (index == _contentText.length && [_contentText hasSuffix:@"\n"]));
                return index;
            }
        }
    }
    return  _contentText.length;
}

//get the nearest white space at the tapped position
- (NSInteger)closestWhitespaceToPoint:(CGPoint)point{
    CFArrayRef lines = CTFrameGetLines(_ctFrame);
    CFIndex linesCount = CFArrayGetCount(lines);
    CGPoint origins[linesCount];
    CTFrameGetLineOrigins(_ctFrame, CFRangeMake(0, linesCount), origins);
    NSString *contentText = _contentText;
    __block NSRange returnRange = NSMakeRange(contentText.length, 0);
    
    for (CFIndex linesIndex = 0; linesIndex < linesCount; linesIndex++) {
        CTLineRef line = (CTLineRef)CFArrayGetValueAtIndex(lines, linesIndex);
        CGFloat ascent = 0, descent = 0;
        CTLineGetTypographicBounds(line, &ascent, &descent, NULL);
        if (point.y > origins[linesIndex].y-descent) {
            CFRange cfRange = CTLineGetStringRange(line);
            point.x -= origins[linesIndex].x;
            CFIndex index = CTLineGetStringIndexForPosition(line, point);
            if(cfRange.location==kCFNotFound)
                break;
            if (index >= contentText.length && cfRange.length > 1 ) {
                if ([contentText characterAtIndex:contentText.length-1] == '\n') {
                    return contentText.length-1;
                }
            }
            if ((cfRange.length < 1 || index == cfRange.location)){
                return cfRange.location;
            }
            if (index >= (cfRange.location+cfRange.length)) {
                unichar lastCharacter = [contentText characterAtIndex:(cfRange.location+cfRange.length)-1];
                return (cfRange.length >= 1 && (lastCharacter == '\n' || lastCharacter == ' '))?index-1:cfRange.location+cfRange.length;
            }
            [contentText enumerateSubstringsInRange:NSMakeRange(cfRange.location, cfRange.length) options:NSStringEnumerationByWords usingBlock:^(NSString *subString, NSRange subStringRange, NSRange enclosingRange, BOOL *stop){
                if (NSLocationInRange(index, enclosingRange)) {
                    if (index > (enclosingRange.location+(enclosingRange.length/2))) {
                        returnRange = NSMakeRange(subStringRange.location+subStringRange.length, 0);
                    } else {
                        returnRange = NSMakeRange(subStringRange.location, 0);
                    }
                    *stop = YES;
                }
                
            }];break;
        }
    }
    return  returnRange.location;
}

//get the word range at the index
- (NSRange)characterRangeAtIndex:(NSInteger)index {
    CFArrayRef lines = CTFrameGetLines(_ctFrame);
    CFIndex linesCount = CFArrayGetCount(lines);
    __block NSRange returnRange = NSMakeRange(NSNotFound, 0);
    for (CFIndex linesIndex=0; linesIndex < linesCount; linesIndex++) {
        CTLineRef line = (CTLineRef)CFArrayGetValueAtIndex(lines, linesIndex);
        CFRange cfRange = CTLineGetStringRange(line);
        NSRange range = NSMakeRange((cfRange.location == kCFNotFound)?NSNotFound:cfRange.location, cfRange.length);
        if (index >= cfRange.location && index <= cfRange.location+cfRange.length) {
            if (cfRange.length > 1) {
                [_contentText enumerateSubstringsInRange:range options:NSStringEnumerationByWords usingBlock:^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop) {
                    if (index - substringRange.location <= substringRange.length) {
                        returnRange = substringRange;
                        *stop = YES;
                    }
                }];
            }else{
                returnRange = NSMakeRange(cfRange.location, 1);
            }
        }
    }
    return returnRange;
}

- (NSRange)getWordRangeAtPoint:(CGPoint)point{
    CFArrayRef lines = CTFrameGetLines(_ctFrame);
    CFIndex linesCount = CFArrayGetCount(lines);
    CGPoint origins[linesCount];
    NSString *contentText = _contentText;
    __block NSRange returnRange = NSMakeRange(contentText.length, 0);
    CTFrameGetLineOrigins(_ctFrame, CFRangeMake(0, linesCount), origins);
    for (CFIndex linesIndex = 0; linesIndex < linesCount; linesIndex++) {
        CTLineRef line = (CTLineRef)CFArrayGetValueAtIndex(lines, linesIndex);
        CGFloat ascent = 0, descent = 0;
        CTLineGetTypographicBounds(line, &ascent, &descent, NULL);
        if (point.y > origins[linesIndex].y-descent) {
            point.x -= origins[linesIndex].x;
            NSUInteger curStrIndex = CTLineGetStringIndexForPosition(line, point);
            CFRange cfRange = CTLineGetStringRange(line);
            NSRange range = NSMakeRange(cfRange.location == kCFNotFound ? NSNotFound : cfRange.location, cfRange.length);
            if(range.location==NSNotFound)
                break;
            if (curStrIndex>=contentText.length || curStrIndex >= (range.location+range.length)) {
                if (range.length >= 1 && [contentText characterAtIndex:(range.location+range.length)-1] == '\n') {
                    returnRange = NSMakeRange(curStrIndex-1, range.length==1);
                    break;
                } else {
                    returnRange = NSMakeRange(range.location+range.length, 0);
                    break;
                }
            }else if (range.length <= 1){
                returnRange = range;
                break;
            }
            [contentText enumerateSubstringsInRange:range options:NSStringEnumerationByWords usingBlock:^(NSString *subString, NSRange subStringRange, NSRange enclosingRange, BOOL *stop){
                if (NSLocationInRange(curStrIndex, enclosingRange)) {
                    returnRange = NSMakeRange(subStringRange.location,subStringRange.length);
                    *stop = YES;
                }
            }];
            break;
        }
    }
    return returnRange;
}

#pragma mark Rect

- (CGRect)caretRectForIndex:(int)index
{
    if (index > _contentText.length) {
        index = _contentText.length;
    }
    if (self.contentText.length == 0) {
        PARAGRAPH_FORMAT curPFmt = [_parentView getCurParagraphFormat];
        CGFloat padLeading = [self getLeadPaddingForParagraphFormat:curPFmt];
        UIFont *curFont = [self getFontForFormat:curPFmt];
        CGPoint origin = CGPointMake(CGRectGetMinX(self.bounds), CGRectGetMaxY(self.bounds) - curFont.lineHeight);
        return CGRectMake(origin.x+padLeading, origin.y - fabs(curFont.descender), 3, curFont.ascender + fabs(curFont.descender));
    }

    CFArrayRef lines = CTFrameGetLines(_ctFrame);
    CFIndex linesCount = CFArrayGetCount(lines);
    
    // Special case, insertion point at final position in text after newline.
    if (index == _contentText.length) {
        CTLineRef line = (CTLineRef)CFArrayGetValueAtIndex(lines, linesCount -1);
        CGPoint origin = CGPointZero;
        CGFloat ascent = 0, descent = 0;
        CTLineGetTypographicBounds(line, &ascent, &descent, NULL);
        CTFrameGetLineOrigins(_ctFrame, CFRangeMake(linesCount - 1, 0), &origin);
        if ([self.contentText characterAtIndex:(index - 1)] == '\n') {
            CFRange range = CTLineGetStringRange(line);
            CGFloat xPos = CTLineGetOffsetForStringIndex(line, range.location, NULL);
            PARAGRAPH_FORMAT curPFmt = [_parentView getCurParagraphFormat];
            UIFont *curFont = [self getFontForFormat:curPFmt];
            CGRect curRect = CGRectMake(origin.x, origin.y-descent, 3, 0);
            curRect.origin.y -= curFont.lineHeight;
            if(curPFmt <= TEXT_PARAGRAPH)curRect.origin.x = xPos;
            curRect.size.height = curFont.ascender - curFont.descender;
            return curRect;
        }else{
            CGFloat xPos = CTLineGetOffsetForStringIndex(line, index, NULL);
            // Place point after last line, including any font leading spacing if applicable.
            return CGRectMake(xPos+origin.x, origin.y - descent, 3, ascent + descent);
        }
    }
    
    // Regular case, caret somewhere within our text content range.
    CGPoint *origins = (CGPoint*)malloc(linesCount * sizeof(CGPoint));
    CTFrameGetLineOrigins(_ctFrame, CFRangeMake(0, linesCount), origins);
    CGRect returnRect = CGRectZero;
    for (int linesIndex = 0; linesIndex < linesCount; linesIndex++) {
        CTLineRef line = (CTLineRef)CFArrayGetValueAtIndex(lines, linesIndex);
        CFRange range = CTLineGetStringRange(line);
        if (index >= range.location && index <= range.location+range.length) {
            CGFloat ascent, descent, xPos;
            xPos = CTLineGetOffsetForStringIndex(line, index, NULL);
            CTLineGetTypographicBounds(line, &ascent, &descent, NULL);
            CGPoint origin = origins[linesIndex];
            if (_selectedTextRange.length>0 && index != _selectedTextRange.location && range.length == 1) {
                xPos = self.bounds.size.width - 3.0f; // selection of entire line
            } else if ([_contentText characterAtIndex:index-1] == '\n' && range.length == 1) {
                xPos = 0.0f;// empty line
            }
            returnRect = CGRectMake(xPos+origin.x,  origin.y - descent, 3, descent + ascent);
        }
    }
    
    free(origins);
    return returnRect;
}

- (CGRect)firstRectForRange:(NSRange)range
{
    NSInteger index = range.location;
    CFArrayRef lines = CTFrameGetLines(_ctFrame);
    NSInteger linesCount = CFArrayGetCount(lines);
    for (CFIndex linesIndex = 0; linesIndex < linesCount; linesIndex++) {
        CTLineRef line = (CTLineRef)CFArrayGetValueAtIndex(lines, linesIndex);
        CFRange lineRange = CTLineGetStringRange(line);
        NSInteger localIndex = index - lineRange.location;
        if (localIndex >= 0 && localIndex < lineRange.length) {
			// use just the first line that intersects range.
            NSInteger finalIndex = MIN(lineRange.location + lineRange.length, range.location + range.length);
			// Create a rect for the given range within this line.
            CGFloat xStart = CTLineGetOffsetForStringIndex(line, index, NULL);
            CGFloat xEnd = CTLineGetOffsetForStringIndex(line, finalIndex, NULL);
            CGPoint origin = CGPointZero;
            CTFrameGetLineOrigins(_ctFrame, CFRangeMake(linesIndex, 1), &origin);
            CGFloat ascent = 0, descent = 0;
            CTLineGetTypographicBounds(line, &ascent, &descent, NULL);
            return [self convertRect:CGRectMake(xStart+origin.x, origin.y - descent, xEnd - xStart, ascent + descent) toView:self.superview];
        }
    }
    return CGRectNull;
}

@end
