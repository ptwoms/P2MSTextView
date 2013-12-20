//
//  P2MSIndexedRange.h
//  P2MSTextView
//
//  Created by P2MS on 17/5/13.
//  Copyright (c) 2013 Pyae Phyo MS. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface P2MSIndexedRange : UITextRange

@property (nonatomic) NSRange range;

+ (instancetype)indexedRangeWithRange:(NSRange)range;

@end
