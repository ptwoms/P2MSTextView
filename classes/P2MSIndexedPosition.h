//
//  P2MSIndexedPosition.h
//  P2MSTextView
//
//  Created by PYAE PHYO MYINT SOE on 3/12/13.
//  Copyright (c) 2013 PYAE PHYO MYINT SOE. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface P2MSIndexedPosition : UITextPosition

@property (nonatomic) NSUInteger index;
@property (nonatomic) id <UITextInputDelegate> inputDelegate;

+ (instancetype)positionWithIndex:(NSUInteger)index;


@end
