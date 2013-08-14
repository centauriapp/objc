//
//  CentauriBufferTests.m
//  Centauri
//
//  Created by Steve Madsen on 5/23/13.
//  Copyright (c) 2013 Light Year Software, LLC
//

#import "Kiwi.h"
#import "CentauriBuffer.h"

static NSString * NSStringFromMemoryStream(NSOutputStream *stream)
{
    NSData *data = [stream propertyForKey:NSStreamDataWrittenToMemoryStreamKey];
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

@interface CentauriBuffer ()
- (NSOutputStream *) outputStream;
@end

SPEC_BEGIN(CentauriBufferTests)

describe(@"NSCoding", ^{
    __block CentauriBuffer *buffer;

    beforeEach(^{
        buffer = [[CentauriBuffer alloc] initWithSessionUUID:@"uuid" sequenceNumber:123];
        buffer.bytesBuffered = 234;
        buffer.frozen = YES;
    });

    it(@"serializes/deserializes sessionUUID", ^{
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:buffer];
        CentauriBuffer *newBuffer = [NSKeyedUnarchiver unarchiveObjectWithData:data];
        [[newBuffer.sessiondUUID should] equal:buffer.sessiondUUID];
    });

    it(@"serializes/deserializes sequenceNumber", ^{
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:buffer];
        CentauriBuffer *newBuffer = [NSKeyedUnarchiver unarchiveObjectWithData:data];
        [[theValue(newBuffer.sequenceNumber) should] equal:theValue(buffer.sequenceNumber)];
    });

    it(@"serializes/deserializes sessionUUID", ^{
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:buffer];
        CentauriBuffer *newBuffer = [NSKeyedUnarchiver unarchiveObjectWithData:data];
        [[newBuffer.bufferFilePath should] equal:buffer.bufferFilePath];
    });

    it(@"serializes/deserializes bytesBuffered", ^{
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:buffer];
        CentauriBuffer *newBuffer = [NSKeyedUnarchiver unarchiveObjectWithData:data];
        [[theValue(newBuffer.bytesBuffered) should] equal:theValue(buffer.bytesBuffered)];
    });

    it(@"serializes/deserializes frozen", ^{
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:buffer];
        CentauriBuffer *newBuffer = [NSKeyedUnarchiver unarchiveObjectWithData:data];
        [[theValue(newBuffer.frozen) should] equal:theValue(buffer.frozen)];
    });
});

describe(@"-addMessage:", ^{
    __block CentauriBuffer *buffer;
    __block NSOutputStream *output;

    beforeEach(^{
        buffer = [[CentauriBuffer alloc] initWithSessionUUID:@"uuid" sequenceNumber:1];
    });

    context(@"with the first message", ^{
        it(@"creates the buffer file", ^{
            [buffer addMessage:@{}];
            BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:buffer.bufferFilePath];
            [[theValue(exists) should] beYes];
            [buffer cleanup];
        });
        
        it(@"adds the prolog", ^{
            output = [NSOutputStream outputStreamToMemory];
            [buffer stub:@selector(outputStream) andReturn:output];
            [output open];
            [buffer addMessage:@{}];
            NSString *string = NSStringFromMemoryStream(output);
            [[string should] startWithString:@"{\"log_lines\":["];
        });
    });

    context(@"with the second and subsequent messages", ^{
        beforeEach(^{
            buffer.bytesBuffered = 1;
            output = [NSOutputStream outputStreamToMemory];
            [buffer stub:@selector(outputStream) andReturn:output];
            [output open];
        });

        it(@"adds the message separator", ^{
            [buffer addMessage:@{}];
            NSString *string = NSStringFromMemoryStream(output);
            [[string should] startWithString:@","];
        });
    });

    it(@"adds the message", ^{
        output = [NSOutputStream outputStreamToMemory];
        [buffer stub:@selector(outputStream) andReturn:output];
        [output open];
        [buffer addMessage:@{@"key": @"value"}];
        NSString *string = NSStringFromMemoryStream(output);
        [[string should] endWithString:@"{\"key\":\"value\"}"];
    });

    it(@"increments bytesBuffered", ^{
        output = [NSOutputStream outputStreamToMemory];
        [buffer stub:@selector(outputStream) andReturn:output];
        [output open];
        NSUInteger oldBytesBuffered = buffer.bytesBuffered;
        [buffer addMessage:@{@"key": @"value"}];
        [[theValue(buffer.bytesBuffered > oldBytesBuffered) should] beYes];
    });

    context(@"with a frozen buffer", ^{
        beforeEach(^{
            [buffer freeze];
        });

        it(@"asserts", ^{
            [[theBlock(^{
                [buffer addMessage:@{}];
            }) should] raise];
        });
    });
});

