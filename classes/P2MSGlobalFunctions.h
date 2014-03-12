//
//  P2MSGlobalFunctions.h
//  P2MSTextView
//
//  Created by PYAE PHYO MYINT SOE on 3/12/13.
//  Copyright (c) 2013 PYAE PHYO MYINT SOE. All rights reserved.
//

#import <Foundation/Foundation.h>

#define kAnimationDuration 0.15f

typedef enum {
    TEXT_FORMAT_NOT_SET = 0,
    TEXT_FORMAT_NONE = 1,
    TEXT_BOLD = 2,
    TEXT_ITALIC = 4,
    TEXT_UNDERLINE = 8,
    TEXT_STRIKE_THROUGH = 16,
    TEXT_HIGHLIGHT = 32,
    TEXT_LINK = 64,
    TEXT_FONT_NAME = 128,
    TEXT_FONT_SIZE = 256,
    TEXT_FONT_COLOR = 512
}TEXT_ATTRIBUTE;


@interface P2MSGlobalFunctions : NSObject

+ (UIColor *)caretColor;
+ (UIColor *)spellingColor;
+ (UIColor *)selectionColor;
+ (UIColor *)highlightColor;

+ (UIImage *)imageWithColor:(UIColor *)color;

@end

@interface P2MSStyle : NSObject
@property (nonatomic) NSRange styleRange;
@end

@interface P2MSTextAttribute : P2MSStyle
@property (nonatomic) TEXT_ATTRIBUTE txtAttrib;
@property (nonatomic, retain) NSMutableDictionary *attributeValues;
@end

//@interface P2MSParagraphStyle : P2MSStyle
//@property (nonatomic) PARAGRAPH_STYLE paraStyle;
//@end

@interface P2MSLink : P2MSStyle
@property (nonatomic, retain) NSString *linkURL;
@end

