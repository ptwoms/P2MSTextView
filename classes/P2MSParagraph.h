//
//  P2MSParagraph.h
//  P2MSTextView
//
//  Created by PYAE PHYO MYINT SOE on 22/2/14.
//  Copyright (c) 2014 PYAE PHYO MYINT SOE. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "P2MSGlobalFunctions.h"

typedef enum{
    PARAGRAPH_NONE = 0,
    PARAGRAPH_SECTION = 1,
    PARAGRAPH_SUBSECTION = 2,
    PARAGRAPH_NORMAL = 4,
    PARAGRAPH_BULLET = 8,
    PARAGRAPH_NUMBERING = 16,
    PARAGRAPH_LIST = 32,
    PARAGRAPH_CONTAINER = 64,
    PARAGRAPH_BLOCK_QUOTE = 128
}PARAGRAPH_STYLE;


@interface P2MSParagraph : P2MSStyle

@property (nonatomic) PARAGRAPH_STYLE style;
@property (nonatomic, retain) NSMutableDictionary *attributeValues;

@end



@interface P2MSParagraphs : NSObject

@property (nonatomic, retain) NSMutableArray *paragraphs;
@property (nonatomic, retain) P2MSParagraph *current_paragraph;
@property (nonatomic, retain) NSString *text;

- (void)applyParagraphStyle:(PARAGRAPH_STYLE)style toRange:(NSRange)selected_range;
- (void)replaceParagraphStlyeAtRange:(NSRange)selected_range withText:(NSString *)text;
- (void)deleteRange:(NSRange)selected_range;
- (void)renderParagraphs;
- (void)updateCurrentParagraphForPosition:(NSInteger)postion;
- (void)clearAll;

@end