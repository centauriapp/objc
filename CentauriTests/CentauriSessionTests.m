//
//  CentauriSessionTests.m
//  Centauri
//
//  Created by Steve Madsen on 5/20/13.
//  Copyright (c) 2013 Light Year Software, LLC
//

#import "Kiwi.h"
#import "CentauriSession.h"
#import "CentauriBuffer.h"
#import "CentauriTransmitter.h"
#import "CentauriTimestamp.h"

SPEC_BEGIN(CentauriSessionTests)

describe(@"initialization", ^{
    __block CentauriSession *session;

    beforeEach(^{
        session = [[CentauriSession alloc] initWithAppToken:@"token" info:@{ @"key": @"value" } userID:@"user ID"];
    });

    it(@"creates a random UUID", ^{
        [session.uuid shouldNotBeNil];
        [[session.uuid shouldNot] equal:@""];
    });

    it(@"records the date", ^{
        [session.beginDate shouldNotBeNil];
        [[theValue([session.beginDate timeIntervalSinceNow]) should] beWithin:theValue(0.001) of:theValue(0)];
    });

    it(@"updates lastActivity", ^{
        [session.lastActivity shouldNotBeNil];
        [[theValue([session.lastActivity timeIntervalSinceNow]) should] beWithin:theValue(0.001) of:theValue(0)];
    });

    it(@"saves the app token", ^{
        [[session.appToken should] equal:@"token"];
    });

    it(@"saves the provided session info", ^{
        [[session.info should] equal:@{ @"key": @"value" }];
    });

    it(@"saves the user ID", ^{
        [[session.userID should] equal:@"user ID"];
    });

    it(@"creates an empty array of unposted buffers", ^{
        [[session.unpostedBuffers should] equal:@[]];
    });
});

describe(@"NSCoding", ^{
    __block CentauriSession *session;

    beforeEach(^{
        session = [[CentauriSession alloc] initWithAppToken:@"token" info:@{ @"key": @"value" } userID:@"user ID"];
        session.beginPosted = YES;
        session.lastActivity = [NSDate date];
        session.suspendedDate = [NSDate date];
        session.endDate = [NSDate date];
        session.endPosted = YES;
        session.unpostedBuffers = [@[ @"one", @"two" ] mutableCopy];
        session.bufferSequenceNumber = 123;
        session.invalid = YES;
    });

    it(@"serializes/deserializes the app token", ^{
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:session];
        CentauriSession *newSession = [NSKeyedUnarchiver unarchiveObjectWithData:data];
        [[newSession.appToken should] equal:session.appToken];
    });

    it(@"serializes/deserializes the session info", ^{
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:session];
        CentauriSession *newSession = [NSKeyedUnarchiver unarchiveObjectWithData:data];
        [[newSession.info should] equal:session.info];
    });

    it(@"serializes/deserializes the user ID", ^{
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:session];
        CentauriSession *newSession = [NSKeyedUnarchiver unarchiveObjectWithData:data];
        [[newSession.userID should] equal:session.userID];
    });

    it(@"serializes/deserializes the UUID", ^{
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:session];
        CentauriSession *newSession = [NSKeyedUnarchiver unarchiveObjectWithData:data];
        [[newSession.uuid should] equal:session.uuid];
    });

    it(@"serializes/deserializes the begin date", ^{
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:session];
        CentauriSession *newSession = [NSKeyedUnarchiver unarchiveObjectWithData:data];
        [[newSession.beginDate should] equal:session.beginDate];
    });

    it(@"serializes/deserializes the last activity date", ^{
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:session];
        CentauriSession *newSession = [NSKeyedUnarchiver unarchiveObjectWithData:data];
        [[newSession.lastActivity should] equal:session.lastActivity];
    });

    it(@"serializes/deserializes the suspended date", ^{
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:session];
        CentauriSession *newSession = [NSKeyedUnarchiver unarchiveObjectWithData:data];
        [[newSession.suspendedDate should] equal:session.suspendedDate];
    });

    it(@"serializes/deserializes the invalidated flag", ^{
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:session];
        CentauriSession *newSession = [NSKeyedUnarchiver unarchiveObjectWithData:data];
        [[theValue(newSession.invalid) should] equal:theValue(session.invalid)];
    });

    it(@"serializes/deserializes the end date", ^{
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:session];
        CentauriSession *newSession = [NSKeyedUnarchiver unarchiveObjectWithData:data];
        [[newSession.endDate should] equal:session.endDate];
    });

    it(@"serializes/deserializes the begin POST state", ^{
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:session];
        CentauriSession *newSession = [NSKeyedUnarchiver unarchiveObjectWithData:data];
        [[theValue(newSession.beginPosted) should] equal:theValue(session.beginPosted)];
    });

    it(@"serializes/deserializes the end POST state", ^{
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:session];
        CentauriSession *newSession = [NSKeyedUnarchiver unarchiveObjectWithData:data];
        [[theValue(newSession.endPosted) should] equal:theValue(session.endPosted)];
    });

    it(@"serializes/deserializes the unposted buffers", ^{
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:session];
        CentauriSession *newSession = [NSKeyedUnarchiver unarchiveObjectWithData:data];
        [[newSession.unpostedBuffers should] haveCountOf:[session.unpostedBuffers count]];
    });

    it(@"serializes/deserializes the buffer sequence number", ^{
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:session];
        CentauriSession *newSession = [NSKeyedUnarchiver unarchiveObjectWithData:data];
        [[theValue(newSession.bufferSequenceNumber) should] equal:theValue(session.bufferSequenceNumber)];
    });
});

