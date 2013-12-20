//
//  P2MSIndexedPosition.m
//  P2MSTextView
//
//  Created by P2MS on 17/5/13.
//  Copyright (c) 2013 Pyae Phyo MS. All rights reserved.
//

#import "P2MSIndexedPosition.h"

@implementation P2MSIndexedPosition

+ (instancetype)positionWithIndex:(NSUInteger)index
{    
    P2MSIndexedPosition *indexedPosition = [[P2MSIndexedPosition alloc] init];
    indexedPosition.index = index;
    return indexedPosition;
}


@end
