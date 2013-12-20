//
//  P2MSIndexedRange.h
//  P2MSTextView
//
//  Created by PYAE PHYO MYINT SOE on 3/12/13.
//  Copyright (c) 2013 PYAE PHYO MYINT SOE. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface P2MSIndexedRange : UITextRange

@property (nonatomic) NSRange range;

+ (instancetype)indexedRangeWithRange:(NSRange)range;

@end