describe(@"-duration", ^{
    __block CentauriSession *session;

    beforeEach(^{
        session = [[CentauriSession alloc] initWithAppToken:@"token" info:@{} userID:nil];
        session.beginDate = [NSDate dateWithTimeIntervalSinceNow:-10];
    });

    context(@"when not stopped", ^{
        it(@"returns the time elapsed from beginDate to now", ^{
            [[theValue(session.duration) should] beWithin:theValue(0.001) of:theValue(10)];
        });
    });

    context(@"when stopped", ^{
        beforeEach(^{
            session.endDate = [session.beginDate dateByAddingTimeInterval:5];
        });

        it(@"returns the interval between beginDate and endDate", ^{
            [[theValue(session.duration) should] beWithin:theValue(0.001) of:theValue(5)];
        });
    });

    context(@"when invalid", ^{
        beforeEach(^{
            session.invalid = YES;
        });

        it(@"returns 0", ^{
            [[theValue(session.duration) should] equal:theValue(0)];
        });

        it(@"returns 0 even if previously stopped", ^{
            session.endDate = [session.beginDate dateByAddingTimeInterval:5];
            [[theValue(session.duration) should] equal:theValue(0)];
        });
    });
});

describe(@"-suspend", ^{
    __block CentauriSession *session;

    beforeEach(^{
        session = [[CentauriSession alloc] initWithAppToken:@"token" info:@{} userID:nil];
        session.lastActivity = nil;
    });
    
    it(@"records the date", ^{
        [session suspend];
        [session.suspendedDate shouldNotBeNil];
        [[theValue([session.suspendedDate timeIntervalSinceNow]) should] beWithin:theValue(0.001) of:theValue(0)];
    });

    it(@"updates lastActivity", ^{
        [session suspend];
        [session.lastActivity shouldNotBeNil];
        [[theValue([session.lastActivity timeIntervalSinceNow]) should] beWithin:theValue(0.001) of:theValue(0)];
    });

    it(@"freezes any unfrozen, non-empty buffers", ^{
        CentauriBuffer *buffer = [[CentauriBuffer alloc] initWithSessionUUID:session.uuid sequenceNumber:1];
        buffer.bytesBuffered = 1;
        session.unpostedBuffers = [@[ buffer ] mutableCopy];
        [[buffer should] receive:@selector(freeze)];
        [session suspend];
    });

    it(@"cleans up and discards any unfrozen, empty buffers", ^{
        CentauriBuffer *buffer = [[CentauriBuffer alloc] initWithSessionUUID:session.uuid sequenceNumber:1];
        session.unpostedBuffers = [@[ buffer ] mutableCopy];
        [[buffer should] receive:@selector(cleanup)];
        [session suspend];
        [[session.unpostedBuffers should] equal:@[]];
    });

    context(@"when invalid", ^{
        beforeEach(^{
            session.invalid = YES;
        });
        
        it(@"does nothing", ^{
            CentauriBuffer *buffer = [[CentauriBuffer alloc] initWithSessionUUID:session.uuid sequenceNumber:1];
            buffer.bytesBuffered = 1;
            CentauriBuffer *emptyBuffer = [[CentauriBuffer alloc] initWithSessionUUID:session.uuid sequenceNumber:2];
            session.unpostedBuffers = [@[ buffer, emptyBuffer ] mutableCopy];
            [[buffer shouldNot] receive:@selector(freeze)];
            [[emptyBuffer shouldNot] receive:@selector(cleanup)];
            [session suspend];
            [session.suspendedDate shouldBeNil];
            [session.lastActivity shouldBeNil];
        });
    });
});

