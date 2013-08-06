//
//  CentauriSession.m
//  Centauri
//
//  Created by Steve Madsen on 5/15/13.
//  Copyright (c) 2013 Light Year Software, LLC
//

#import <UIKit/UIKit.h>
#include <mach/mach_types.h>
#include <pthread.h>
#include <sys/sysctl.h>

#import "CentauriSession.h"
#import "CentauriBuffer.h"
#import "CentauriWorker.h"
#import "CentauriTimestamp.h"
#import "CentauriTransmitter.h"
#import "CentauriDevLog.h"

extern NSString * const CentauriLibraryVersion;

@implementation CentauriSession
{
    BOOL _transmitInProgress;
}

- (void) encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:self.appToken forKey:@"appToken"];
    [aCoder encodeObject:self.info forKey:@"info"];
    [aCoder encodeObject:self.userID forKey:@"userID"];
    [aCoder encodeObject:self.uuid forKey:@"uuid"];
    [aCoder encodeObject:self.beginDate forKey:@"beginDate"];
    [aCoder encodeObject:self.lastActivity forKey:@"lastActivity"];
    [aCoder encodeObject:self.suspendedDate forKey:@"suspendedDate"];
    [aCoder encodeBool:self.invalid forKey:@"invalid"];
    [aCoder encodeObject:self.endDate forKey:@"endDate"];
    [aCoder encodeBool:self.beginPosted forKey:@"beginPosted"];
    [aCoder encodeBool:self.endPosted forKey:@"endPosted"];
    [aCoder encodeObject:self.unpostedBuffers forKey:@"unpostedBuffers"];
    [aCoder encodeInteger:self.bufferSequenceNumber forKey:@"bufferSequenceNumber"];
}

- (id) initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self)
    {
        self.appToken = [aDecoder decodeObjectForKey:@"appToken"];
        self.info = [aDecoder decodeObjectForKey:@"info"];
        self.userID = [aDecoder decodeObjectForKey:@"userID"];
        self.uuid = [aDecoder decodeObjectForKey:@"uuid"];
        self.beginDate = [aDecoder decodeObjectForKey:@"beginDate"];
        self.lastActivity = [aDecoder decodeObjectForKey:@"lastActivity"];
        self.suspendedDate = [aDecoder decodeObjectForKey:@"suspendedDate"];
        self.endDate = [aDecoder decodeObjectForKey:@"endDate"];
        self.invalid = [aDecoder decodeBoolForKey:@"invalid"];
        self.beginPosted = [aDecoder decodeBoolForKey:@"beginPosted"];
        self.endPosted = [aDecoder decodeBoolForKey:@"endPosted"];
        self.unpostedBuffers = [aDecoder decodeObjectForKey:@"unpostedBuffers"];
        self.bufferSequenceNumber = [aDecoder decodeIntegerForKey:@"bufferSequenceNumber"];
    }

    return self;
}

- (id) initWithAppToken:(NSString *)appToken info:(NSDictionary *)info userID:(NSString *)userID
{
    self = [super init];
    if (self)
    {
        self.appToken = appToken;
        self.info = info;
        self.userID = userID;
        self.beginDate = [NSDate date];
        self.lastActivity = self.beginDate;

        CFUUIDRef uuidRef = CFUUIDCreate(NULL);
        self.uuid = CFBridgingRelease(CFUUIDCreateString(NULL, uuidRef));
        CFRelease(uuidRef);

        self.bufferSequenceNumber = 0;
        self.unpostedBuffers = [NSMutableArray array];
    }

    return self;
}

- (NSString *) description
{
    return [NSString stringWithFormat:@"<%@: %p  %@  began=%@, duration=%.0f, suspended=%@, ended=%@, %lu unposted buffers, transmitting=%@>", [self class], self, self.uuid, self.beginDate, [self duration], self.suspendedDate ? self.suspendedDate : @"NO", self.endDate ? self.endDate : @"NO", (unsigned long)[self.unpostedBuffers count], _transmitInProgress ? @"YES" : @"NO"];
}

- (NSTimeInterval) duration
{
    if (self.invalid)
    {
        return 0;
    }
    else if (self.endDate == nil)
    {
        return -[self.beginDate timeIntervalSinceNow];
    }
    else
    {
        return [self.endDate timeIntervalSinceDate:self.beginDate];
    }
}

