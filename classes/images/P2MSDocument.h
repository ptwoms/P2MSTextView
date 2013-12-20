//
//  P2MSDocument.h
//  P2MSTextView
//
//  Created by P2MS on 28/5/13.
//  Copyright (c) 2013 Pyae Phyo MS. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum {
    TEXT_FORMAT_NOT_SET = 0,
    TEXT_FORMAT_NONE = 1,
    TEXT_BOLD = 2,
    TEXT_ITALIC = 4,
    TEXT_UNDERLINE = 8,
    TEXT_STRIKE_THROUGH = 16,
    TEXT_HIGHLIGHT = 32,
    TEXT_LINK = 64
}TEXT_FORMAT;

typedef enum {
    TEXT_FONT_SIMPLIFY,
    TEXT_FONT_PLAIN_TEXT
}
TEXT_FONT_STYLE;

typedef enum{
    TEXT_SECTION = 100,
    TEXT_SUBSECTION,
    TEXT_PARAGRAPH,
    TEXT_BULLET,
    TEXT_NUMBERING,
    TEXT_CONTAINER,
    TEXT_BLOCK_QUOTE
}PARAGRAPH_FORMAT;

@interface P2MSFormat : NSObject
@property (nonatomic) NSRange formatRange;
@end

@interface P2MSTextFormat : P2MSFormat
@property (nonatomic) TEXT_FORMAT txtFormat;
@end

@interface P2MSParagraph : P2MSFormat
@property (nonatomic) PARAGRAPH_FORMAT paraFormat;
@end

@interface P2MSLink : P2MSFormat
@property (nonatomic, retain) NSString *linkURL;
@end