describe(@"-idleSeconds", ^{
    __block CentauriSession *session;

    beforeEach(^{
        session = [[CentauriSession alloc] initWithAppToken:@"token" info:@{} userID:nil];
    });

    context(@"when suspended", ^{
        beforeEach(^{
            session.suspendedDate = [NSDate dateWithTimeIntervalSinceNow:-1];
        });

        it(@"returns the seconds since suspension", ^{
            [[theValue([session idleSeconds]) should] beWithin:theValue(0.001) of:theValue(1)];
        });
    });

    context(@"when not suspended", ^{
        it(@"returns 0", ^{
            [[theValue([session idleSeconds]) should] equal:theValue(0)];
        });
    });

    context(@"when invalid", ^{
        beforeEach(^{
            session.invalid = YES;
        });
        
        it(@"returns 0", ^{
            [[theValue([session idleSeconds]) should] equal:theValue(0)];
        });
    });
});

describe(@"-resume", ^{
    __block CentauriSession *session;

    beforeEach(^{
        session = [[CentauriSession alloc] initWithAppToken:@"token" info:@{} userID:nil];
        session.lastActivity = nil;
        session.suspendedDate = [NSDate dateWithTimeIntervalSinceNow:-1];
        [session resume];
    });
    
    it(@"clears suspendedDate", ^{
        [session.suspendedDate shouldBeNil];
    });

    it(@"updates lastActivity", ^{
        [session.lastActivity shouldNotBeNil];
        [[theValue([session.lastActivity timeIntervalSinceNow]) should] beWithin:theValue(0.001) of:theValue(0)];
    });
});

describe(@"-invalidate", ^{
    __block CentauriSession *session;
    __block CentauriBuffer *buffer;

    beforeEach(^{
        session = [[CentauriSession alloc] initWithAppToken:@"token" info:@{} userID:nil];
        buffer = [[CentauriBuffer alloc] initWithSessionUUID:session.uuid sequenceNumber:1];
        session.unpostedBuffers = [@[ buffer ] mutableCopy];
    });

    it(@"sets the invalid flag", ^{
        [session invalidate];
        [[theValue(session.invalid) should] beYes];
    });

    it(@"cleans up all unpostedBuffers", ^{
        [[buffer should] receive:@selector(cleanup)];
        [session invalidate];
    });
});

