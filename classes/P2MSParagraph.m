//
//  P2MSParagraph.m
//  P2MSTextView
//
//  Created by PYAE PHYO MYINT SOE on 22/2/14.
//  Copyright (c) 2014 PYAE PHYO MYINT SOE. All rights reserved.
//

#import "P2MSParagraph.h"

@implementation P2MSParagraph


@end


@interface P2MSParagraphs(){
    NSInteger cur_paragraph_index;
}

@end

@implementation P2MSParagraphs

- (id)init{
    self = [super init];
    if (self) {
        _paragraphs = [NSMutableArray array];
        cur_paragraph_index = 0;
        [self initializeParagraphs];
    }
    return self;
}


- (void)initializeParagraphs{
    [_paragraphs removeAllObjects];
    P2MSParagraph *first_paragraph = [[P2MSParagraph alloc]init];
    first_paragraph.style = PARAGRAPH_NORMAL;
    first_paragraph.styleRange = NSMakeRange(0, 0);
    [_paragraphs addObject:first_paragraph];
    _current_paragraph = first_paragraph;
}

- (void)updateCurrentParagraphForPosition:(NSInteger)postion{
    if (postion >= _text.length) {
        cur_paragraph_index = _paragraphs.count-1;
        _current_paragraph = [_paragraphs objectAtIndex:cur_paragraph_index];
    }else if (NSLocationInRange(postion, _current_paragraph.styleRange)) {
        //Nothing to do
    }else{
        int i = 0;
        for (P2MSParagraph *cur_para in _paragraphs) {
            if (NSLocationInRange(postion, cur_para.styleRange)) {
                cur_paragraph_index = i;
                _current_paragraph = [_paragraphs objectAtIndex:i];
                break;
            }else{
                i++;
            }
        }
    }
//    NSLog(@"Current Paragraph index %d for text %@", cur_paragraph_index, _text);
}

- (void)updateLocationsFromCurrentParagraph{
    NSInteger para_count = _paragraphs.count;
    NSUInteger lastIndex = _current_paragraph.styleRange.location + _current_paragraph.styleRange.length;
    for (int i = cur_paragraph_index+1; i < para_count; i++) {
        P2MSParagraph *paragraph = [_paragraphs objectAtIndex:i];
        paragraph.styleRange = NSMakeRange(lastIndex, paragraph.styleRange.length);
        lastIndex += paragraph.styleRange.length;
    }
}

- (void)deleteRange:(NSRange)selected_range{
    [self deleteRangeWithoutUpdatingLocation:selected_range];
    [self updateLocationsFromCurrentParagraph];
}

- (void)deleteRangeWithoutUpdatingLocation:(NSRange)selected_range{
    NSMutableArray *paragraphs_to_remove = [NSMutableArray array];
    if (selected_range.length) { //current and subsequent paragraphs
        int paragraph_count = _paragraphs.count;
        
        P2MSParagraph *part_1 = nil, *part_2 = nil;
        for (int i = cur_paragraph_index; i < paragraph_count; i++) {
            P2MSParagraph *paragraph_to_test = [_paragraphs objectAtIndex:i];
            NSRange intersect_range = NSIntersectionRange(paragraph_to_test.styleRange, selected_range);
            if (intersect_range.length == paragraph_to_test.styleRange.length) {
                //delete test paragraph
                [paragraphs_to_remove addObject:paragraph_to_test];
            }else{
                if(intersect_range.length > 0){
                    //combine test paragraph and current paragraph and style to current style
                    NSInteger additioanl_location_to_move = (intersect_range.location == paragraph_to_test.styleRange.location) * intersect_range.length;
                    paragraph_to_test.styleRange = NSMakeRange(paragraph_to_test.styleRange.location + additioanl_location_to_move, paragraph_to_test.styleRange.length - intersect_range.length);
                    paragraph_to_test.style = _current_paragraph.style;
                    if (part_1) {
                        part_2 = paragraph_to_test;
                    }else{
                        part_1 = paragraph_to_test;
                    }
                }else
                    break;
            }
        }
        if (part_2) {
            part_1.styleRange = NSMakeRange(part_1.styleRange.location, part_2.styleRange.length+part_1.styleRange.length);
            [paragraphs_to_remove addObject:part_2];
        }else{
            part_1.styleRange = NSMakeRange(selected_range.location, part_1.styleRange.length);
        }
        
        for (P2MSParagraph *paragraph_to_remove in paragraphs_to_remove) {
            [_paragraphs removeObject:paragraph_to_remove];
        }
        
        if (_paragraphs.count) {
            _current_paragraph = [_paragraphs objectAtIndex:cur_paragraph_index];
        }else{
            P2MSParagraph *newParagraph = [[P2MSParagraph alloc]init];
            newParagraph.styleRange = NSMakeRange(0, 0);
            newParagraph.style = _current_paragraph.style;
            [_paragraphs addObject:newParagraph];
            cur_paragraph_index = 0;
            _current_paragraph = [_paragraphs objectAtIndex:cur_paragraph_index];
        }
    }
}

