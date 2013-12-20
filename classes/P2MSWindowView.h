//
//  P2MSWindowView.h
//  P2MSTextView
//
//  Created by PYAE PHYO MYINT SOE on 3/12/13.
//  Copyright (c) 2013 PYAE PHYO MYINT SOE. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface P2MSWindowView : UIView

@property (nonatomic, retain) UIImage *textImage;

@end


@interface P2MSMagnifyView : P2MSWindowView

@end

@interface P2MSLoupeView : P2MSWindowView

@end