describe(@"-end:", ^{
    __block CentauriSession *session;

    beforeEach(^{
        session = [[CentauriSession alloc] initWithAppToken:@"token" info:@{} userID:nil];
    });

    it(@"nils the suspended date", ^{
        session.suspendedDate = [NSDate date];
        [session end:NO];
        [session.suspendedDate shouldBeNil];
    });

    it(@"freezes any unfrozen, non-empty buffers", ^{
        CentauriBuffer *buffer = [[CentauriBuffer alloc] initWithSessionUUID:session.uuid sequenceNumber:1];
        buffer.bytesBuffered = 1;
        session.unpostedBuffers = [@[ buffer ] mutableCopy];
        [[buffer should] receive:@selector(freeze)];
        [session end:NO];
    });

    it(@"cleans up and discards any unfrozen, empty buffers", ^{
        CentauriBuffer *buffer = [[CentauriBuffer alloc] initWithSessionUUID:session.uuid sequenceNumber:1];
        session.unpostedBuffers = [@[ buffer ] mutableCopy];
        [[buffer should] receive:@selector(cleanup)];
        [session end:NO];
        [[session.unpostedBuffers should] equal:@[]];
    });

    context(@"when ending normally", ^{
        it(@"records the date", ^{
            [session end:NO];
            [session.endDate shouldNotBeNil];
            [[theValue([session.endDate timeIntervalSinceNow]) should] beWithin:theValue(0.001) of:theValue(0)];
        });
    });

    context(@"when ending a session from a previous, abnormal run", ^{
        it(@"records the date of last activity", ^{
            NSDate *thePast = [NSDate dateWithTimeIntervalSinceNow:-10];
            session.lastActivity = thePast;
            [session end:YES];
            [[session.endDate should] equal:thePast];
        });
    });

    context(@"when invalid", ^{
        beforeEach(^{
            session.invalid = YES;
        });
        
        it(@"does nothing", ^{
            CentauriBuffer *buffer = [[CentauriBuffer alloc] initWithSessionUUID:session.uuid sequenceNumber:1];
            buffer.bytesBuffered = 1;
            CentauriBuffer *emptyBuffer = [[CentauriBuffer alloc] initWithSessionUUID:session.uuid sequenceNumber:2];
            session.unpostedBuffers = [@[ buffer, emptyBuffer ] mutableCopy];
            [[buffer shouldNot] receive:@selector(freeze)];
            [[emptyBuffer shouldNot] receive:@selector(cleanup)];
            [session end:NO];
            [session.endDate shouldBeNil];
        });
    });
});

describe(@"-cleanup", ^{
    __block CentauriSession *session;
    __block CentauriBuffer *buffer1, *buffer2;

    beforeEach(^{
        session = [[CentauriSession alloc] initWithAppToken:@"token" info:@{} userID:nil];
        buffer1 = [CentauriBuffer nullMock];
        buffer2 = [CentauriBuffer nullMock];
        session.unpostedBuffers = [@[ buffer1, buffer2 ] mutableCopy];
    });
    
    it(@"cleans up unposted buffers", ^{
        [[buffer1 should] receive:@selector(cleanup)];
        [[buffer2 should] receive:@selector(cleanup)];
        [session cleanup];
    });
});

describe(@"-bufferMessage:", ^{
    __block CentauriSession *session;
    __block CentauriBuffer *buffer;

    beforeEach(^{
        session = [[CentauriSession alloc] initWithAppToken:@"token" info:@{} userID:nil];
        session.lastActivity = nil;
        buffer = [CentauriBuffer nullMock];
        session.maximumBufferSize = 1000;
        session.unpostedBuffers = [@[ [CentauriBuffer mock], buffer ] mutableCopy];
    });

    context(@"when the session is valid", ^{
        it(@"sends the message to the last unposted buffer", ^{
            [[buffer should] receive:@selector(addMessage:) withArguments:@{ @"key": @"value" }];
            [session bufferMessage:@{ @"key": @"value" }];
        });

        it(@"updates lastActivity", ^{
            [session bufferMessage:@{ @"key": @"value" }];
            [session.lastActivity shouldNotBeNil];
            [[theValue([session.lastActivity timeIntervalSinceNow]) should] beWithin:theValue(0.001) of:theValue(0)];
        });

        context(@"when the buffer is full", ^{
            beforeEach(^{
                [buffer stub:@selector(bytesBuffered) andReturn:theValue(session.maximumBufferSize)];
            });

            it(@"creates a new buffer", ^{
                [session bufferMessage:@{ @"key": @"value" }];
                [[session.unpostedBuffers should] haveCountOf:3];
            });

            it(@"returns YES to signal the caller should flush", ^{
                BOOL result = [session bufferMessage:@{ @"key": @"value" }];
                [[theValue(result) should] beYes];
            });
        });

        context(@"when the buffer is frozen", ^{
            beforeEach(^{
                [buffer stub:@selector(frozen) andReturn:theValue(YES)];
            });

            it(@"creates a new buffer", ^{
                [session bufferMessage:@{ @"key": @"value" }];
                [[session.unpostedBuffers should] haveCountOf:3];
            });

            it(@"returns YES to signal the caller should flush", ^{
                BOOL result = [session bufferMessage:@{ @"key": @"value" }];
                [[theValue(result) should] beYes];
            });
        });

        context(@"when there are no unposted buffers", ^{
            beforeEach(^{
                session.unpostedBuffers = [NSMutableArray array];
            });

            it(@"creates a new buffer", ^{
                [session bufferMessage:@{ @"key": @"value" }];
                [[session.unpostedBuffers should] haveCountOf:1];
            });
            
            it(@"returns NO", ^{
                BOOL result = [session bufferMessage:@{ @"key": @"value" }];
                [[theValue(result) should] beNo];
            });
        });
    });
    
    context(@"when the session is invalid", ^{
        beforeEach(^{
            session.invalid = YES;
        });

        it(@"does not add the message", ^{
            [[buffer shouldNot] receive:@selector(addMessage:)];
            [session bufferMessage:@{ @"key": @"value" }];
        });

        it(@"does not create a new buffer", ^{
            session.unpostedBuffers = [NSMutableArray array];
            [session bufferMessage:@{ @"key": @"value" }];
            [[session.unpostedBuffers should] haveCountOf:0];
        });
    });
});

