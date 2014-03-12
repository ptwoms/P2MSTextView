//
//  P2MSGlobalFunctions.m
//  P2MSTextView
//
//  Created by PYAE PHYO MYINT SOE on 3/12/13.
//  Copyright (c) 2013 PYAE PHYO MYINT SOE. All rights reserved.
//

#import "P2MSGlobalFunctions.h"

@implementation P2MSGlobalFunctions

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


+ (UIImage *)imageWithColor:(UIColor *)color{
    CGRect rect = CGRectMake(0, 0, 1, 1);
    // Create a 1 by 1 pixel context
    UIGraphicsBeginImageContextWithOptions(rect.size, NO, 0);
    [color setFill];
    UIRectFill(rect);   // Fill it with the color provided
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

@end

@implementation P2MSStyle

@end

@implementation P2MSTextAttribute

@end

@implementation P2MSLink

@end
