//
//  P2MSHTMLNode.m
//  P2MSTextView
//
//  Created by PYAE PHYO MYINT SOE on 3/12/13.
//  Copyright (c) 2013 PYAE PHYO MYINT SOE. All rights reserved.
//

#import "P2MSHTMLNode.h"
#import "GTMNSString+HTML.h"
#import "P2MSGlobalFunctions.h"
#import "P2MSParagraph.h"

@implementation P2MSHTMLNode

- (NSMutableDictionary *)attributes{
    if (!_attributes) {
        _attributes = [NSMutableDictionary dictionary];
    }
    return _attributes;
}

@end


@implementation P2MSHTMLReferenceTable

+ (P2MSHTMLReferenceTable *)sharedInstance {
    static dispatch_once_t pred;
    __strong static P2MSHTMLReferenceTable *sharedReferenceTable = nil;
    dispatch_once( &pred, ^{
        sharedReferenceTable = [[self alloc] init]; });
    return sharedReferenceTable;
}

- (id)init{
    if (self = [super init]) {
        _textFormatReference = [NSDictionary dictionaryWithObjects:
                                                         [NSArray arrayWithObjects:
                                                          [NSNumber numberWithInt:TEXT_BOLD],
                                                          [NSNumber numberWithInt:TEXT_ITALIC],
                                                          [NSNumber numberWithInt:TEXT_UNDERLINE],
                                                          [NSNumber numberWithInt:TEXT_STRIKE_THROUGH],
                                                          [NSNumber numberWithInt:TEXT_HIGHLIGHT],
                                                          [NSNumber numberWithInt:TEXT_LINK],
                                                          [NSNumber numberWithInt:TEXT_FORMAT_NONE],
                                                          [NSNumber numberWithInt:TEXT_FORMAT_NONE],
                                                          nil] forKeys:[NSArray arrayWithObjects:@"b", @"i", @"u", @"strike", @"mark", @"a", @"span", @"NO_HTML", nil]];
        
        _paragraphFormatReference = [NSMutableDictionary dictionaryWithObjects:
                                                             [NSArray arrayWithObjects:
                                                              [NSNumber numberWithInt:PARAGRAPH_BULLET],
                                                              [NSNumber numberWithInt:PARAGRAPH_NUMBERING],
                                                              [NSNumber numberWithInt:PARAGRAPH_SECTION],
                                                              [NSNumber numberWithInt:PARAGRAPH_SUBSECTION],
                                                              [NSNumber numberWithInt:PARAGRAPH_BLOCK_QUOTE],
                                                              [NSNumber numberWithInt:PARAGRAPH_LIST],
                                                              [NSNumber numberWithInt:PARAGRAPH_NORMAL],
                                                              [NSNumber numberWithInt:PARAGRAPH_NORMAL],
                                                              nil]
                                                    forKeys:[NSArray arrayWithObjects:@"ul", @"ol", @"h3", @"h5", @"blockquote", @"li", @"p", @"div", nil]];

    }
    return self;
}


@end


@implementation P2MSHTMLOperation

