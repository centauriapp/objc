//
//  CentauriSanitizer.m
//  Centauri
//
//  Created by Steve Madsen on 6/6/13.
//  Copyright (c) 2013 Light Year Software, LLC
//

#import "CentauriSanitizer.h"
#import "CentauriTimestamp.h"

@implementation CentauriSanitizer

+ (id) sanitize:(id)object
{
    if ([object isKindOfClass:[NSArray class]])
    {
        return [self sanitizeArray:object];
    }
    else if ([object isKindOfClass:[NSDictionary class]])
    {
        return [self sanitizeDictionary:object];
    }

    return nil;
}

+ (NSArray *) sanitizeArray:(NSArray *)array
{
    NSMutableArray *sanitizedArray = [NSMutableArray array];

    for (id object in array)
    {
        if ([object isKindOfClass:[NSString class]] || [object isKindOfClass:[NSNumber class]])
        {
            [sanitizedArray addObject:object];
        }
        else if ([object isKindOfClass:[NSDate class]])
        {
            [sanitizedArray addObject:[CentauriTimestamp ISO8601TimestampFromDate:object]];
        }
    }

    if ([array isKindOfClass:[NSMutableArray class]])
    {
        return sanitizedArray;
    }
    else
    {
        return [sanitizedArray copy];
    }
}

+ (NSDictionary *) sanitizeDictionary:(NSDictionary *)dictionary
{
    NSMutableDictionary *sanitizedDictionary = [NSMutableDictionary dictionary];

    [dictionary enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        if ([key isKindOfClass:[NSString class]])
        {
            if ([obj isKindOfClass:[NSString class]] || [obj isKindOfClass:[NSNumber class]])
            {
                sanitizedDictionary[key] = obj;
            }
            else if ([obj isKindOfClass:[NSDate class]])
            {
                sanitizedDictionary[key] = [CentauriTimestamp ISO8601TimestampFromDate:obj];
            }
        }
    }];

    if ([dictionary isKindOfClass:[NSMutableDictionary class]])
    {
        return sanitizedDictionary;
    }
    else
    {
        return [sanitizedDictionary copy];
    }
}

@end
