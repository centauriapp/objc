//
//  CentauriTimestampTests.m
//  Centauri
//
//  Created by Steve Madsen on 6/2/13.
//  Copyright (c) 2013 Light Year Software, LLC
//

#import "Kiwi.h"
#import "CentauriTimestamp.h"

SPEC_BEGIN(CentauriTimestampTests)

describe(@"+ISO8601Timestamp", ^{
    it(@"returns an ISO8601 formatted string", ^{
        NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
        NSDateComponents *dateComponents = [[NSDateComponents alloc] init];
        dateComponents.year = 2013;
        dateComponents.month = 6;
        dateComponents.day = 2;
        dateComponents.hour = 16;
        dateComponents.minute = 5;
        dateComponents.second = 11;
        dateComponents.timeZone = [NSTimeZone timeZoneWithName:@"Eastern Time (US & Canada)"];
        NSDate *date = [gregorian dateFromComponents:dateComponents];
        [NSDate stub:@selector(date) andReturn:date];
        [[[CentauriTimestamp ISO8601Timestamp] should] equal:@"2013-06-02T20:05:11.000Z"];
    });
});

describe(@"+ISO8601TimestampFromDate:", ^{
    it(@"returns an ISO8601 formatted string", ^{
        NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
        NSDateComponents *dateComponents = [[NSDateComponents alloc] init];
        dateComponents.year = 2013;
        dateComponents.month = 6;
        dateComponents.day = 2;
        dateComponents.hour = 16;
        dateComponents.minute = 5;
        dateComponents.second = 11;
        dateComponents.timeZone = [NSTimeZone timeZoneWithName:@"Eastern Time (US & Canada)"];
        NSDate *date = [gregorian dateFromComponents:dateComponents];
        [[[CentauriTimestamp ISO8601TimestampFromDate:date] should] equal:@"2013-06-02T20:05:11.000Z"];
    });
});

SPEC_END
