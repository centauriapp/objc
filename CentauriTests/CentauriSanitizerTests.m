//
//  CentauriSanitizerTests.m
//  Centauri
//
//  Created by Steve Madsen on 6/6/13.
//  Copyright (c) 2013 Light Year Software, LLC
//

#import "Kiwi.h"
#import "CentauriSanitizer.h"
#import "CentauriTimestamp.h"

SPEC_BEGIN(CentauriSanitizerTests)

describe(@"+sanitize:", ^{
    context(@"when passed an array", ^{
        __block NSArray *array;

        beforeEach(^{
            array = @[ @"string", @123, @YES, [NSDate date], @[@1], @{ @"key": @"value" } ];
        });

        it(@"accepts scalar values", ^{
            NSArray *sanitizedArray = [CentauriSanitizer sanitize:array];
            [[sanitizedArray[0] should] equal:@"string"];
            [[sanitizedArray[1] should] equal:@123];
            [[sanitizedArray[2] should] equal:@YES];
        });

        it(@"converts dates to ISO8601 formatted strings", ^{
            [[CentauriTimestamp should] receive:@selector(ISO8601TimestampFromDate:) andReturn:@"iso8601"];
            NSArray *sanitizedArray = [CentauriSanitizer sanitize:array];
            [[sanitizedArray[3] should] equal:@"iso8601"];
        });

        it(@"strips out everything else", ^{
            NSArray *sanitizedArray = [CentauriSanitizer sanitize:array];
            [[sanitizedArray should] haveCountOf:4];
        });

        it(@"returns an array", ^{
            id result = [CentauriSanitizer sanitize:array];
            [[result should] beKindOfClass:[NSArray class]];
        });
    });

    context(@"when passed a mutable array", ^{
        __block NSMutableArray *array;

        beforeEach(^{
            array = [@[ @"string", @123, @YES, [NSDate date], @[@1], @{ @"key": @"value" } ] mutableCopy];
        });
        
        it(@"returns a mutable array", ^{
            id result = [CentauriSanitizer sanitize:array];
            [[result should] beKindOfClass:[NSMutableArray class]];
        });
    });

    context(@"when passed a dictionary", ^{
        __block NSDictionary *dictionary;

        beforeEach(^{
            dictionary = @{ @"string": @"value", @"number": @123, @"bool": @YES, @"date": [NSDate date], @"array": @[@1], @"dictionary": @{ @"key": @"value" }, @1: @"non-string key" };
        });

        it(@"strips out non-string keys", ^{
            NSDictionary *sanitizedDictionary = [CentauriSanitizer sanitize:dictionary];
            [sanitizedDictionary[@1] shouldBeNil];
        });

        it(@"accepts scalar values", ^{
            NSDictionary *sanitizedDictionary = [CentauriSanitizer sanitize:dictionary];
            [[sanitizedDictionary[@"string"] should] equal:@"value"];
            [[sanitizedDictionary[@"number"] should] equal:@123];
            [[sanitizedDictionary[@"bool"] should] equal:@YES];
        });

        it(@"converts dates to ISO8601 formatted strings", ^{
            [[CentauriTimestamp should] receive:@selector(ISO8601TimestampFromDate:) andReturn:@"iso8601"];
            NSDictionary *sanitizedDictionary = [CentauriSanitizer sanitize:dictionary];
            [[sanitizedDictionary[@"date"] should] equal:@"iso8601"];
        });

        it(@"strips out everything else", ^{
            NSDictionary *sanitizedDictionary = [CentauriSanitizer sanitize:dictionary];
            [sanitizedDictionary[@"data"] shouldBeNil];
        });

        it(@"returns a dictionary", ^{
            id result = [CentauriSanitizer sanitize:dictionary];
            [[result should] beKindOfClass:[NSDictionary class]];
        });
    });

    context(@"when passed a mutable dictionary", ^{
        __block NSMutableDictionary *dictionary;

        beforeEach(^{
            dictionary = [@{ @"string": @"value", @"number": @123, @"bool": @YES, @"date": [NSDate date], @"array": @[@1], @"dictionary": @{ @"key": @"value" }, @1: @"non-string key" } mutableCopy];
        });
        
        it(@"returns a mutable dictionary", ^{
            id result = [CentauriSanitizer sanitize:dictionary];
            [[result should] beKindOfClass:[NSMutableDictionary class]];
        });
    });
});

SPEC_END
