//
//  CentauriTimestamp.h
//  Centauri
//
//  Created by Steve Madsen on 6/2/13.
//  Copyright (c) 2013 Light Year Software, LLC
//

#import <Foundation/Foundation.h>

@interface CentauriTimestamp : NSObject

+ (NSString *) ISO8601Timestamp;
+ (NSString *) ISO8601TimestampFromDate:(NSDate *)date;

@end
