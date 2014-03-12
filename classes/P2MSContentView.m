//
//  P2MSContentView.m
//  P2MSTextView
//
//  Created by PYAE PHYO MYINT SOE on 3/12/13.
//  Copyright (c) 2013 PYAE PHYO MYINT SOE. All rights reserved.
//

#import "P2MSContentView.h"
#import <CoreText/CoreText.h>
#import "P2MSGlobalFunctions.h"
#import "P2MSIndexedRange.h"

static NSString *STRIKETHROUGH_KEY = @"p2msTextView_strike_through_key";
static NSString *HIGHLIGHT_KEY =  @"p2msTextView_highlight_key";
static CGFloat MAX_POSSIBLE_HEIGHT = 100000;

@interface P2MSContentView()
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
        _caretView = [[P2MSCaretView alloc] initWithFrame:CGRectZero];
        [self addSubview:_caretView];
        _caretView.hidden = YES;
        
        self.layer.geometryFlipped = YES;
        self.backgroundColor = [UIColor clearColor];
        self.contentMode = UIViewContentModeRedraw;//change	to proper content modes if you want to do animation
        _contentText = @"";
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    }
    return self;
}

- (void)updateDefaultAttributes{
    if ([_fontSizes objectForKey:@"normal"] && [_fontNames objectForKey:@"regular"]) {
        CGFloat fontSize = [[_fontSizes objectForKey:@"normal"]floatValue];
        CTFontRef ctFont = CTFontCreateWithName((__bridge CFStringRef) [_fontNames objectForKey:@"regular"], fontSize, NULL);
        self.attributes = @{ (NSString *)kCTFontAttributeName : (__bridge id)ctFont };
        CFRelease(ctFont);
    }
}

- (void)setFontNames:(NSDictionary *)fontNames{
    _fontNames = fontNames;
    [self updateDefaultAttributes];
    if (_contentText.length) {
        [self redrawContentFrame];
    }
}

- (void)setFontSizes:(NSDictionary *)fontSizes{
    _fontSizes = fontSizes;
    [self updateDefaultAttributes];
    if (_contentText.length) {
        [self redrawContentFrame];
    }
}

- (void)setContentText:(NSString *)text
{
    _contentText = text;
    [self redrawContentFrame];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [self redrawContentFrame];
}

- (void)setEditing:(BOOL)editing
{
    _editing = editing;
    [self updateSelection];
}

#pragma mark Drawing Methods

- (void)refreshLayout{
    if (!self.editing) {
        _caretView.hidden = YES;
        return;
    }
    
    P2MSTextView *textView = (P2MSTextView *)self.superview;
    if (textView.selectedRange.length == 0) {
        self.caretView.frame = [self caretRectForIndex:textView.selectedRange.location];
        _caretView.hidden = NO;
        [self setNeedsDisplay];
        [self.caretView blinkCaret];
    }
    else {
        if (_caretView && !_caretView.hidden) {
            _caretView.hidden = YES;
        }
        
        if (textView.selectedRange.length > 0) {
            [self showSelectionViewForRange:textView.selectedRange];
        }
        [self setNeedsDisplay];
    }
}

- (void)refreshView{
    [self redrawContentFrame];
    [self refreshLayout];
}

