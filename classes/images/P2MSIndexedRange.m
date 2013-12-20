//
//  P2MSIndexedRange.m
//  P2MSTextView
//
//  Created by P2MS on 17/5/13.
//  Copyright (c) 2013 Pyae Phyo MS. All rights reserved.
//

#import "P2MSIndexedRange.h"
#import "P2MSIndexedPosition.h"

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
