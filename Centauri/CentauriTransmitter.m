//
//  CentauriTransmitter.m
//  Centauri
//
//  Created by Steve Madsen on 5/15/13.
//  Copyright (c) 2013 Light Year Software, LLC
//

#import <UIKit/UIKit.h>

#import "Centauri.h"
#import "CentauriTransmitter.h"
#import "CentauriWorker.h"
#import "CentauriDevLog.h"

@interface Centauri ()
- (void) saveState;
@end

typedef NS_ENUM(NSInteger, JobType)
{
    JobTypeParameterDictionary,
    JobTypeStream,
    JobTypeMarker
};

@implementation CentauriTransmitter
{
    NSURL *_baseURL;
    NSMutableArray *_queue;
    BOOL _jobInProgress;
    UIBackgroundTaskIdentifier _backgroundTask;
}

+ (instancetype) sharedTransmitter
{
    static CentauriTransmitter *transmitter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        transmitter = [[[self class] alloc] init];
    });

    return transmitter;
}

- (id) init
{
    self = [super init];
    if (self)
    {
        self.completionWorker = [[CentauriWorker alloc] initWithName:@"com.centauriapp.transmitter-completion"];
        _headers = [NSMutableDictionary dictionary];
        _queue = [NSMutableArray array];
        _backgroundTask = UIBackgroundTaskInvalid;
    }

    return self;
}

- (void) setBaseURLString:(NSString *)baseURLString
{
    if (![baseURLString hasSuffix:@"/"])
    {
        [NSException raise:NSInvalidArgumentException format:@"The base URL must include a trailing slash."];
    }

    _baseURLString = [baseURLString copy];
    _baseURL = [NSURL URLWithString:_baseURLString];
}

- (void) pause
{
    _paused = YES;
}

- (void) resume
{
    _paused = NO;
    [self runNextJob];
}

- (void) setValue:(NSString *)value forHTTPHeader:(NSString *)header
{
    if (value)
    {
        self.headers[header] = value;
    }
    else
    {
        [self.headers removeObjectForKey:header];
    }
}

- (void) queueMethod:(NSString *)method path:(NSString *)path parameters:(NSDictionary *)parameters completion:(void (^)(TransmitStatus status))block
{
    NSMutableDictionary *job = [NSMutableDictionary dictionary];
    job[@"type"] = @(JobTypeParameterDictionary);
    job[@"method"] = method;
    job[@"path"] = path;
    if (parameters)
    {
        job[@"parameters"] = parameters;
    }
    if (block)
    {
        job[@"block"] = [block copy];
    }
    [self addJob:job];
}

- (void) queueMethod:(NSString *)method path:(NSString *)path stream:(NSInputStream *)stream completion:(void (^)(TransmitStatus status))block
{
    NSMutableDictionary *job = [NSMutableDictionary dictionary];
    job[@"type"] = @(JobTypeStream);
    job[@"method"] = method;
    job[@"path"] = path;
    job[@"stream"] = stream;
    if (block)
    {
        job[@"block"] = [block copy];
    }
    [self addJob:job];
}

- (void) queueMarker:(void (^)(void))block
{
    [self addJob:@{ @"type": @(JobTypeMarker), @"block": [block copy] }];
}

- (void) addJob:(NSDictionary *)job
{
    [_queue addObject:job];
    if ([_queue count] == 1 && !_jobInProgress)
    {
        [self runNextJob];
    }
}

- (void) runNextJob
{
    if (_jobInProgress)
    {
        return;
    }

next_job:
    if ([_queue count] == 0 || _paused)
    {
        [[UIApplication sharedApplication] endBackgroundTask:_backgroundTask];
        _backgroundTask = UIBackgroundTaskInvalid;
        return;
    }

    if (_backgroundTask == UIBackgroundTaskInvalid)
    {
        _backgroundTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
            [self pause];
            [[Centauri sharedInstance] saveState];
            [[UIApplication sharedApplication] endBackgroundTask:_backgroundTask];
            _backgroundTask = UIBackgroundTaskInvalid;
        }];
    }

    NSDictionary *job = _queue[0];
    [_queue removeObjectAtIndex:0];

    NSNumber *type = job[@"type"];
    switch ((JobType)[type integerValue])
    {
        case JobTypeParameterDictionary:
        {
            id parameters = job[@"parameters"];
            NSInputStream *stream;
            if (parameters)
            {
                NSError *error;
                NSData *data = [NSJSONSerialization dataWithJSONObject:parameters options:0 error:&error];
                stream = [NSInputStream inputStreamWithData:data];
            }
            [self startHTTPMethod:job[@"method"] path:job[@"path"] bodyStream:stream completion:job[@"block"]];
            break;
        }

        case JobTypeStream:
            [self startHTTPMethod:job[@"method"] path:job[@"path"] bodyStream:job[@"stream"] completion:job[@"block"]];
            break;

        case JobTypeMarker:
        {
            void (^block)(void) = job[@"block"];
            _jobInProgress = YES;
            block();
            _jobInProgress = NO;
            goto next_job;
        }
    }
}

- (void) startHTTPMethod:(NSString *)method path:(NSString *)path bodyStream:(NSInputStream *)stream completion:(void (^)(BOOL success))block
{
    _jobInProgress = YES;

    NSURL *url = [NSURL URLWithString:path relativeToURL:_baseURL];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = method;
    request.networkServiceType = NSURLNetworkServiceTypeBackground;
    [request setAllHTTPHeaderFields:_headers];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    request.HTTPBodyStream = stream;

    void (^connectionCompletion)(NSURLResponse *, NSData *, NSError *) = ^(NSURLResponse *response, NSData *data, NSError *error) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        CentauriDevLog(@"Transmitter: response: %d bytes, status %d, error %@", [data length], httpResponse.statusCode, error);

        if (block)
        {
            TransmitStatus status;
            if (error == nil && httpResponse.statusCode >= 200 && httpResponse.statusCode < 300)
            {
                status = TransmitStatusSuccess;
            }
            else if ((httpResponse.statusCode >= 400 && httpResponse.statusCode < 500) || ([error.domain isEqualToString:NSURLErrorDomain] && error.code == kCFURLErrorUserCancelledAuthentication))
            {
                status = TransmitStatusPermanentFailure;
            }
            else
            {
                status = TransmitStatusTemporaryFailure;
            }

            block(status);
        }
        _jobInProgress = NO;
        [self runNextJob];
    };

    CentauriDevLog(@"Transmitter: request %@ %@", method, path);
    
#ifndef SPECS
    [NSURLConnection sendAsynchronousRequest:request queue:self.completionWorker.queue completionHandler:connectionCompletion];
#else
    NSURLResponse *response;
    NSError *error;
    NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    connectionCompletion(response, data, error);
#endif
}

@end
