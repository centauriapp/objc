//
//  CentauriTimestamp.m
//  Centauri
//
//  Created by Steve Madsen on 6/2/13.
//  Copyright (c) 2013 Light Year Software, LLC
//

#import "CentauriTimestamp.h"

@implementation CentauriTimestamp

+ (NSString *) ISO8601Timestamp
{
    return [self ISO8601TimestampFromDate:[NSDate date]];
}

+ (NSString *) ISO8601TimestampFromDate:(NSDate *)date
{
    static NSDateFormatter *formatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        formatter.dateFormat = @"yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'SSS'Z'";
        formatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
    });

    return [formatter stringFromDate:date];
}

@end