- (void) suspend
{
    if (!self.invalid)
    {
        self.suspendedDate = [NSDate date];
        self.lastActivity = self.suspendedDate;
        [self freezeAndCleanBuffers];
    }
}

- (void) freezeAndCleanBuffers
{
    NSMutableArray *emptyBuffers = [NSMutableArray array];
    for (CentauriBuffer *buffer in self.unpostedBuffers)
    {
        if (buffer.frozen == NO)
        {
            if (buffer.bytesBuffered > 0)
            {
                [buffer freeze];
            }
            else
            {
                [buffer cleanup];
                [emptyBuffers addObject:buffer];
            }
        }
    }

    [self.unpostedBuffers removeObjectsInArray:emptyBuffers];
}

- (NSTimeInterval) idleSeconds
{
    NSTimeInterval seconds = 0;

    if (self.suspendedDate != nil)
    {
        seconds = [[NSDate date] timeIntervalSinceDate:self.suspendedDate];
    }

    return seconds;
}

- (void) resume
{
    self.suspendedDate = nil;
    self.lastActivity = [NSDate date];
}

- (void) invalidate
{
    CentauriDevLog(@"Session %@: invalidating", self.uuid);
    self.invalid = YES;

    for (CentauriBuffer *buffer in self.unpostedBuffers)
    {
        [buffer cleanup];
    }
    [self.unpostedBuffers removeAllObjects];
}

- (void) end:(BOOL)abnormal
{
    if (!self.invalid)
    {
        CentauriDevLog(@"Session %@: ending", self.uuid);
        if (abnormal)
        {
            CentauriDevLog(@"Session %@: abnormal end; last activity was %@", self.uuid, self.lastActivity);
        }

        self.endDate = abnormal ? self.lastActivity : [NSDate date];
        self.suspendedDate = nil;
        [self freezeAndCleanBuffers];
    }
}

- (void) sendToServerWithCompletion:(void (^)(BOOL))block
{
    CentauriDevLog(@"Session %@: sending to server", self.uuid);

    CentauriTransmitter *transmitter = [CentauriTransmitter sharedTransmitter];

    if (!_invalid)
    {
        self.lastActivity = [NSDate date];

        if (_transmitInProgress)
        {
            CentauriDevLog(@"Early exit: a transmit is already in progress");
            return;
        }

        _transmitInProgress = YES;

        if (!self.beginPosted)
        {
            CentauriDevLog(@"Session %@: POST session create", self.uuid);
            [transmitter queueMethod:@"POST" path:@"sessions.json" parameters:[self beginPostParameters] completion:^(TransmitStatus status) {
                CentauriDevLog(@"Session %@: POST complete status=%d session create", self.uuid, status);
                switch (status)
                {
                    case TransmitStatusSuccess:
                        self.beginPosted = YES;
                        [self sendToServerWithCompletion:block];
                        break;

                    case TransmitStatusTemporaryFailure:
                        break;

                    case TransmitStatusPermanentFailure:
                        [self invalidate];
                        break;
                }
            }];
        }
        else
        {
            NSString *path = [NSString stringWithFormat:@"sessions/%@/log_lines.json", self.uuid];
            for (CentauriBuffer *buffer in [self.unpostedBuffers copy])
            {
                if (buffer.bytesBuffered > 0)
                {
                    CentauriDevLog(@"Session %@: POST buffer %@", self.uuid, buffer);
                    [buffer freeze];
                    [transmitter queueMethod:@"POST" path:path stream:[buffer inputStream] completion:^(TransmitStatus status) {
                        CentauriDevLog(@"Session %@: POST complete success=%d buffer %@", self.uuid, status, buffer);
                        switch (status)
                        {
                            case TransmitStatusSuccess:
                            case TransmitStatusPermanentFailure:
                                [self.unpostedBuffers removeObject:buffer];
                                [buffer cleanup];
                                break;
                                
                            case TransmitStatusTemporaryFailure:
                                break;
                        }
                    }];
                }
            }
            if ([[self.unpostedBuffers lastObject] bytesBuffered] > 0 && self.endDate == nil)
            {
                [self startNewBuffer];
            }

            if (self.suspendedDate)
            {
                CentauriDevLog(@"Session %@: POST session update (suspended)", self.uuid);
                path = [NSString stringWithFormat:@"sessions/%@.json", self.uuid];
                [transmitter queueMethod:@"PATCH" path:path parameters:@{ @"session": @{ @"duration": @(self.duration) }} completion:nil];
            }

            if (self.endDate && !self.endPosted)
            {
                CentauriDevLog(@"Session %@: POST session update (ended)", self.uuid);
                path = [NSString stringWithFormat:@"sessions/%@.json", self.uuid];
                [transmitter queueMethod:@"PATCH" path:path parameters:@{ @"session": @{ @"duration": @(self.duration) }} completion:^(TransmitStatus status) {
                    CentauriDevLog(@"Session %@: POST complete success=%d session update (ended)", self.uuid, status);
                    switch (status)
                    {
                        case TransmitStatusSuccess:
                            self.endPosted = YES;
                            break;

                        case TransmitStatusTemporaryFailure:
                            break;

                        case TransmitStatusPermanentFailure:
                            [self invalidate];
                            break;
                    }
                }];
            }
        }
    }
    
    [transmitter queueMarker:^{
        _transmitInProgress = NO;
        if (block)
        {
            block(self.endPosted || self.invalid);
        }
    }];
}

