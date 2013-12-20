//
//  P2MSIndexedPosition.h
//  P2MSTextView
//
//  Created by P2MS on 17/5/13.
//  Copyright (c) 2013 Pyae Phyo MS. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface P2MSIndexedPosition : UITextPosition

@property (nonatomic) NSUInteger index;
@property (nonatomic) id <UITextInputDelegate> inputDelegate;

+ (instancetype)positionWithIndex:(NSUInteger)index;

@end
