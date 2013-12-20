//
//  P2MSIndexedPosition.m
//  P2MSTextView
//
//  Created by PYAE PHYO MYINT SOE on 3/12/13.
//  Copyright (c) 2013 PYAE PHYO MYINT SOE. All rights reserved.
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
