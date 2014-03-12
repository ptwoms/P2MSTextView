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
@property (nonatomic, retain) P2MSHTMLNode *parent;
@property (nonatomic) NSRange range;

@end


@interface P2MSHTMLReferenceTable : NSObject

@property (nonatomic, retain) NSDictionary *textFormatReference;
@property (nonatomic, retain) NSDictionary *paragraphFormatReference;

+ (P2MSHTMLReferenceTable *)sharedInstance;

@end


@interface P2MSHTMLOperation : NSObject

+ (NSMutableArray *)getHTMLNodes:(NSString *)htmlString withParent:(P2MSHTMLNode *)parentNode;
+ (void)convertNode:(P2MSHTMLNode **)parentNode toParaAttributes:(NSMutableArray **)paraSet toAttributes:(NSMutableArray **)attrArr andLinks:(NSMutableSet **)allLinks;

@end