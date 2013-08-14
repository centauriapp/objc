//
//  CentauriTests.m
//  Centauri
//
//  Created by Steve Madsen on 5/16/13.
//  Copyright (c) 2013 Light Year Software, LLC
//

#import "Kiwi.h"
#import "Centauri.h"
#import "CentauriInMemoryState.h"
#import "CentauriTimestamp.h"
#import "CentauriSanitizer.h"
#import "CentauriWorker.h"
#import "CentauriSession.h"
#import "CentauriTransmitter.h"

static void LogSeverityTagsFormatArguments(Centauri *instance, NSNumber *severity, NSString *tags, NSString *format, ...)
{
    va_list arguments;
    va_start(arguments, format);
    [instance logSeverity:severity tags:tags format:format arguments:arguments];
}

@interface Centauri ()
@property (nonatomic) CentauriState *state;
@property (nonatomic) CentauriWorker *worker;
@property (nonatomic) CentauriSession *currentSession;
@end

SPEC_BEGIN(CentauriTests)

describe(@"C interface", ^{
    __block Centauri *instance;

    beforeEach(^{
        instance = [Centauri mock];
        [Centauri stub:@selector(sharedInstance) andReturn:instance];
    });

    afterEach(^{
        instance = nil;
    });

    describe(@"CENLog", ^{
        it(@"calls -logSeverity:tags:format:arguments:", ^{
            [[instance should] receive:@selector(logSeverity:tags:format:arguments:) withArguments:nil, nil, @"the message", any()];
            CENLog(@"the message");
        });
    });

    describe(@"CENLogT", ^{
        it(@"calls -logSeverity:tags:format:arguments:", ^{
            [[instance should] receive:@selector(logSeverity:tags:format:arguments:) withArguments:nil, @"tag", @"the message", any()];
            CENLogT(@"tag", @"the message");
        });
    });

    describe(@"CENLogST", ^{
        it(@"calls -logSeverity:tags:format:arguments:", ^{
            [[instance should] receive:@selector(logSeverity:tags:format:arguments:) withArguments:@(CentauriLogInfo), @"tag", @"the message", any()];
            CENLogST(CentauriLogInfo, @"tag", @"the message");
        });
    });
});

describe(@"initialization", ^{
    it(@"loads previous unposted sessions", ^{
        CentauriInMemoryState *state = [CentauriInMemoryState alloc];
        [CentauriState stub:@selector(alloc) andReturn:state];
        [[state should] receive:@selector(loadSessions)];
        __unused Centauri *instance = [[Centauri alloc] init];
    });
});

