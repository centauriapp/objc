//
//  CentauriBuffer.m
//  Centauri
//
//  Created by Steve Madsen on 5/15/13.
//  Copyright (c) 2013 Light Year Software, LLC
//

#import "CentauriBuffer.h"
#import "CentauriDevLog.h"

@implementation CentauriBuffer
{
    NSOutputStream *_outputStream;
}

- (void) encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:self.sessiondUUID forKey:@"uuid"];
    [aCoder encodeInteger:self.sequenceNumber forKey:@"sequenceNumber"];
    [aCoder encodeObject:self.bufferFilePath forKey:@"bufferFilePath"];
    [aCoder encodeInteger:self.bytesBuffered forKey:@"bytesBuffered"];
    [aCoder encodeBool:self.frozen forKey:@"frozen"];
}

- (id) initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self)
    {
        self.sessiondUUID = [aDecoder decodeObjectForKey:@"uuid"];
        self.sequenceNumber = [aDecoder decodeIntegerForKey:@"sequenceNumber"];
        self.bufferFilePath = [aDecoder decodeObjectForKey:@"bufferFilePath"];
        self.bytesBuffered = [aDecoder decodeIntegerForKey:@"bytesBuffered"];
        self.frozen = [aDecoder decodeBoolForKey:@"frozen"];
    }

    return self;
}

- (id) initWithSessionUUID:(NSString *)uuid sequenceNumber:(NSInteger)sequenceNumber
{
    self = [super init];
    if (self)
    {
        self.sessiondUUID = uuid;
        self.sequenceNumber = sequenceNumber;
        NSString *bufferFileName = [NSString stringWithFormat:@"com.centauriapp,%@,%d", self.sessiondUUID, self.sequenceNumber];
        self.bufferFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:bufferFileName];
    }

    return self;
}

- (NSString *) description
{
    return [NSString stringWithFormat:@"<%@: %p sequence=%ld bytes=%lu, frozen=%@>", [self class], self, (long)self.sequenceNumber, (unsigned long)self.bytesBuffered, self.frozen ? @"YES" : @"NO"];
}

- (NSOutputStream *) outputStream
{
    if (_outputStream == nil)
    {
        _outputStream = [NSOutputStream outputStreamToFileAtPath:self.bufferFilePath append:YES];
        [_outputStream open];
    }

    return _outputStream;
}

- (void) addMessage:(NSDictionary *)message
{
    NSAssert(self.frozen == NO, @"Cannot add a message to a frozen buffer");

    if (self.frozen)
    {
        return;
    }
    
    NSOutputStream *stream = [self outputStream];
    if (self.bytesBuffered == 0)
    {
        [stream open];
        NSData *prolog = [@"{\"log_lines\":[" dataUsingEncoding:NSUTF8StringEncoding];
        [stream write:[prolog bytes] maxLength:[prolog length]];
    }
    else
    {
        [stream write:(uint8_t *)"," maxLength:1];
    }

    NSError *error;
    NSData *json = [NSJSONSerialization dataWithJSONObject:message options:0 error:&error];
    [stream write:[json bytes] maxLength:[json length]];

    self.bytesBuffered = self.bytesBuffered + [json length];
}

- (void) freeze
{
    if (self.bytesBuffered > 0)
    {
        NSOutputStream *stream = [self outputStream];
        [stream write:(uint8_t *)"]}" maxLength:2];
        [stream close];
    }

    self.frozen = YES;
}

- (NSInputStream *) inputStream
{
    NSAssert(self.frozen == YES, @"Cannot retrieve the input stream for an unfrozen buffer");

    return self.frozen ? [NSInputStream inputStreamWithFileAtPath:self.bufferFilePath] : nil;
}

- (void) cleanup
{
    NSError *error;
    [[NSFileManager defaultManager] removeItemAtPath:self.bufferFilePath error:&error];
}

@end
