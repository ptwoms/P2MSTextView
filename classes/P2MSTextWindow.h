//
//  P2MSTextWindow.h
//  P2MSTextView
//
//  Created by PYAE PHYO MYINT SOE on 3/12/13.
//  Copyright (c) 2013 PYAE PHYO MYINT SOE. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "P2MSWindowView.h"

typedef enum {
    P2MS_TEXT_LOUPE = 1,
    P2MS_TEXT_MAGNIFY
}P2MS_TEXTWINDOW_TYPE;


@interface P2MSTextWindow : UIWindow{
    P2MSWindowView   *windowView;
}

@property(nonatomic,assign) P2MS_TEXTWINDOW_TYPE windowType;
@property(nonatomic,readonly,getter=isShowing) BOOL showing;

- (void)renderContentView:(UIView*)view fromRect:(CGRect)rect;
- (void)showTextWindowFromView:(UIView*)view rect:(CGRect)rect;
- (void)hideTextWindow:(BOOL)animated;

+ (P2MSTextWindow *)getTextWindow:(P2MSTextWindow *)textWindow;

@end