- (void)redrawContentFrame{
    if (isDrawing) {
        return;
    }
    isDrawing = YES;
    if ([[UIMenuController sharedMenuController] isMenuVisible]) {
        [[UIMenuController sharedMenuController] setMenuVisible:NO animated:NO];
    }
    _attributedString = nil;
    _attributedString = [[NSMutableAttributedString alloc] initWithString:_contentText attributes:self.attributes];
    NSMutableDictionary *attribs = [(P2MSTextView *)self.superview getStyleAttributes];
    NSMutableArray *attrArr = [attribs objectForKey:@"attributes"];
    NSMutableArray *paragraphs = [attribs objectForKey:@"paragraphs"];
    NSMutableArray *links = [attribs objectForKey:@"links"];
    
    UIColor *linkColor = [_fontColors objectForKey:@"link"];
    for (P2MSLink *link in links) {
        [_attributedString addAttribute:(NSString *)kCTForegroundColorAttributeName value:(id)[linkColor CGColor] range:link.styleRange];
    }
    
    NSString *regularFontName = [_fontNames objectForKey:@"regular"];
    CGFloat sectionFontSize = [[_fontSizes objectForKey:@"section"]floatValue];
    CGFloat subSectionFontSize = [[_fontSizes objectForKey:@"subsection"]floatValue];
    CGFloat normalFontSize = [[_fontSizes objectForKey:@"normal"]floatValue];
    
    NSString *boldItalicFontName = [_fontNames objectForKey:@"bold_italic"];
    NSString *boldFontName = [_fontNames objectForKey:@"bold"];
    NSString *italicFontName = [_fontNames objectForKey:@"italic"];
    
    NSEnumerator *paragraphEnumerator = [paragraphs objectEnumerator];
    P2MSParagraph *curParagraph = nil;//[paragraphEnumerator nextObject];
    CGFloat paragraphEndPos = 0;//curParagraph.styleRange.location + curParagraph.styleRange.length;
    
    NSString *fontName;
    CGFloat pointSize, paragraph_pointSize = normalFontSize;
    
    for (P2MSTextAttribute *curAttr in attrArr) {
        if (curAttr.styleRange.location >= paragraphEndPos) {
            while (curAttr.styleRange.location >= paragraphEndPos && (curParagraph = [paragraphEnumerator nextObject])) {
                paragraphEndPos = curParagraph.styleRange.location + curParagraph.styleRange.length;
            }
            paragraph_pointSize = normalFontSize;
            switch (curParagraph.style) {
                case PARAGRAPH_SECTION:{
                    paragraph_pointSize = sectionFontSize;
                }break;
                case PARAGRAPH_SUBSECTION:{
                    paragraph_pointSize = subSectionFontSize;
                }break;
                case PARAGRAPH_BLOCK_QUOTE:{
                    [self applyBlockquoteToRange:curParagraph.styleRange];
                }break;
                case PARAGRAPH_BULLET:{
                    [self applyBulletToRange:curParagraph.styleRange];
                }break;
                case PARAGRAPH_NUMBERING:{
                    [self applyNumberingToRange:curParagraph.styleRange];
                }break;
                default:{
                }break;
            }
        }
        fontName = regularFontName;
        pointSize = paragraph_pointSize;

        int num = curAttr.txtAttrib;
        if (num == TEXT_FORMAT_NONE && curParagraph.style > 4)continue;
        NSRange curRange = curAttr.styleRange;
        if (curRange.location+curRange.length > _contentText.length) {
            NSInteger newLength = _contentText.length;
            newLength -= curRange.location;
            curRange = NSMakeRange(curRange.location, (newLength>0)?newLength:0);
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
        }else if (pointSize != normalFontSize || ![fontName isEqualToString:regularFontName]){
            CTFontRef ctFont = CTFontCreateWithName((__bridge CFStringRef) fontName, pointSize, NULL);
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
    
    if (_framesetter!=NULL) {
        CFRelease(_framesetter);
        _framesetter = NULL;
    }
    _framesetter = CTFramesetterCreateWithAttributedString((__bridge CFAttributedStringRef)_attributedString);

    P2MSTextView *textView = (P2MSTextView *)self.superview;
    CGRect rect = CGRectMake(textView.edgeInsets.top, textView.edgeInsets.left, self.bounds.size.width, MAX_POSSIBLE_HEIGHT);
    CGSize suggestedSize = CTFramesetterSuggestFrameSizeWithConstraints(_framesetter, CFRangeMake(0, 0), NULL, rect.size, NULL);
    rect.size.height = suggestedSize.height; //self.font.lineHeight (or) _fontSize/1.618
    if ([_contentText hasSuffix:@"\n"]) {
        rect.size.height += normalFontSize;
    }
    self.frame = rect;
    NSLog(@"New frame %f,%f,%f,%f", rect.origin.x, rect.origin.y, rect.size.width, rect.size.height);

    [self updateCTFrame];
    [self setNeedsDisplay];
    isDrawing = NO;
}


- (void)applyBlockquoteToRange:(NSRange)range{
    if (range.length > 0) {
        NSDictionary *format = [P2MSContentView getParagraphFormatWithLeftPadding:26.0f];
        [_attributedString addAttributes:format range:range];
    }
}

///////////////////////////////////////////////////////////////////////////////////////
// Tricks to avoid maintaining the additional data (or additional manipulation) for the bullets & numberings and to easily recognize in drawRect
// need to adjust the spacing (using modulo) if you want to add Left/Right Indentation
///////////////////////////////////////////////////////////////////////////////////////
- (void)applyBulletToRange:(NSRange)range{
    if (range.length > 0) {
        NSDictionary *format = [P2MSContentView getParagraphFormatWithLeftPadding:25.0f];
        [_attributedString addAttributes:format range:range];
    }
}

- (void)applyNumberingToRange:(NSRange)range{
    if (range.length) {
        NSDictionary *format = [P2MSContentView getParagraphFormatWithLeftPadding:28.0f];
        [_attributedString addAttributes:format range:range];
    }
}
///////////////////////////////////////////////////////////////////////////////////////

+ (NSDictionary *)getParagraphFormatWithLeftPadding:(CGFloat)leftPadding{
    CTTextAlignment alignment = kCTLeftTextAlignment;
    CGFloat paragraphSpacing = 2;
    CGFloat paragraphSpacingBefore = 2;
    CGFloat firstLineHeadIndent = leftPadding;//15.0;
    CGFloat headIndent = leftPadding;
    
    CGFloat firstTabStop = 15.0; // width of your indent
//    CGFloat lineSpacing = 1;
    
    CTTextTabRef tabArray[] = { CTTextTabCreate(0, firstTabStop, NULL) };
    
    CFArrayRef tabStops = CFArrayCreate( kCFAllocatorDefault, (const void**) tabArray, 1, &kCFTypeArrayCallBacks );
    CFRelease(tabArray[0]);
    
    CGFloat minSpacing = 0.0f;
    CGFloat maxSpacing = 3.0f;
    
    CTParagraphStyleSetting altSettings[] =
    {
//        { kCTParagraphStyleSpecifierLineSpacingAdjustment, sizeof(CGFloat), &lineSpacing},//deprecated and causing error in drawRect
        { kCTParagraphStyleSpecifierMinimumLineSpacing, sizeof(CGFloat), &minSpacing},
        { kCTParagraphStyleSpecifierMaximumLineSpacing, sizeof(CGFloat), &maxSpacing},
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

- (void)updateCTFrame
{
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


//Background color fit to text
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

//fill background color to max width
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

- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CFArrayRef lines = CTFrameGetLines(_ctFrame);
    CFIndex linesCount = CFArrayGetCount(lines);
    
    //draw highlights
    CGContextSaveGState(context);
    UIColor *highlightColor = [_fontColors objectForKey:@"highlight"];
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
            NSNumber *curVal = CFDictionaryGetValue(attributes , (__bridge const void *)(HIGHLIGHT_KEY));
            if (curVal && [curVal boolValue])
            {
                CGRect bounds = CGRectMake(origin.x + offset, origin.y-descent, width, ascent + descent);
                UIRectFill(bounds);
            }
            offset += width;
        }
    }
    CGContextRestoreGState(context);
    
    P2MSTextView *textView = (P2MSTextView *)self.superview;
    
    UIColor *selectionColor = [_fontColors objectForKey:@"selection"];
    UIColor *spellingColor = [_fontColors objectForKey:@"spelling"];
    [self drawFitTextHighLightForRange: ((P2MSIndexedRange *)textView.markedTextRange).range withColor:selectionColor];
    [self drawFitWidthHighLightForRange:((P2MSIndexedRange *)textView.selectedTextRange).range withColor:selectionColor];
    [self drawFitTextHighLightForRange:textView.correctionRange withColor:spellingColor];
    
    //bullet specific
    NSString *regularFontName = [_fontNames objectForKey:@"regular"];
    CFStringRef keys[] = { kCTFontAttributeName };
    CTFontRef bulletFont = CTFontCreateWithName((__bridge CFStringRef) regularFontName, 25, NULL);
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
    CTFontRef numFont1 = CTFontCreateWithName((__bridge CFStringRef) regularFontName, 14, NULL);
    CFTypeRef values1[] = { (numFont1) };
    CFDictionaryRef numAttributes =
    CFDictionaryCreate(kCFAllocatorDefault, (const void**)&keys1,
                       (const void**)&values1, sizeof(keys1) / sizeof(keys1[0]), &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
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
        //append numbering/bullets based on left paragraph spacing
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
            NSNumber *curVal = CFDictionaryGetValue(attributes , (__bridge const void *)(STRIKETHROUGH_KEY));
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

#pragma mark misc

- (CGFloat)getLeftPaddingForParagraphFormat:(PARAGRAPH_STYLE)paraStyle{
    switch (paraStyle) {
        case PARAGRAPH_BULLET:return 25;
        case PARAGRAPH_NUMBERING:return 28;
        case PARAGRAPH_BLOCK_QUOTE:return 26;
        default:return 0;
    }
}

- (UIFont *)getRegularFontForParagraphStyle:(PARAGRAPH_STYLE) paraStyle{
    NSString *regularFontName = [_fontNames objectForKey:@"regular"];
    switch (paraStyle) {
        case PARAGRAPH_SECTION:return [UIFont fontWithName:regularFontName size:[[_fontSizes objectForKey:@"section"]floatValue]];;
        case PARAGRAPH_SUBSECTION:return [UIFont fontWithName:regularFontName size:[[_fontSizes objectForKey:@"subsection"]floatValue]];;
        default:return [UIFont fontWithName:regularFontName size:[[_fontSizes objectForKey:@"normal"]floatValue]];
    }
}

- (void)responseToLongPress:(UILongPressGestureRecognizer*)gesture{
    if (gesture.state==UIGestureRecognizerStateBegan || gesture.state == UIGestureRecognizerStateChanged) {
        CGPoint point = [gesture locationInView:self];
        BOOL _selection = (_selectionView!=nil);
        if (!_selection && !self.caretView.hidden) {
            [self.caretView removeAnimations];
        }
        
        textWindow = [P2MSTextWindow getTextWindow:textWindow];
        textWindow.windowType = (_selection)?P2MS_TEXT_MAGNIFY:P2MS_TEXT_LOUPE;
        P2MSTextView *textView = (P2MSTextView *)self.superview;
        NSInteger index = [self closestIndexToPoint:point];
        if (_selection) {
            if (gesture.state == UIGestureRecognizerStateBegan) {
                _selectionView.isSelectionLeft = !(index > (textView.selectedRange.location+(textView.selectedRange.length/2)));
            }
            CGRect rect = CGRectZero;
            if (_selectionView.isSelectionLeft) {
                NSInteger begin = MAX(0, index);
                begin = MIN(textView.selectedRange.location+textView.selectedRange.length-1, begin);
                if (_contentText.length > begin+1 && [_contentText characterAtIndex:begin] == '\n') {
                    begin++;
                }
                
                NSInteger end = textView.selectedRange.location + textView.selectedRange.length;
                end = MIN(_contentText.length, end-begin);
                textView.selectedRange = NSMakeRange(begin, end);
                index = textView.selectedRange.location;
            } else {
                NSInteger length = MAX(1, index - (NSInteger)textView.selectedRange.location);
                length = MIN(length, _contentText.length-textView.selectedRange.location);

                NSRange newRange = NSMakeRange(textView.selectedRange.location, length);
                index = (newRange.location+newRange.length);
                textView.selectedRange = newRange;
            }
            rect = [self caretRectForIndex:index];
            if (gesture.state == UIGestureRecognizerStateBegan) {
                [textWindow showTextWindowFromView:self rect:[self convertRect:rect toView:textWindow]];
            } else {
                [textWindow renderContentView:self fromRect:[self convertRect:rect toView:textWindow]];
            }
        } else {
            textView.selectedRange = NSMakeRange(index, 0);
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
            [self.caretView blinkCaret];
        }
        
        if (textWindow!=nil) {
            [textWindow hideTextWindow:YES];
            textWindow=nil;
        }
    }
}

#pragma mark Selection
- (void)updateSelection
{
    _showCorrectinMenu = NO;
    if (!self.editing) {
        _caretView.hidden = YES;
    }
    P2MSTextView *textView = (P2MSTextView *)self.superview;
    UILongPressGestureRecognizer *longPress = textView.longPressGestureRecognizer;
    if (textView.selectedRange.length == 0) {
        _caretView.frame = [self caretRectForIndex:textView.selectedRange.location];
        if (_selectionView != nil) {
            [_selectionView removeFromSuperview];
            _selectionView = nil;
        }

        _caretView.hidden = !_editing;
        [self setNeedsDisplay];
        [self.caretView blinkCaret];
        longPress.minimumPressDuration = 0.5f;
    }
    else {
        longPress.minimumPressDuration = 0.0f;
        if (_caretView && !_caretView.hidden) {
            _caretView.hidden = YES;
        }
        if (_selectionView==nil) {
            _selectionView = [[P2MSSelectionView alloc] initWithFrame:self.bounds];
            [self addSubview:_selectionView];
        }
        [self showSelectionViewForRange:textView.selectedRange];
        [self setNeedsDisplay];
    }
}

- (void)showSelectionViewForRange:(NSRange)range{
    CFArrayRef lines = CTFrameGetLines(_ctFrame);
    CFIndex linesCount = CFArrayGetCount(lines);
    
    // Regular case, caret somewhere within our text content range.
    CGPoint *origins = (CGPoint*)malloc(linesCount * sizeof(CGPoint));
    CTFrameGetLineOrigins(_ctFrame, CFRangeMake(0, linesCount), origins);
    
    NSUInteger textLength = _contentText.length;
    NSUInteger beginIndex = range.location, endIndex = range.location+range.length;
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
    [_selectionView beginCaretForRect:beginRect endCaretForRect:endRect];
    free(origins);
}



#pragma mark Character Range
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

//get nearest white space at the tapped position
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


#pragma mark Caret Rect Methods

- (CGRect)caretRectForIndex:(int)index
{
    if (_contentText.length == 0) {
        PARAGRAPH_STYLE paraStyle = [(P2MSTextView *)self.superview paragraphs].current_paragraph.style;
        CGFloat padLeading = [self getLeftPaddingForParagraphFormat:paraStyle];
        UIFont *curFont = [self getRegularFontForParagraphStyle:paraStyle];
//        CGPoint origin = CGPointMake(CGRectGetMinX(self.bounds), CGRectGetMaxY(self.bounds) - curFont.lineHeight);
//        return CGRectMake(origin.x+padLeading, origin.y - fabs(curFont.descender), 3, curFont.ascender + fabs(curFont.descender));
        CGPoint origin = CGPointMake(CGRectGetMinX(self.bounds), 0);
        origin.y = floorf(curFont.ascender-curFont.capHeight);
        return CGRectMake(origin.x+padLeading, origin.y+curFont.descender-curFont.lineHeight, 3, curFont.ascender + fabs(curFont.descender));
    }
    index = MIN(index, _contentText.length);
    
    CFArrayRef lines = CTFrameGetLines(_ctFrame);
    CFIndex linesCount = CFArrayGetCount(lines);
    CGRect returnRect = CGRectZero;
    if (linesCount == 0) {
        return returnRect;
    }

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
            PARAGRAPH_STYLE paraStyle = [(P2MSTextView *)self.superview paragraphs].current_paragraph.style;
            UIFont *curFont = [self getRegularFontForParagraphStyle:paraStyle];
            CGRect curRect = CGRectMake(origin.x, origin.y-descent, 3, 0);
            curRect.origin.y -= curFont.lineHeight;
            if(paraStyle <= PARAGRAPH_NORMAL)curRect.origin.x = xPos;
            curRect.size.height = curFont.ascender - curFont.descender;
            returnRect = curRect;
        }else{
            CGFloat xPos = CTLineGetOffsetForStringIndex(line, index, NULL);
            // Place point after last line, including any font leading spacing if applicable.
            returnRect = CGRectMake(xPos+origin.x, origin.y - descent, 3, ascent + descent);
        }
    }else{
        // Regular case, caret somewhere within our text content range.
        CGPoint *origins = (CGPoint*)malloc(linesCount * sizeof(CGPoint));
        CTFrameGetLineOrigins(_ctFrame, CFRangeMake(0, linesCount), origins);
        
        for (int linesIndex = 0; linesIndex < linesCount; linesIndex++) {
            CTLineRef line = (CTLineRef)CFArrayGetValueAtIndex(lines, linesIndex);
            CFRange range = CTLineGetStringRange(line);
            if (index >= range.location && index <= range.location+range.length) {
                CGFloat ascent, descent, xPos;
                xPos = CTLineGetOffsetForStringIndex(line, index, NULL);
                CTLineGetTypographicBounds(line, &ascent, &descent, NULL);
                CGPoint origin = origins[linesIndex];
                P2MSTextView *textView = (P2MSTextView *)self.superview;
                if (textView.selectedRange.length>0 && index != textView.selectedRange.location && range.length == 1) {
                    xPos = self.bounds.size.width - 3.0f; // selection of entire line
                } else if ([_contentText characterAtIndex:index-1] == '\n' && range.length == 1) {
                    xPos = 0.0f;
                }
                returnRect = CGRectMake(xPos+origin.x,  origin.y - descent, 3, descent + ascent);
            }
        }
        free(origins);
    }
    if (returnRect.origin.x >= self.bounds.size.width-2) {
        returnRect.origin.x = self.bounds.size.width-3;
    }
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
			// use the first line that intersects range.
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
