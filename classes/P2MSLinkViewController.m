//
//  P2MSLinkViewController.m
//  P2MSTextView
//
//  Created by PYAE PHYO MYINT SOE on 17/12/13.
//  Copyright (c) 2013 PYAE PHYO MYINT SOE. All rights reserved.
//

#import "P2MSLinkViewController.h"
#import "P2MSGlobalFunctions.h"

@interface P2MSLinkViewController (){
    UIView *doneLayer;
    UITextField *curActiveField;
    BOOL showTitle, isUpdate;
}
@end

@implementation P2MSLinkViewController

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        showTitle = YES;
        isUpdate = NO;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    UIView *view = [[UIView alloc]initWithFrame:self.view.frame];
    view.backgroundColor = [UIColor whiteColor];
    self.tableView.backgroundView = view;
    self.tableView.showsVerticalScrollIndicator = NO;
    UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, 45)];
    UIButton *button = [[UIButton alloc]initWithFrame:CGRectMake(15, 10, 25, 25)];
    [button setBackgroundImage:[UIImage imageNamed:@"button_close"] forState:UIControlStateNormal];
    [button addTarget:self action:@selector(closeView:) forControlEvents:UIControlEventTouchUpInside];
    [headerView addSubview:button];
    CGSize curSize = self.view.bounds.size;
    UIView *customTitleView = [ [UIView alloc] initWithFrame:CGRectMake(0, 44, curSize.width, 1)];
    customTitleView.backgroundColor = [UIColor colorWithWhite:0.8 alpha:0.5];
    [headerView addSubview:customTitleView];
    showTitle = (_linkTitle == nil && _linkRange.location == NSNotFound);
    isUpdate = (_linkURL != nil);
    if (!isUpdate) {
        _linkURL = @"http://";
    }
    
    self.tableView.tableHeaderView = headerView;

    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
 
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

-(float)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section{
    return 34.0f;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath{
    return 39;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section{
    CGSize curSize = self.view.bounds.size;
    UIView *customTitleView = [ [UIView alloc] initWithFrame:CGRectMake(0, 0, curSize.width, 34)];
    CGFloat leftPadding = (self.view.bounds.size.width>320)?40:10;
    UILabel *titleLabel = [ [UILabel alloc] initWithFrame:CGRectMake(leftPadding, 0, curSize.width- (leftPadding*2), 34)];
    switch (section) {
        case 0:titleLabel.text = @"Link";break;
        case 1:titleLabel.text = @"Link Label";break;
    }
    titleLabel.textColor = [UIColor colorWithRed:0.1333 green:0.22745 blue:0.611765 alpha:1.0];
    titleLabel.font = [UIFont systemFontOfSize:17];
    titleLabel.backgroundColor = [UIColor clearColor];
    [customTitleView addSubview:titleLabel];
    return customTitleView;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView{
    return (showTitle)?3:2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    UITableViewCell *cell;
    CGSize curSize = self.view.bounds.size;
    if ((showTitle && indexPath.section == 2) || (!showTitle && indexPath.section == 1)) {
        static NSString *CellIdentifier1 = @"ButtonCell";
        cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier1];
        if (!cell) {
            cell = [[UITableViewCell alloc]initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier1];
            cell.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.7];
            cell.backgroundView = [[UIView alloc]initWithFrame:CGRectZero];
            UIButton *loginButton = [[UIButton alloc]initWithFrame:CGRectMake(29, 0, 280, 39)];
            loginButton.tag = 6;
            loginButton.center = CGPointMake(self.view.frame.size.width/2, 23);
            [loginButton addTarget:self action:@selector(addLink:) forControlEvents:UIControlEventTouchUpInside];
            [loginButton setBackgroundImage:[P2MSGlobalFunctions imageWithColor:[UIColor lightGrayColor]] forState:UIControlStateNormal];
            [loginButton setBackgroundImage:[P2MSGlobalFunctions imageWithColor:[UIColor grayColor]] forState:UIControlStateHighlighted];
            loginButton.layer.borderColor = [UIColor colorWithWhite:0.8 alpha:0.8].CGColor;
            loginButton.layer.borderWidth = 1.0;
            loginButton.layer.cornerRadius = 7;
            loginButton.clipsToBounds = YES;
            loginButton.titleLabel.font = [UIFont systemFontOfSize:16];
            [loginButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
            [loginButton setTitleColor:[UIColor whiteColor] forState:UIControlStateHighlighted];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            [cell addSubview:loginButton];
        }
        UIButton *loginButton = (UIButton *)[cell viewWithTag:6];
        [loginButton setTitle:(isUpdate)?@"Update Link":@"Add Link" forState:UIControlStateNormal];
    }else{
        static NSString *CellIdentifier2 = @"TextCell";
        cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier2];
        CGFloat leftPadding = (curSize.width>320)?55:20;
        if (!cell) {
            cell = [[UITableViewCell alloc]initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier2];
            cell.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.7];
            UITextField *textFiled = [[UITextField alloc]initWithFrame:CGRectMake(leftPadding, 1, curSize.width-(leftPadding*2), cell.frame.size.height-5)];
            textFiled.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
            textFiled.font = [UIFont systemFontOfSize:16];
            textFiled.tag = 5;
            textFiled.returnKeyType = UIReturnKeyNext;
            textFiled.clearButtonMode = UITextFieldViewModeWhileEditing;
            textFiled.delegate = self;
            textFiled.inputAccessoryView = [self showDoneLayer];
            [cell addSubview:textFiled];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        }
        UITextField *textFiled = (UITextField *)[cell viewWithTag:5];
        if (indexPath.section) {
            textFiled.text = _linkTitle;
            textFiled.returnKeyType = UIReturnKeyDone;
            textFiled.keyboardType = UIKeyboardTypeAlphabet;
            textFiled.placeholder = @"Optional";
        }else{
            textFiled.text = _linkURL;
            textFiled.returnKeyType = (showTitle)?UIReturnKeyNext:UIReturnKeyDone;
            textFiled.keyboardType = UIKeyboardTypeURL;
        }
    }
    return cell;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
}