describe(@"-freeze", ^{
    __block CentauriBuffer *buffer;
    __block NSOutputStream *output;

    beforeEach(^{
        buffer = [[CentauriBuffer alloc] initWithSessionUUID:@"uuid" sequenceNumber:1];
        output = [NSOutputStream outputStreamToMemory];
        [buffer stub:@selector(outputStream) andReturn:output];
    });

    context(@"when not frozen", ^{
        context(@"with messages in the buffer", ^{
            beforeEach(^{
                buffer.bytesBuffered = 1;
                [output open];
                [buffer freeze];
            });

            it(@"adds the epilog", ^{
                NSString *string = NSStringFromMemoryStream(output);
                [[string should] equal:@"]}"];
            });
        });

        context(@"with no messages in the buffer", ^{
            beforeEach(^{
                [buffer freeze];
            });

            it(@"does not add the epilog", ^{
                NSString *string = NSStringFromMemoryStream(output);
                [[string should] equal:@""];
            });
        });

        it(@"marks the buffer frozen", ^{
            [buffer freeze];
            [[theValue(buffer.frozen) should] beYes];
        });
    });

    context(@"when already frozen", ^{
        beforeEach(^{
            buffer.bytesBuffered = 1;
            buffer.frozen = YES;
            [output open];
            [buffer freeze];
        });

        it(@"does not add the epilog", ^{
            NSString *string = NSStringFromMemoryStream(output);
            [[string should] equal:@""];
        });
    });
});

describe(@"-inputStream", ^{
    __block CentauriBuffer *buffer;

    beforeEach(^{
        buffer = [[CentauriBuffer alloc] initWithSessionUUID:@"uuid" sequenceNumber:1];
        [buffer addMessage:@{}];
        [buffer freeze];
    });

    afterEach(^{
        [buffer cleanup];
    });

    it(@"returns an input stream with the accumulated messages", ^{
        [[buffer inputStream] shouldNotBeNil];
    });

    it(@"contains the accumulated messages in JSON format", ^{
        NSInputStream *stream = [buffer inputStream];
        [stream open];
        uint8_t bytes[1024];
        NSInteger length = [stream read:bytes maxLength:1024];
        NSString *string = [[NSString alloc] initWithBytes:bytes length:length encoding:NSUTF8StringEncoding];
        [[string should] equal:@"{\"log_lines\":[{}]}"];
    });

    it(@"asserts with an unfrozen buffer", ^{
        buffer = [[CentauriBuffer alloc] initWithSessionUUID:@"uuid" sequenceNumber:1];
        [buffer addMessage:@{}];
        [[theBlock(^{
            [buffer inputStream];
        }) should] raise];
    });
});

describe(@"-cleanup", ^{
    __block CentauriBuffer *buffer;
    __block NSString *path;

    beforeEach(^{
        buffer = [[CentauriBuffer alloc] initWithSessionUUID:@"uuid" sequenceNumber:1];
        [buffer addMessage:@{}];
        path = [buffer.bufferFilePath copy];
    });

    it(@"deletes the buffer file", ^{
        [buffer cleanup];
        BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:path];
        [[theValue(exists) should] beNo];
    });
});

SPEC_END
