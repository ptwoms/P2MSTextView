//
//  P2MSFunctions.m
//  P2MSTextView
//
//  Created by PYAE PHYO MYINT SOE on 27/8/13.
//  Copyright (c) 2013 Pyae Phyo MS. All rights reserved.
//

#import "P2MSFunctions.h"

@implementation P2MSFunctions


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
