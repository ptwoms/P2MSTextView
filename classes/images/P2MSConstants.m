//
//  P2MSConstants.m
//  P2MSTextView
//
//  Created by PYAE PHYO MYINT SOE on 15/8/13.
//  Copyright (c) 2013 Pyae Phyo MS. All rights reserved.
//

#import "P2MSConstants.h"

@implementation P2MSConstants

+ (UIColor *)caretColor{//[UIColor colorWithRed:0.259f green:0.420f blue:0.949f alpha:1.0f]
    return [UIColor colorWithRed:0.3176 green:0.41568 blue:0.9294 alpha:0.9];
}

+ (UIColor *)spellingColor{
    return [UIColor colorWithRed:1.000f green:0.851f blue:0.851f alpha:1.0f];
}

+ (UIColor *)selectionColor{
    return [UIColor colorWithRed:0.25 green:0.50 blue:1.0 alpha:0.3];
}

+ (UIColor *)highlightColor{
    return [UIColor yellowColor];
}

//+ (NSString *)normalFontName{
//    return @"HelveticaNeue";
//}
//
//+ (NSString *)boldFontName{
//    return @"HelveticaNeue-Bold";
//}
//
//+ (NSString *)italicFontName{
//    return @"HelveticaNeue-Italic";
//}
//
//+ (NSString *)boldItalicFontName{
//    return @"HelveticaNeue-BoldItalic";
//}

@end