describe(@"sendToServerWithCompletion:", ^{
    __block CentauriSession *session;
    __block CentauriTransmitter *transmitter;

    beforeEach(^{
        session = [[CentauriSession alloc] initWithAppToken:@"token" info:@{} userID:@"user"];
        session.lastActivity = nil;
        transmitter = [CentauriTransmitter nullMock];
        [transmitter stub:@selector(queueMarker:)];
        [CentauriTransmitter stub:@selector(sharedTransmitter) andReturn:transmitter];
    });

    it(@"updates lastActivity", ^{
        session.beginPosted = YES;
        [session sendToServerWithCompletion:nil];
        [session.lastActivity shouldNotBeNil];
        [[theValue([session.lastActivity timeIntervalSinceNow]) should] beWithin:theValue(0.001) of:theValue(0)];
    });

    context(@"when beginPosted is NO", ^{
        beforeEach(^{
            NSDictionary *infoDictionary = @{ (NSString *)kCFBundleVersionKey: @"1.0" };
            [[NSBundle mainBundle] stub:@selector(infoDictionary) andReturn:infoDictionary];
        });

        it(@"queues a POST to create the session on the server", ^{
            [[transmitter should] receive:@selector(queueMethod:path:parameters:completion:) withArguments:@"POST", @"sessions.json", any(), any()];
            [session sendToServerWithCompletion:nil];
        });

        it(@"sends the required session parameters", ^{
            KWCaptureSpy *spy = [transmitter captureArgument:@selector(queueMethod:path:parameters:completion:) atIndex:2];
            [session sendToServerWithCompletion:nil];

            NSDictionary *parameters = spy.argument[@"session"];
            [[parameters[@"uuid"] should] equal:session.uuid];
            [[parameters[@"started_at"] should] equal:[CentauriTimestamp ISO8601TimestampFromDate:session.beginDate]];
            [[parameters[@"user_unique_id"] should] equal:session.userID];
            [parameters[@"session_info"] shouldNotBeNil];

            NSDictionary *info = parameters[@"session_info"];
            [info[@"_SDK Version"] shouldNotBeNil];
            [info[@"_App Version"] shouldNotBeNil];
            [info[@"_OS Version"] shouldNotBeNil];
            [info[@"_OS"] shouldNotBeNil];
            [info[@"_Hardware Model"] shouldNotBeNil];
            [info[@"_Locale"] shouldNotBeNil];
            [info[@"_Time Zone"] shouldNotBeNil];
        });

        it(@"does not send any buffers", ^{
            CentauriBuffer *buffer = [CentauriBuffer nullMock];
            [buffer stub:@selector(bytesBuffered) andReturn:theValue(100)];
            session.unpostedBuffers = [@[ buffer ] mutableCopy];
            [[buffer shouldNot] receive:@selector(inputStream)];
            [session sendToServerWithCompletion:nil];
        });

        context(@"when the POST succeeds", ^{
            it(@"sets beginPosted to YES", ^{
                [transmitter stub:@selector(queueMethod:path:parameters:completion:) withBlock:^id(NSArray *params) {
                    void (^block)(TransmitStatus status) = params[3];
                    block(TransmitStatusSuccess);
                    return nil;
                }];
                [session sendToServerWithCompletion:nil];
                [[theValue(session.beginPosted) should] beYes];
            });

            it(@"initiates another send to queue pending buffers", ^{
                [transmitter stub:@selector(queueMethod:path:parameters:completion:) withBlock:^id(NSArray *params) {
                    void (^block)(TransmitStatus status) = params[3];
                    block(TransmitStatusSuccess);
                    return nil;
                }];
                [[session should] receive:@selector(sendToServerWithCompletion:)];
                [session sendToServerWithCompletion:nil];
            });
        });

        context(@"when the POST fails", ^{
            it(@"does not initiate another send to queue pending buffers", ^{
                [transmitter stub:@selector(queueMethod:path:parameters:completion:) withBlock:^id(NSArray *params) {
                    void (^block)(TransmitStatus status) = params[3];
                    [[session shouldNot] receive:@selector(sendToServerWithCompletion:)];
                    block(TransmitStatusTemporaryFailure);
                    return nil;
                }];
                [session sendToServerWithCompletion:nil];
            });
        });

        context(@"when the POST fails permanently", ^{
            it(@"invalidates the session", ^{
                [transmitter stub:@selector(queueMethod:path:parameters:completion:) withBlock:^id(NSArray *params) {
                    void (^block)(TransmitStatus status) = params[3];
                    [[session should] receive:@selector(invalidate)];
                    block(TransmitStatusPermanentFailure);
                    return nil;
                }];
                [session sendToServerWithCompletion:nil];
            });

            it(@"calls the completion block with readyForCleanup=YES", ^{
                [transmitter stub:@selector(queueMethod:path:parameters:completion:) withBlock:^id(NSArray *params) {
                    void (^block)(TransmitStatus status) = params[3];
                    block(TransmitStatusPermanentFailure);
                    return nil;
                }];
                [transmitter stub:@selector(queueMarker:) withBlock:^id(NSArray *params) {
                    void (^block)(void) = params[0];
                    block();
                    return nil;
                }];
                __block BOOL cleanup = NO;
                [session sendToServerWithCompletion:^(BOOL readyForCleanup) {
                    cleanup = readyForCleanup;
                }];
                [[theValue(cleanup) should] beYes];
            });
        });
    });

    context(@"when there is at least one unposted buffer", ^{
        __block NSString *path;
        __block CentauriBuffer *buffer;
        __block CentauriBuffer *lastBuffer;

        beforeEach(^{
            session.beginPosted = YES;
            path = [NSString stringWithFormat:@"sessions/%@/log_lines.json", session.uuid];
            buffer = [CentauriBuffer nullMock];
            [buffer stub:@selector(bytesBuffered) andReturn:theValue(100)];
            lastBuffer = [CentauriBuffer nullMock];
            [lastBuffer stub:@selector(bytesBuffered) andReturn:theValue(0)];
            session.unpostedBuffers = [@[ buffer, lastBuffer ] mutableCopy];
        });

        context(@"when the last unposted buffer is empty", ^{
            it(@"queues each unposted, non-empty buffer", ^{
                [[buffer should] receive:@selector(inputStream)];
                [[lastBuffer shouldNot] receive:@selector(inputStream)];
                [[transmitter should] receive:@selector(queueMethod:path:stream:completion:) withArguments:@"POST", path, any(), any()];
                [session sendToServerWithCompletion:nil];
            });

            it(@"does not create a new buffer", ^{
                [transmitter stub:@selector(queueMethod:path:stream:completion:)];
                [[[session.unpostedBuffers lastObject] should] equal:lastBuffer];
            });
        });

        context(@"when the last unposted buffer is not empty", ^{
            beforeEach(^{
                [lastBuffer clearStubs];
                [lastBuffer stub:@selector(bytesBuffered) andReturn:theValue(100)];
            });

            it(@"freezes the buffer", ^{
                [[lastBuffer should] receive:@selector(freeze)];
                [transmitter stub:@selector(queueMethod:path:stream:completion:)];
                [session sendToServerWithCompletion:nil];
            });

            context(@"when the session has not yet ended", ^{
                it(@"starts a new buffer", ^{
                    [transmitter stub:@selector(queueMethod:path:stream:completion:)];
                    [session sendToServerWithCompletion:nil];
                    [[session.unpostedBuffers should] haveCountOf:3];
                });
            });

            context(@"when the session has ended", ^{
                beforeEach(^{
                    session.endDate = [NSDate date];
                });

                it(@"does not start a new buffer", ^{
                    [transmitter stub:@selector(queueMethod:path:stream:completion:)];
                    [session sendToServerWithCompletion:nil];
                    [[session.unpostedBuffers should] haveCountOf:2];
                });
            });
        });

        context(@"when the POST succeeds", ^{
            it(@"cleans the buffer up", ^{
                [[buffer should] receive:@selector(cleanup)];
                [transmitter stub:@selector(queueMethod:path:stream:completion:) withBlock:^id(NSArray *params) {
                    void (^block)(TransmitStatus status) = params[3];
                    block(TransmitStatusSuccess);
                    return nil;
                }];
                [session sendToServerWithCompletion:nil];
            });

            it(@"removes the buffer from unpostedBuffers", ^{
                [transmitter stub:@selector(queueMethod:path:stream:completion:) withBlock:^id(NSArray *params) {
                    void (^block)(TransmitStatus status) = params[3];
                    block(TransmitStatusSuccess);
                    return nil;
                }];
                [session sendToServerWithCompletion:nil];
                [[session.unpostedBuffers shouldNot] contain:buffer];
            });
        });

        context(@"when the POST fails", ^{
            it(@"does not remove the buffer from unpostedBuffers", ^{
                [transmitter stub:@selector(queueMethod:path:stream:completion:) withBlock:^id(NSArray *params) {
                    void (^block)(TransmitStatus status) = params[3];
                    block(TransmitStatusTemporaryFailure);
                    return nil;
                }];
                [session sendToServerWithCompletion:nil];
                [[session.unpostedBuffers should] contain:buffer];
            });
        });

        context(@"when the POST fails permanently", ^{
            it(@"cleans the buffer up", ^{
                [[buffer should] receive:@selector(cleanup)];
                [transmitter stub:@selector(queueMethod:path:stream:completion:) withBlock:^id(NSArray *params) {
                    void (^block)(TransmitStatus status) = params[3];
                    block(TransmitStatusPermanentFailure);
                    return nil;
                }];
                [session sendToServerWithCompletion:nil];
            });

            it(@"removes the buffer from unpostedBuffers", ^{
                [transmitter stub:@selector(queueMethod:path:stream:completion:) withBlock:^id(NSArray *params) {
                    void (^block)(TransmitStatus status) = params[3];
                    block(TransmitStatusPermanentFailure);
                    return nil;
                }];
                [session sendToServerWithCompletion:nil];
                [[session.unpostedBuffers shouldNot] contain:buffer];
            });
        });
    });

    context(@"when suspended", ^{
        beforeEach(^{
            session.beginPosted = YES;
            session.suspendedDate = [session.beginDate dateByAddingTimeInterval:10];
            session.unpostedBuffers = [NSMutableArray array];
        });

        it(@"queues a PATCH to update the session duration", ^{
            NSString *path = [NSString stringWithFormat:@"sessions/%@.json", session.uuid];
            [[transmitter should] receive:@selector(queueMethod:path:parameters:completion:) withArguments:@"PATCH", path, any(), nil];
            [session sendToServerWithCompletion:nil];
        });

        it(@"sends the updated duration", ^{
            KWCaptureSpy *spy = [transmitter captureArgument:@selector(queueMethod:path:parameters:completion:) atIndex:2];
            [session sendToServerWithCompletion:nil];
            NSDictionary *parameters = spy.argument[@"session"];
            [parameters[@"duration"] shouldNotBeNil];
        });
    });

    context(@"when ended, with no unposted buffers and endPosted is NO", ^{
        beforeEach(^{
            session.beginPosted = YES;
            session.endDate = [session.beginDate dateByAddingTimeInterval:10];
            session.unpostedBuffers = [NSMutableArray array];
        });

        it(@"queues a PATCH to update the session duration", ^{
            NSString *path = [NSString stringWithFormat:@"sessions/%@.json", session.uuid];
            [[transmitter should] receive:@selector(queueMethod:path:parameters:completion:) withArguments:@"PATCH", path, any(), any()];
            [session sendToServerWithCompletion:nil];
        });

        it(@"sends the updated duration", ^{
            KWCaptureSpy *spy = [transmitter captureArgument:@selector(queueMethod:path:parameters:completion:) atIndex:2];
            [session sendToServerWithCompletion:nil];
            NSDictionary *parameters = spy.argument[@"session"];
            [parameters[@"duration"] shouldNotBeNil];
        });

        context(@"when the PATCH succeeds", ^{
            it(@"sets endPosted to YES", ^{
                [transmitter stub:@selector(queueMethod:path:parameters:completion:) withBlock:^id(NSArray *params) {
                    void (^block)(TransmitStatus status) = params[3];
                    block(TransmitStatusSuccess);
                    return nil;
                }];
                [session sendToServerWithCompletion:nil];
                [[theValue(session.endPosted) should] beYes];
            });
        });

        context(@"when the PATCH fails", ^{
            it(@"endPosted remains NO", ^{
                [transmitter stub:@selector(queueMethod:path:parameters:completion:) withBlock:^id(NSArray *params) {
                    void (^block)(TransmitStatus status) = params[3];
                    block(TransmitStatusTemporaryFailure);
                    return nil;
                }];
                [session sendToServerWithCompletion:nil];
                [[theValue(session.endPosted) should] beNo];
            });
        });

        context(@"when the PATCH fails permanently", ^{
            it(@"invalidates the session", ^{
                [transmitter stub:@selector(queueMethod:path:parameters:completion:) withBlock:^id(NSArray *params) {
                    void (^block)(TransmitStatus status) = params[3];
                    block(TransmitStatusPermanentFailure);
                    return nil;
                }];
                [[session should] receive:@selector(invalidate)];
                [session sendToServerWithCompletion:nil];
            });
        });
    });

    context(@"when endPosted is NO", ^{
        beforeEach(^{
            session.beginPosted = YES;
        });

        it(@"calls the completion block with readyForCleanup = NO", ^{
            __block BOOL shouldCleanup = YES;
            [transmitter stub:@selector(queueMethod:path:parameters:completion:)];
            [transmitter stub:@selector(queueMarker:) withBlock:^id(NSArray *params) {
                void (^block)(void) = params[0];
                block();
                return nil;
            }];
            [session sendToServerWithCompletion:^(BOOL readyForCleanup) {
                shouldCleanup = readyForCleanup;
            }];
            [[theValue(shouldCleanup) should] beNo];
        });
    });

    context(@"when endPosted is YES", ^{
        beforeEach(^{
            session.beginPosted = YES;
            session.endPosted = YES;
        });

        it(@"calls the completion block with readyForCleanup=YES", ^{
            __block BOOL shouldCleanup = NO;
            [transmitter stub:@selector(queueMethod:path:parameters:completion:)];
            [transmitter stub:@selector(queueMarker:) withBlock:^id(NSArray *params) {
                void (^block)(void) = params[0];
                block();
                return nil;
            }];
            [session sendToServerWithCompletion:^(BOOL readyForCleanup) {
                shouldCleanup = readyForCleanup;
            }];
            [[theValue(shouldCleanup) should] beYes];
        });
    });

    context(@"when the session is invalid", ^{
        beforeEach(^{
            [session invalidate];
        });

        it(@"queues nothing", ^{
            [[transmitter shouldNot] receive:@selector(queueMethod:path:parameters:completion:)];
            [session sendToServerWithCompletion:nil];
        });

        it(@"calls the completion block with readyForCleanup=YES", ^{
            __block BOOL shouldCleanup = NO;
            [transmitter stub:@selector(queueMarker:) withBlock:^id(NSArray *params) {
                void (^block)(void) = params[0];
                block();
                return nil;
            }];
            [session sendToServerWithCompletion:^(BOOL readyForCleanup) {
                shouldCleanup = readyForCleanup;
            }];
            [[theValue(shouldCleanup) should] beYes];
        });
    });
});

SPEC_END