- (NSDictionary *) beginPostParameters
{
    NSMutableDictionary *session = [NSMutableDictionary dictionary];
    session[@"uuid"] = self.uuid;
    session[@"started_at"] = [CentauriTimestamp ISO8601TimestampFromDate:self.beginDate];
    if (self.userID && ![self.userID isEqualToString:@""])
    {
        session[@"user_unique_id"] = self.userID;
    }

    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    info[@"_OS"] = @"iOS";
    info[@"_OS Version"] = [[UIDevice currentDevice] systemVersion];
    NSDictionary *infoPlist = [[NSBundle mainBundle] infoDictionary];
    info[@"_App Version"] = [infoPlist objectForKey:(NSString *)kCFBundleVersionKey];
    info[@"_Library Version"] = CentauriLibraryVersion;

    size_t size;
    sysctlbyname("hw.machine", NULL, &size, NULL, 0);
    char *machine = malloc(size);
    sysctlbyname("hw.machine", machine, &size, NULL, 0);
    info[@"_Hardware Model"] = @(machine);
    free(machine);

    info[@"_Locale"] = [[NSLocale currentLocale] localeIdentifier];
    info[@"_Time Zone"] = [[NSTimeZone localTimeZone] name];

    session[@"session_info"] = info;

    return @{ @"session": session };
}

- (void) cleanup
{
    CentauriDevLog(@"Session %@: cleaning up", self.uuid);
    for (CentauriBuffer *buffer in self.unpostedBuffers)
    {
        [buffer cleanup];
    }
}

- (void) startNewBuffer
{
    self.bufferSequenceNumber = self.bufferSequenceNumber + 1;
    CentauriBuffer *buffer = [[CentauriBuffer alloc] initWithSessionUUID:self.uuid sequenceNumber:self.bufferSequenceNumber];
    [self.unpostedBuffers addObject:buffer];
    CentauriDevLog(@"Session %@: started new buffer %@", self.uuid, buffer);
}

- (BOOL) bufferMessage:(NSDictionary *)message
{
    BOOL shouldFlush = NO;

    if (!self.invalid)
    {
        self.lastActivity = [NSDate date];

        CentauriBuffer *buffer = [self.unpostedBuffers lastObject];

        if (buffer == nil || buffer.frozen)
        {
            shouldFlush = buffer.frozen;
            [self startNewBuffer];
            buffer = [self.unpostedBuffers lastObject];
        }

        [buffer addMessage:message];
        CentauriDevLog(@"Session %@: message added to %@", self.uuid, buffer);

        if (buffer.bytesBuffered >= self.maximumBufferSize)
        {
            CentauriDevLog(@"Session %@: buffer reached maximum size", self.uuid);
            [self startNewBuffer];
            shouldFlush = YES;
        }
    }

    return shouldFlush;
}

@end