describe(@"Centauri public API", ^{
    __block Centauri *instance;
    __block CentauriInMemoryState *state;
    __block CentauriSession *session;

    beforeEach(^{
        state = [CentauriInMemoryState alloc];
        [CentauriState stub:@selector(alloc) andReturn:state];
        instance = [[Centauri alloc] init];
        instance.worker = [[CentauriWorker alloc] init];
    });

    describe(@"defaults", ^{
        it(@"userID is nil", ^{
            [instance.userID shouldBeNil];
        });

        it(@"useHTTPS is NO", ^{
            [[theValue(instance.useHTTPS) should] beNo];
        });

        it(@"sessionIdleTimeout is 300", ^{
            [[theValue(instance.sessionIdleTimeout) should] equal:theValue(300)];
        });

        it(@"autoFlushThreshold is 65536", ^{
            [[theValue(instance.autoFlushThreshold) should] equal:theValue(65536)];
        });

        it(@"teeToSystemLog is YES", ^{
            [[theValue(instance.teeToSystemLog) should] beYes];
        });

        it(@"sessionInfo is nil", ^{
            [instance.sessionInfo shouldBeNil];
        });

        it(@"userInfoBlock is nil", ^{
            [instance.userInfoBlock shouldBeNil];
        });
    });

    describe(@"useHTTPS property", ^{
        it(@"sets the transmitter base URL scheme to http:// when NO", ^{
            instance.useHTTPS = NO;
            [[[CentauriTransmitter sharedTransmitter].baseURLString should] startWithString:@"http://"];
        });

        it(@"sets the transmitter base URL scheme to https:// when YES", ^{
            instance.useHTTPS = YES;
            [[[CentauriTransmitter sharedTransmitter].baseURLString should] startWithString:@"https://"];
        });
    });

    describe(@"autoFlushThreshold property", ^{
        it(@"sets the new value on the active session", ^{
            session = [CentauriSession mock];
            instance.currentSession = session;
            [[session should] receive:@selector(setMaximumBufferSize:) withArguments:theValue(1000)];
            instance.autoFlushThreshold = 1000;
        });
    });

    describe(@"sessionInfo property", ^{
        it(@"sanitizes the dictionary", ^{
            [[CentauriSanitizer should] receive:@selector(sanitize:)];
            instance.sessionInfo = @{};
        });
    });

    context(@"at initialization", ^{
        it(@"ends previous sessions", ^{
            CentauriSession *previousSession = [CentauriSession nullMock];
            [previousSession stub:@selector(active) andReturn:theValue(YES)];
            [[previousSession should] receive:@selector(end:) withArguments:theValue(YES)];
            state.savedSessions = @[ previousSession ];
            instance.state = state;
        });
    });
    
    describe(@"-beginSession:", ^{
        beforeEach(^{
            session = [CentauriSession alloc];
            [CentauriSession stub:@selector(alloc) andReturn:session];
            [instance stub:@selector(flush)];
        });
        
        it(@"creates a new session with the provided app token", ^{
            [[session should] receive:@selector(initWithAppToken:info:userID:) withArguments:@"token", any(), any()];
            [instance beginSession:@"token"];
        });

        it(@"sets the Authorization header on the transmitter", ^{
            [[[CentauriTransmitter sharedTransmitter] should] receive:@selector(setValue:forHTTPHeader:) withArguments:@"Basic dG9rZW46", @"Authorization"];
            [instance beginSession:@"token"];
        });

        it(@"creates a new session with the provided info dictionary", ^{
            instance.sessionInfo = @{ @"mykey": @"myvalue" };
            KWCaptureSpy *spy = [session captureArgument:@selector(initWithAppToken:info:userID:) atIndex:1];
            [instance beginSession:@"token"];
            [[spy.argument objectForKey:@"mykey"] shouldNotBeNil];
        });

        it(@"creates a new session with the provided user ID", ^{
            instance.userID = @"theuser";
            KWCaptureSpy *spy = [session captureArgument:@selector(initWithAppToken:info:userID:) atIndex:2];
            [instance beginSession:@"token"];
            [[spy.argument should] equal:@"theuser"];
        });

        it(@"sets the current session to the new session", ^{
            [instance beginSession:@"token"];
            [[instance.currentSession should] equal:session];
        });

        it(@"saves the list of unposted sessions", ^{
            [[state should] receive:@selector(saveSessions:)];
            [instance beginSession:@"token"];
        });

        it(@"should add the new session to the set of unposted sessions", ^{
            [instance beginSession:@"token"];
            [[theValue([state.savedSessions containsObject:session]) should] beTrue];
        });

        it(@"assigns the auto-flush threshold to the session's maximum buffer size", ^{
            [instance beginSession:@"token"];
            [[theValue(session.maximumBufferSize) should] equal:theValue(instance.autoFlushThreshold)];
        });

        it(@"initiates a flush", ^{
            [[instance should] receive:@selector(flush)];
            [instance beginSession:@"token"];
        });

        it(@"ends a previously active session", ^{
            CentauriSession *activeSession = [[CentauriSession alloc] init];
            instance.currentSession = activeSession;
            [[activeSession should] receive:@selector(end:) withArguments:theValue(NO)];
            [instance beginSession:@"token"];
        });
    });

    describe(@"-endSession", ^{
        beforeEach(^{
            instance.currentSession = session;
        });

        it(@"ends the current session", ^{
            [[session should] receive:@selector(end:)];
            [instance endSession];
        });

        it(@"saves the list of unposted sessions", ^{
            [[state should] receive:@selector(saveSessions:)];
            [instance endSession];
        });

        it(@"initiates a flush", ^{
            [[instance should] receive:@selector(flush)];
            [instance endSession];
        });
    });

    describe(@"-flush", ^{
        context(@"when there are sessions", ^{
            __block CentauriSession *oldSession;

            beforeEach(^{
                oldSession = [CentauriSession nullMock];
                session = [CentauriSession nullMock];
                state.savedSessions = @[ oldSession, session ];
                instance.state = state;
                instance.currentSession = session;
            });

            it(@"tells known sessions to send their data to the server", ^{
                [[oldSession should] receive:@selector(sendToServerWithCompletion:)];
                [[session should] receive:@selector(sendToServerWithCompletion:)];
                [instance flush];
            });

            context(@"when the session signals it is ready for clean-up", ^{
                context(@"for an old session", ^{
                    it(@"cleans up the session", ^{
                        [oldSession stub:@selector(sendToServerWithCompletion:) withBlock:^id(NSArray *params) {
                            void (^block)(BOOL) = params[0];
                            block(YES);
                            return nil;
                        }];
                        [[oldSession should] receive:@selector(cleanup)];
                        [instance flush];
                    });

                    it(@"removes the session from the session list", ^{
                        [oldSession stub:@selector(sendToServerWithCompletion:) withBlock:^id(NSArray *params) {
                            void (^block)(BOOL) = params[0];
                            block(YES);
                            return nil;
                        }];
                        [instance flush];
                        [[theValue([state.savedSessions containsObject:oldSession]) should] beNo];
                    });
                });

                context(@"for the current session", ^{
                    it(@"does not clean up the session", ^{
                        [session stub:@selector(sendToServerWithCompletion:) withBlock:^id(NSArray *params) {
                            void (^block)(BOOL) = params[0];
                            block(YES);
                            return nil;
                        }];
                        [[session shouldNot] receive:@selector(cleanup)];
                        [instance flush];
                    });

                    it(@"does not remove the session from the session list", ^{
                        [session stub:@selector(sendToServerWithCompletion:) withBlock:^id(NSArray *params) {
                            void (^block)(BOOL) = params[0];
                            block(YES);
                            return nil;
                        }];
                        [instance flush];
                        [[theValue([state.savedSessions containsObject:session]) should] beYes];
                    });
                });
            });

            context(@"when the session signals it is not ready for clean-up", ^{
                context(@"for an old session", ^{
                    it(@"does not clean up the session", ^{
                        [oldSession stub:@selector(sendToServerWithCompletion:) withBlock:^id(NSArray *params) {
                            void (^block)(BOOL) = params[0];
                            block(NO);
                            return nil;
                        }];
                        [[oldSession shouldNot] receive:@selector(cleanup)];
                        [instance flush];
                    });
                });

                context(@"for the current session", ^{
                    it(@"does not clean up the session", ^{
                        [session stub:@selector(sendToServerWithCompletion:) withBlock:^id(NSArray *params) {
                            void (^block)(BOOL) = params[0];
                            block(NO);
                            return nil;
                        }];
                        [[session shouldNot] receive:@selector(cleanup)];
                        [instance flush];
                    });
                });
            });
        });
    });

    describe(@"-beginLogging", ^{
        beforeEach(^{
            session = [CentauriSession nullMock];
            instance.currentSession = session;
        });

        it(@"starts buffering log messages", ^{
            [[session should] receive:@selector(bufferMessage:)];
            [instance beginLogging];
            [instance logSeverity:nil tags:nil message:@""];
        });
    });

    describe(@"-endLogging", ^{
        beforeEach(^{
            session = [CentauriSession nullMock];
            instance.currentSession = session;
            [instance beginLogging];
        });

        it(@"stops buffering log messages", ^{
            [[session shouldNot] receive:@selector(bufferMessage:)];
            [instance endLogging];
            [instance logSeverity:nil tags:nil message:@""];
        });

        it(@"initiates a flush", ^{
            [[instance should] receive:@selector(flush)];
            [instance endLogging];
        });
    });

    describe(@"-logSeverity:tags:message:", ^{
        it(@"delegates the real work to -logSeverity:tags:format:message:", ^{
            [[instance should] receive:@selector(logSeverity:tags:format:arguments:)];
            [instance logSeverity:nil tags:nil message:@""];
        });
    });

    describe(@"-logSeverity:tags:format:arguments:", ^{
        context(@"when logging has started", ^{
            __block KWCaptureSpy *spy;

            beforeEach(^{
                session = [CentauriSession nullMock];
                spy = [session captureArgument:@selector(bufferMessage:) atIndex:0];
                instance.currentSession = session;
                [instance beginLogging];
            });

            it(@"records a timestamp", ^{
                [[CentauriTimestamp should] receive:@selector(ISO8601Timestamp) andReturn:@"timestamp"];
                LogSeverityTagsFormatArguments(instance, nil, nil, @"the message");
                NSDictionary *dict = spy.argument;
                [[dict objectForKey:@"timestamp"] shouldNotBeNil];
            });

            it(@"preserves the severity", ^{
                LogSeverityTagsFormatArguments(instance, @(CentauriLogInfo), nil, @"the message");
                NSDictionary *dict = spy.argument;
                [[[dict objectForKey:@"severity"] should] equal:@(CentauriLogInfo)];
            });

            it(@"preserves the tag", ^{
                LogSeverityTagsFormatArguments(instance, nil, @"tag", @"the message");
                NSDictionary *dict = spy.argument;
                [[[dict objectForKey:@"tags"] should] equal:@"tag"];
            });

            it(@"preserves the message", ^{
                LogSeverityTagsFormatArguments(instance, nil, nil, @"the message");
                NSDictionary *dict = spy.argument;
                [[[dict objectForKey:@"message"] should] equal:@"the message"];
            });

            it(@"captures the process ID", ^{
                LogSeverityTagsFormatArguments(instance, nil, nil, @"the message");
                NSDictionary *dict = spy.argument;
                NSDictionary *info = dict[@"user_info"];
                [[info objectForKey:@"process_id"] shouldNotBeNil];
            });

            it(@"captures the thread ID", ^{
                LogSeverityTagsFormatArguments(instance, nil, nil, @"the message");
                NSDictionary *dict = spy.argument;
                NSDictionary *info = dict[@"user_info"];
                [[info objectForKey:@"thread_id"] shouldNotBeNil];
            });

            it(@"uses “main” as the queue name when run from the main queue", ^{
                LogSeverityTagsFormatArguments(instance, nil, nil, @"the message");
                NSDictionary *dict = spy.argument;
                NSDictionary *info = dict[@"user_info"];
                [[[info objectForKey:@"queue"] should] equal:@"main"];
            });

            it(@"captures the queue name when run from an NSOperationQueue", ^{
                __block NSDictionary *dict;
                NSOperationQueue *queue = [[NSOperationQueue alloc] init];
                queue.name = @"my operation queue";
                [queue addOperationWithBlock:^{
                    LogSeverityTagsFormatArguments(instance, nil, nil, @"the message");
                    dict = spy.argument;
                }];
                [queue waitUntilAllOperationsAreFinished];
                NSDictionary *info = dict[@"user_info"];
                [[[info objectForKey:@"queue"] should] equal:@"my operation queue"];
            });

            it(@"captures the queue name when run from a dispatch queue", ^{
                __block NSDictionary *dict;
                dispatch_queue_t queue = dispatch_queue_create("my dispatch queue", NULL);
                dispatch_sync(queue, ^{
                    LogSeverityTagsFormatArguments(instance, nil, nil, @"the message");
                    dict = spy.argument;
                });
                NSDictionary *info = dict[@"user_info"];
                [[[info objectForKey:@"queue"] should] equal:@"my dispatch queue"];
            });

            it(@"captures the queue address when run from a dispatch queue without a name", ^{
                __block NSDictionary *dict;
                dispatch_queue_t queue = dispatch_queue_create(NULL, NULL);
                dispatch_sync(queue, ^{
                    LogSeverityTagsFormatArguments(instance, nil, nil, @"the message");
                    dict = spy.argument;
                });
                NSDictionary *info = dict[@"user_info"];
                [[[info objectForKey:@"queue"] should] equal:[NSString stringWithFormat:@"%p", queue]];
            });

            it(@"calls the userInfoBlock when one is assigned", ^{
                __block BOOL called = NO;
                instance.userInfoBlock =  ^(NSMutableDictionary *userInfo) {
                    called = YES;
                };
                LogSeverityTagsFormatArguments(instance, nil, nil, @"");
                [[theValue(called) should] beTrue];
            });

            it(@"sanitizes the userInfo dictionary", ^{
                [[CentauriSanitizer should] receive:@selector(sanitize:) andReturn:@{}];
                instance.userInfoBlock = ^(NSMutableDictionary *userInfo) {
                    userInfo[@"key"] = @"value";
                };
                LogSeverityTagsFormatArguments(instance, nil, nil, @"");
            });

            it(@"sends the message to the current session for buffering", ^{
                [[session should] receive:@selector(bufferMessage:)];
                LogSeverityTagsFormatArguments(instance, nil, nil, @"");
            });

            context(@"when -[CentauriSession bufferMessage:] returns YES", ^{
                beforeEach(^{
                    [[session should] receive:@selector(bufferMessage:) andReturn:theValue(YES)];
                });

                it(@"initiates a flush", ^{
                    [[instance should] receive:@selector(flush)];
                    LogSeverityTagsFormatArguments(instance, nil, nil, @"");
                });
            });
        });

        context(@"when logging is stopped", ^{
            beforeEach(^{
                session = [CentauriSession nullMock];
                instance.currentSession = session;
            });

            it(@"does not send the message to the current session", ^{
                [[session shouldNot] receive:@selector(bufferMessage:)];
                LogSeverityTagsFormatArguments(instance, nil, nil, @"");
            });
        });
    });
});

SPEC_END