- (void)replaceParagraphStlyeAtRange:(NSRange)selected_range withText:(NSString *)inserted_text{
    if (selected_range.length > 0) {
        [self deleteRangeWithoutUpdatingLocation:selected_range];
    }
    if ([inserted_text isEqualToString:@"\n"]) {
        NSInteger cur_para_length;
        if (selected_range.location >= _text.length) {//add new paragraph
            P2MSParagraph *newParagraph = [[P2MSParagraph alloc]init];
            newParagraph.styleRange = NSMakeRange(selected_range.location+1, 0);
            newParagraph.style = _current_paragraph.style;
            [_paragraphs addObject:newParagraph];
            cur_para_length = _current_paragraph.styleRange.length + 1;//inserted_text.length;
        }else{//split current paragraph into two
            //second paragraph
            NSInteger second_para_loc = selected_range.location+1;
            NSInteger second_para_length = _current_paragraph.styleRange.location + _current_paragraph.styleRange.length - selected_range.location;
            P2MSParagraph *second_paragraph = [[P2MSParagraph alloc]init];
            second_paragraph.style = _current_paragraph.style;
            second_paragraph.styleRange = NSMakeRange(second_para_loc, second_para_length);

            //frist paragraph
            cur_para_length = selected_range.location - _current_paragraph.styleRange.location + 1;
            [_paragraphs insertObject:second_paragraph atIndex:cur_paragraph_index+1];
        }
        _current_paragraph.styleRange = NSMakeRange(_current_paragraph.styleRange.location, cur_para_length);
        cur_paragraph_index++;
        _current_paragraph = [_paragraphs objectAtIndex:cur_paragraph_index];
    }else{
        NSRange newRange = _current_paragraph.styleRange;
        newRange.length += inserted_text.length;
        _current_paragraph.styleRange = newRange;
    }
    [self updateLocationsFromCurrentParagraph];
}


- (void)applyParagraphStyle:(PARAGRAPH_STYLE)style  toRange:(NSRange)selected_range{
    if (selected_range.length == 0) {
        _current_paragraph.style = [self getParagraphStyle:style forParagraph:_current_paragraph];
    }else{
        for (P2MSParagraph *paragraph in _paragraphs) {
            if (NSIntersectionRange(paragraph.styleRange, selected_range).length > 0) {
                paragraph.style = [self getParagraphStyle:style forParagraph:paragraph];
            }
        }
    }
}

- (void)clearAll{
    [_paragraphs removeAllObjects];
    _current_paragraph = nil;
    cur_paragraph_index = -1;
}

- (PARAGRAPH_STYLE)getParagraphStyle:(PARAGRAPH_STYLE)style forParagraph:(P2MSParagraph *)paragraph{
    switch (style) {
        case PARAGRAPH_BULLET:
        case PARAGRAPH_NUMBERING:
        {
            return (paragraph.style == style)?PARAGRAPH_NORMAL:style;
        }break;
        default:
            return style;
    }
}

- (void)renderParagraphs{
    
}

@end