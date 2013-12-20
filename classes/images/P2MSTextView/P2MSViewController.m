//
//  P2MSViewController.m
//  P2MSTextView
//
//  Created by P2MS on 17/5/13.
//  Copyright (c) 2013 Pyae Phyo MS. All rights reserved.
//

#import "P2MSViewController.h"

@interface P2MSViewController (){
    P2MSTextView *textView;
}

@end

@implementation P2MSViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	
    textView = [[P2MSTextView alloc]initWithFrame:CGRectMake(0, 70, 320, 200)];
    textView.backgroundColor = [UIColor whiteColor];
    textView.textViewDelegate = self;
    textView.inputAccessoryView = [self inputAccessoryView];
    [self.view addSubview:textView];
    [textView becomeFirstResponder];
    
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeContactAdd];
    btn.frame = CGRectMake(0, 0, 30, 30);
    [btn addTarget:self action:@selector(exportHTML:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:btn];
    
    NSString *androidStr = @"Fn\nHdbs d\nType\nClick\n";
//
//    NSLog(@"Final Constructed String");
//    NSString *finalStr = [P2MSTextView parseFromAndroidHTMLString:[androidStr stringByReplacingOccurrencesOfString:@"<br>" withString:@"\n"]];
//    NSLog(@"%@", finalStr);
//    textView.editable = NO;
//    [textView importHTMLString:androidStr];
    
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)exportHTML:(id)sender{
    
    NSString *htmlString = [textView exportHTMLString];
    NSLog(@"%@", htmlString);
    [textView importHTMLString:htmlString];
}


- (UIView *)inputAccessoryView{
    CGSize curSize = [UIScreen mainScreen].bounds.size;
    CGFloat curWidth = UIInterfaceOrientationIsPortrait([UIDevice currentDevice].orientation)?curSize.width:curSize.height;
    UIView *view = [[UIView alloc]initWithFrame:CGRectMake(0, 0, curWidth, 30)];
    view.backgroundColor = [UIColor colorWithWhite:0.7 alpha:0.4];
    UIView *placeholder = [[UIView alloc]initWithFrame:CGRectMake(curWidth-100, 0, 80, 30)];
    placeholder.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [view addSubview:placeholder];
    
    UIButton *kb = [UIButton buttonWithType:UIButtonTypeCustom];
    [kb setBackgroundImage:[UIImage imageNamed:@"alphabetKB"] forState:UIControlStateNormal];
    kb.frame = CGRectMake(0, 0, 40, 30);
    kb.tag = 0;
    [kb addTarget:textView action:@selector(toggleFormattingKeyboard) forControlEvents:UIControlEventTouchUpInside];
    [placeholder addSubview:kb];
    UIButton *alpha = [UIButton buttonWithType:UIButtonTypeCustom];
    [alpha setBackgroundImage:[UIImage imageNamed:@"keyboard_icon"] forState:UIControlStateNormal];
    alpha.tag = 1;
    alpha.frame = CGRectMake(40, 0, 40, 30);
    [alpha addTarget:textView action:@selector(toggleNormalKeyboard) forControlEvents:UIControlEventTouchUpInside];
    [placeholder addSubview:alpha];
    return view;
}

#pragma mark P2MSTextViewDelegate

- (BOOL)p2msTextViewShouldBeginEditing:(P2MSTextView *)textView {
    return YES;
}

- (BOOL)p2msTextViewShouldEndEditing:(P2MSTextView *)textView {
    return YES;
}

- (void)p2msTextViewDidBeginEditing:(P2MSTextView *)textView {
}

- (void)p2msTextViewDidEndEditing:(P2MSTextView *)textView {
}

- (void)p2msTextViewDidChange:(P2MSTextView *)textView {
    
}

- (void)p2msTextViewLinkClicked:(P2MSTextView *)textView andLink:(P2MSLink *)link{
    NSLog(@"Link Clicked %@", link.linkURL);
}

- (void)p2msTextView:(P2MSTextView*)textView didSelectURL:(NSURL *)URL {
    
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation{
    return YES;
}


@end
