//
//  P2MSLinkViewController.h
//  P2MSTextView
//
//  Created by PYAE PHYO MYINT SOE on 17/12/13.
//  Copyright (c) 2013 PYAE PHYO MYINT SOE. All rights reserved.
//

#import <UIKit/UIKit.h>

@class P2MSLinkViewController;

@protocol P2MSLinkViewControllerDelegate <NSObject>

- (void) linkViewDidClose:(P2MSLinkViewController *)viewController;
- (void) linkViewDidCancel:(P2MSLinkViewController *)viewController;

@end

@interface P2MSLinkViewController : UITableViewController<UITextFieldDelegate>

@property (nonatomic, retain) NSString *linkURL, *linkTitle;
@property (nonatomic) NSRange linkRange;
@property (nonatomic, unsafe_unretained) id<P2MSLinkViewControllerDelegate> delegate;

@end