+ (NSString *)stripHTML:(NSString *)inString{
    NSRange r;
    while ((r = [inString rangeOfString:@"<[^>]+>" options:NSRegularExpressionSearch]).location != NSNotFound)
        inString = [inString stringByReplacingCharactersInRange:r withString:@""];
    NSString *s = [inString gtm_stringByUnescapingFromHTML];
    return s;
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

+ (NSMutableArray *)getHTMLNodes:(NSString *)htmlString withParent:(P2MSHTMLNode *)parentNode{
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
        if(initialString && initialString.length) {
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
                oneNode.parent = parentNode;
                oneNode.htmlTag = htmlTag;
                NSString *contentToSave = [content substringFromIndex:1];
                NSString *htmlStripped = [self stripHTML:contentToSave];
                oneNode.content = htmlStripped;
                if (htmlStripped && ![htmlStripped isEqualToString:contentToSave]) {
                    oneNode.children = [self getHTMLNodes:contentToSave withParent:oneNode];
                }else{
                    NSArray *children = [self stripNewLine:htmlStripped];
                    if (children.count > 1) {
                        NSMutableArray *childrenNodes = [NSMutableArray array];
                        for (NSString *inStr in children) {
                            P2MSHTMLNode *oneNode = [[P2MSHTMLNode alloc]init];
                            oneNode.htmlTag = @"NO_HTML";
                            oneNode.parent = parentNode;
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

//- (PARAGRAPH_STYLE)parentParagraphStyle:(P2MSHTMLNode *)node{
//    if (node.parent) {
//        return [[[P2MSHTMLReferenceTable sharedInstance].paragraphFormatReference objectForKey:node.parent.htmlTag] integerValue];
//    }
//    return PARAGRAPH_NONE;
//}

+ (void)convertNode:(P2MSHTMLNode **)parentNode toParaAttributes:(NSMutableArray **)paraSet toAttributes:(NSMutableArray **)attrArr andLinks:(NSMutableSet **)allLinks{
    P2MSHTMLNode *node = *parentNode;
    NSRange strRange = node.range;
    //child range
    if (strRange.location == NSNotFound || strRange.length == 0)return;
    
    if (node.children) {
        NSUInteger lastIndex = strRange.location, curLength = 0;
        for (P2MSHTMLNode *children in node.children) {
            curLength = children.content.length;
            children.range = NSMakeRange(lastIndex, curLength);
            lastIndex += curLength;
        }
    }
    NSDictionary *paraDict = [P2MSHTMLReferenceTable sharedInstance].paragraphFormatReference;
    NSDictionary *txtDict = [P2MSHTMLReferenceTable sharedInstance].textFormatReference;
    NSString *htmlTag = node.htmlTag;
    NSNumber *paragraphFormat = [paraDict objectForKey:htmlTag];
    if (paragraphFormat) {
        PARAGRAPH_STYLE paragraphStyle = [paragraphFormat integerValue];
        if (paragraphStyle == PARAGRAPH_LIST) {
            paragraphStyle = PARAGRAPH_BULLET;
            if (node.parent) {
                PARAGRAPH_STYLE parentParagraphStyle = [[paraDict objectForKey:node.parent.htmlTag] integerValue];
                if (parentParagraphStyle == PARAGRAPH_NUMBERING) {
                    paragraphStyle = PARAGRAPH_NUMBERING;
                }
            }
        }
        [self addParaFormat:paragraphStyle forRange:strRange toArr:paraSet];
    }else{
        NSNumber *txtFormatValue = [txtDict objectForKey:htmlTag];
        if (txtFormatValue){
            TEXT_ATTRIBUTE textFormat = [txtFormatValue integerValue];
            if (textFormat == TEXT_LINK) {
                P2MSLink *link = [[P2MSLink alloc]init];
                link.linkURL = [node.attributes objectForKey:@"href"];
                link.styleRange = node.range;
                [(*allLinks) addObject:link];
                [self addTextFormat:TEXT_FORMAT_NONE forRange:strRange toArr:attrArr];
            }else
                [self addTextFormat:textFormat forRange:strRange toArr:attrArr];
        }
    }
    
    if (node.children){
        for (P2MSHTMLNode *curNode in node.children) {
            P2MSHTMLNode *internalNode = curNode;
            [self convertNode:&internalNode toParaAttributes:paraSet toAttributes:attrArr andLinks:allLinks];
        }
    }
    
//    if (![htmlTag isEqualToString:@"NO_HTML"]) {
//        if (strRange.location != NSNotFound && strRange.length > 0) {
//            NSNumber *paragraphFormat = [paraDict objectForKey:htmlTag];
//            if (paragraphFormat) {
//                PARAGRAPH_STYLE paragraphStyle = [paragraphFormat integerValue];
//                if (paragraphStyle != PARAGRAPH_BULLET && paragraphStyle != PARAGRAPH_NUMBERING) {
//                    if (paragraphStyle == PARAGRAPH_LIST && node.parent ) {
//                    }
//                    [self addParaFormat:paragraphStyle forRange:strRange toArr:paraSet];
//                }
//            }
//                if ([htmlTag isEqualToString:@"li"] || [htmlTag isEqualToString:@"a"]) {
//                    if (node.children && node.children.count) {
//                        if (paragraphStyle != PARAGRAPH_NORMAL) {
//                            [self addParaFormat:paragraphStyle forRange:strRange toArr:paraSet];
//                        }
//                    }else{
//                        [self addTextFormat:TEXT_FORMAT_NONE forRange:strRange toArr:attrArr];
//                    }
//                }
//                else{
//                    [self addParaFormat:paragraphStyle forRange:strRange toArr:paraSet];
//                    if (node.children && node.children.count) {}//nothing to do in this case
//                    else//it occurs only when there is no text formatting applied on it
//                        [self addTextFormat:TEXT_FORMAT_NONE forRange:strRange toArr:attrArr];
//                }
//            }else{
//            }
//            NSNumber *refFmt = [dict objectForKey:htmlTag];
//            if (refFmt) {
//                int format = [refFmt intValue];
//                if (format >= 100) {
//                    if ([htmlTag isEqualToString:@"li"] || [htmlTag isEqualToString:@"a"]) {
//                        if (node.children && node.children.count) {
//                            if (format != PARAGRAPH_NORMAL) {
//                                [self addParaFormat:format forRange:strRange toArr:paraSet];
//                            }
//                        }else{
//                            [self addTextFormat:TEXT_FORMAT_NONE forRange:strRange toArr:attrArr];
//                        }
//                        if ([htmlTag isEqualToString:@"a"]) {
//                            P2MSLink *link = [[P2MSLink alloc]init];
//                            link.linkURL = [node.attributes objectForKey:@"href"];
//                            link.styleRange = node.range;
//                            [(*allLinks) addObject:link];
//                        }
//                    }else{
//                        [self addParaFormat:format forRange:strRange toArr:paraSet];
//                        if (node.children && node.children.count) {}//nothing to do in this case
//                        else//it occurs only when there is no text formatting applied on it
//                            [self addTextFormat:TEXT_FORMAT_NONE forRange:strRange toArr:attrArr];
//                    }
//                }else{
//                    [self addTextFormat:format forRange:strRange toArr:attrArr];
//                }
//            }
//        }
//        if (node.children) {
//            for (P2MSHTMLNode *curNode in node.children) {
//                P2MSHTMLNode *internalNode = curNode;
//                [self convertNode:&internalNode toParaAttributes:paraSet toAttributes:attrArr andLinks:allLinks refDict:dict];
//            }
//        }
//    }else{
//        [self addTextFormat:TEXT_FORMAT_NONE forRange:strRange toArr:attrArr];
//    }
}

+ (void)addTextFormat:(TEXT_ATTRIBUTE)txtFmt forRange:(NSRange)range toArr:(NSMutableArray **)attrArr{
    BOOL isNew = YES;
    NSRange intersectRange;
    for (P2MSTextAttribute *txtFormat in *attrArr) {
        if ((intersectRange = NSIntersectionRange(txtFormat.styleRange, range)).length > 0) {
            if (intersectRange.length != txtFormat.styleRange.length) {//split it into two or three
                if (txtFormat.styleRange.location < intersectRange.location) {
                    P2MSTextAttribute *leftFmt = [[P2MSTextAttribute alloc]init];
                    leftFmt.txtAttrib = txtFormat.txtAttrib;
                    leftFmt.styleRange = NSMakeRange(txtFormat.styleRange.location, intersectRange.location - txtFormat.styleRange.location);
                    [(*attrArr) addObject:leftFmt];
                }
                NSInteger finalIntersectPos = intersectRange.location + intersectRange.length;
                NSInteger finalFmtPos = txtFormat.styleRange.location + txtFormat.styleRange.length;
                if (finalFmtPos > finalIntersectPos) {
                    P2MSTextAttribute *rightFmt = [[P2MSTextAttribute alloc]init];
                    rightFmt.txtAttrib =  txtFormat.txtAttrib;
                    rightFmt.styleRange = NSMakeRange(finalIntersectPos, finalFmtPos - finalIntersectPos);
                    [(*attrArr) addObject:rightFmt];
                }
                txtFormat.styleRange = intersectRange;
                txtFormat.txtAttrib = txtFormat.txtAttrib | txtFmt;
            }else
                txtFormat.txtAttrib |= txtFmt;
            isNew = NO;break;
        }
    }
    if (isNew) {
        P2MSTextAttribute *curFmt = [[P2MSTextAttribute alloc]init];
        curFmt.txtAttrib = txtFmt;
        curFmt.styleRange = range;
        [(*attrArr) addObject:curFmt];
    }
}

+ (void)addParaFormat:(PARAGRAPH_STYLE)paraFmt forRange:(NSRange)range toArr:(NSMutableArray **)paraArr{
    BOOL isNew = YES;
    NSRange intersectRange;
    for (P2MSParagraph *curPara in *paraArr) {
        if ((intersectRange = NSIntersectionRange(curPara.styleRange, range)).length > 0) {
            if (intersectRange.length != curPara.styleRange.length) {//split it into two or three
                if (curPara.styleRange.location < intersectRange.location) {
                    P2MSParagraph *leftPara = [[P2MSParagraph alloc]init];
                    leftPara.style = curPara.style;
                    leftPara.styleRange = NSMakeRange(curPara.styleRange.location, intersectRange.location - curPara.styleRange.location);
                    [(*paraArr) addObject:leftPara];
                }
                NSInteger finalIntersectPos = intersectRange.location + intersectRange.length;
                NSInteger finalFmtPos = curPara.styleRange.location + curPara.styleRange.length;
                if (finalFmtPos > finalIntersectPos) {
                    P2MSParagraph *rightPara = [[P2MSParagraph alloc]init];
                    rightPara.style =  curPara.style;
                    rightPara.styleRange = NSMakeRange(finalIntersectPos, finalFmtPos - finalIntersectPos);
                    [(*paraArr) addObject:rightPara];
                }
                curPara.styleRange = intersectRange;
                curPara.style = curPara.style | paraFmt;
            }else
                curPara.style |= paraFmt;
            isNew = NO;break;
        }
    }

    if (isNew) {
        P2MSParagraph *curPara = [[P2MSParagraph alloc]init];
        curPara.style = paraFmt;
        curPara.styleRange = range;
        [(*paraArr) addObject:curPara];
    }

//    P2MSParagraph *curFmt = [[P2MSParagraph alloc]init];
//    curFmt.style = paraFmt;
//    curFmt.range = range;
//    [(*arr) addObject:curFmt];
}


@end
