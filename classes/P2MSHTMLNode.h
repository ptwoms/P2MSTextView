//
//  P2MSHTMLNode.h
//  P2MSTextView
//
//  Created by PYAE PHYO MYINT SOE on 3/12/13.
//  Copyright (c) 2013 PYAE PHYO MYINT SOE. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface P2MSHTMLNode : NSObject

@property(nonatomic, retain) NSString *content, *htmlTag;
@property (nonatomic, retain) NSMutableArray *children;
@property (nonatomic, retain) NSMutableDictionary *attributes;
@property (nonatomic) NSRange range;

@end


@interface P2MSHTMLOperation : NSObject

+ (NSMutableArray *)getHTMLNodes:(NSString *)htmlString;
+ (void)convertNode:(P2MSHTMLNode **)passNode toParaAttributes:(NSMutableSet **)paraSet toAttributes:(NSMutableArray **)attrArr andLinks:(NSMutableSet **)allLinks refDict:(NSDictionary *)dict;

@end