#pragma mark Actions
- (IBAction)clickDone:(id)sender{
    if (curActiveField) {
        [curActiveField resignFirstResponder];
    }
}

- (IBAction)closeView:(id)sender{
    if (self.delegate) {
        [_delegate linkViewDidCancel:self];
    }else
        [self dismissModalViewControllerAnimated:YES];
}

- (IBAction)addLink:(id)sender{
    if (curActiveField) {
        [curActiveField resignFirstResponder];
    }
    if (self.delegate) {
        [_delegate linkViewDidClose:self];
    }else
        [self dismissModalViewControllerAnimated:YES];
}

#pragma mark textFieldDelegate
- (void)textFieldDidBeginEditing:(UITextField *)textField{
    curActiveField = textField;
}

- (void)textFieldDidEndEditing:(UITextField *)textField{
    curActiveField = nil;
    if ([textField.placeholder isEqualToString:@"Optional"]) {
        _linkTitle = textField.text;
    }else{
        _linkURL = textField.text;
    }
}

- (BOOL)textFieldShouldClear:(UITextField *)textField{
    return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField{
    if (showTitle) {
        if ([textField.placeholder isEqualToString:@"Optional"]) {
            [textField resignFirstResponder];
            [self addLink:nil];
        }else{
            NSIndexPath *indexPathToGo = [NSIndexPath indexPathForRow:0 inSection:1];
            UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPathToGo];
            if (!cell) {
                [self.tableView scrollToRowAtIndexPath:indexPathToGo atScrollPosition:UITableViewScrollPositionNone animated:NO];
                cell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:1]];
            }
            UITextField *txtField = (UITextField *)[cell viewWithTag:5];
            [txtField becomeFirstResponder];
        }
    }else{
        [textField resignFirstResponder];
        [self addLink:nil];
    }
    return NO;
}

#pragma mark misc
- (UIView *)showDoneLayer{
    if ([[UIDevice currentDevice]userInterfaceIdiom] == UIUserInterfaceIdiomPad)return nil;
    if (!doneLayer) {
        doneLayer = [[UIView alloc]initWithFrame:CGRectMake(0, 0, 320, 35)];
        [doneLayer setBackgroundColor:[UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:0.8]];
        UIButton *doneBtn = [[UIButton alloc]initWithFrame:CGRectMake(self.view.bounds.size.width-40, 3,36, 28)];
        [doneBtn setBackgroundImage:[UIImage imageNamed:@"keyboard_down_arrow"] forState:UIControlStateNormal];
        [doneBtn addTarget:self action:@selector(clickDone:) forControlEvents:UIControlEventTouchUpInside];
        [doneLayer addSubview:doneBtn];
    }
    return doneLayer;
}


@end
