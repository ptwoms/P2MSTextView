//
//  P2MSTextViewExampleViewController.m
//  P2MSTextView
//
//  Created by PYAE PHYO MYINT SOE on 8/12/13.
//  Copyright (c) 2013 PYAE PHYO MYINT SOE. All rights reserved.
//

#import "P2MSTextViewExampleViewController.h"

@interface P2MSTextViewExampleViewController (){
    P2MSTextView *textView;
    UIButton *kb, *alpha;
}

@end

@implementation P2MSTextViewExampleViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    textView = [[P2MSTextView alloc]initWithFrame:CGRectMake(0, 10, 320, 100)];
    textView.backgroundColor = [UIColor colorWithWhite:0.9 alpha:0.9];
    textView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    textView.textViewDelegate = self;
    textView.inputAccessoryView = [self inputAccessoryView];
    [textView importHTMLString:@"Hello \n\n<b>W<strike>o</strike><u>r</u><mark>l</mark><i>d</i></b>"];
//    textView.plainText = @"Hello World";
    [self.view addSubview:textView];
    [textView becomeFirstResponder];
    
    UIButton *button = [UIButton buttonWithType:UIButtonTypeInfoDark];
    button.frame = CGRectMake(10, 150, 30, 30);
    [button addTarget:self action:@selector(exportString:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:button];
    
	// Do any additional setup after loading the view.
}

- (IBAction)exportString:(id)sender{
    NSLog(@"HTML String :%@", [textView exportHTMLString]);
    NSLog(@"Plain Text :%@", textView.plainText);
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (UIView *)inputAccessoryView{
    CGSize curSize = [UIScreen mainScreen].bounds.size;
    CGFloat curWidth = UIInterfaceOrientationIsPortrait([UIDevice currentDevice].orientation)?curSize.width:curSize.height;
    UIView *view = [[UIView alloc]initWithFrame:CGRectMake(0, 0, curWidth, 30)];
    view.backgroundColor = [UIColor colorWithWhite:0.7 alpha:0.4];
    UIView *placeholder = [[UIView alloc]initWithFrame:CGRectMake(curWidth-100, 0, 80, 30)];
    placeholder.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [view addSubview:placeholder];
    
    alpha = [UIButton buttonWithType:UIButtonTypeCustom];
    [alpha setBackgroundImage:[UIImage imageNamed:@"alphabetKB-dim"] forState:UIControlStateNormal];
    alpha.frame = CGRectMake(0, 0, 40, 30);
    [alpha addTarget:self action:@selector(showFormatKB:) forControlEvents:UIControlEventTouchUpInside];
    [placeholder addSubview:alpha];
    kb = [UIButton buttonWithType:UIButtonTypeCustom];
    [kb setBackgroundImage:[UIImage imageNamed:@"keyboard_icon-hover"] forState:UIControlStateNormal];
    kb.frame = CGRectMake(40, 0, 40, 30);
    [kb addTarget:self action:@selector(showDefaultKB:) forControlEvents:UIControlEventTouchUpInside];
    [placeholder addSubview:kb];
    return view;
}

- (IBAction)showDefaultKB:(id)sender{
    [textView showKeyboard:KEYBOARD_TYPE_DEFAULT];
    if ([textView isFirstResponder]) {
        [sender setImage:[UIImage imageNamed:@"keyboard_icon-hover"] forState:UIControlStateNormal];
        [alpha setImage:[UIImage imageNamed:@"alphabetKB-dim"] forState:UIControlStateNormal];
        
    }
}

- (IBAction)showFormatKB:(id)sender{
    [textView showKeyboard:KEYBOARD_TYPE_FORMAT];
    if ([textView isFirstResponder]) {
        [kb setImage:[UIImage imageNamed:@"keyboard_icon"] forState:UIControlStateNormal];
        [sender setImage:[UIImage imageNamed:@"alphabetKB"] forState:UIControlStateNormal];
    }
}

- (void)p2msTextViewDidChange:(P2MSTextView *)mytextView{
}

@end
