//
//  P2MSIndexedRange.m
//  P2MSTextView
//
//  Created by PYAE PHYO MYINT SOE on 3/12/13.
//  Copyright (c) 2013 PYAE PHYO MYINT SOE. All rights reserved.
//

#import "P2MSIndexedRange.h"
#import "P2MSIndexedPosition.h"

//https://developer.apple.com/library/ios/documentation/uikit/reference/UITextRange_Class/UITextRange_Class.pdf

@implementation P2MSIndexedRange

+ (instancetype)indexedRangeWithRange:(NSRange)range
{
    if (range.location == NSNotFound)return nil;
    
    P2MSIndexedRange *indexedRange = [[P2MSIndexedRange alloc] init];
    indexedRange.range = range;
    return indexedRange;
}

- (UITextPosition *)start
{
    return [P2MSIndexedPosition positionWithIndex:_range.location];
}

- (UITextPosition *)end
{
	return [P2MSIndexedPosition positionWithIndex:(_range.location + _range.length)];
}

-(BOOL)isEmpty
{
    return (_range.length == 0);
}

@end
