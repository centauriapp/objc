//
//  CentauriTransmitter.h
//  Centauri
//
//  Created by Steve Madsen on 5/15/13.
//  Copyright (c) 2013 Light Year Software, LLC
//

#import <Foundation/Foundation.h>

@class CentauriWorker;

typedef NS_ENUM(NSInteger, TransmitStatus)
{
    TransmitStatusSuccess,
    TransmitStatusTemporaryFailure,
    TransmitStatusPermanentFailure
};

@interface CentauriTransmitter : NSObject

@property (nonatomic) CentauriWorker *completionWorker;
@property (copy, nonatomic) NSString *baseURLString;
@property (copy, nonatomic) NSMutableDictionary *headers;
@property (readonly, nonatomic) BOOL paused;

+ (instancetype) sharedTransmitter;

- (void) pause;
- (void) resume;
- (void) setValue:(NSString *)value forHTTPHeader:(NSString *)header;
- (void) queueMethod:(NSString *)method path:(NSString *)path parameters:(NSDictionary *)parameters completion:(void (^)(TransmitStatus status))block;
- (void) queueMethod:(NSString *)method path:(NSString *)path stream:(NSInputStream *)stream completion:(void (^)(TransmitStatus status))block;
- (void) queueMarker:(void (^)(void))block;

@end
