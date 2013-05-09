//
//  CentauriTransmitterTests.m
//  Centauri
//
//  Created by Steve Madsen on 5/29/13.
//  Copyright (c) 2013 Light Year Software, LLC
//

#import <UIKit/UIKit.h>
#import "Kiwi.h"
#import "Nocilla.h"

#import "CentauriTransmitter.h"

SPEC_BEGIN(CentauriTransmitterTests)

__block CentauriTransmitter *transmitter;

beforeAll(^{
    [[LSNocilla sharedInstance] start];
});

beforeEach(^{
    transmitter = [[CentauriTransmitter alloc] init];
    transmitter.baseURLString = @"http://test.host/";
});

afterEach(^{
    [[LSNocilla sharedInstance] clearStubs];
});

afterAll(^{
    [[LSNocilla sharedInstance] stop];
});

describe(@"-setBaseURLString:", ^{
    it(@"raises an exception if the string does not end with a slash", ^{
        [[theBlock(^{
            transmitter.baseURLString = @"http://relative.to.URL.will.do.the.wrong.thing/v1";
        }) should] raise];
    });
});

describe(@"-pause", ^{
    it(@"pauses the queue", ^{
        [transmitter pause];
        [[theValue(transmitter.paused) should] beYes];
    });

    it(@"does not execute newly queued jobs", ^{
        __block BOOL blockRun = NO;

        [transmitter pause];
        [transmitter queueMarker:^{
            blockRun = YES;
        }];
        [[theValue(blockRun) should] beNo];
    });
});

describe(@"-resume", ^{
    beforeEach(^{
        [transmitter pause];
    });

    it(@"unpauses the queue", ^{
        [transmitter resume];
        [[theValue(transmitter.paused) should] beNo];
    });

    it(@"starts executing queued jobs", ^{
        __block BOOL blockRun = NO;
        [transmitter queueMarker:^{
            blockRun = YES;
        }];
        [transmitter resume];
        [[theValue(blockRun) should] beYes];
    });
});

describe(@"-setValue:forHTTPHeader:", ^{
    context(@"with a non-nil value", ^{
        it(@"adds or changes the value sent in future requests", ^{
            [transmitter setValue:@"the header value" forHTTPHeader:@"My-Header"];
            [[transmitter.headers[@"My-Header"] should] equal:@"the header value"];
        });
    });

    context(@"with a nil value", ^{
        it(@"removes the header from future requests", ^{
            transmitter.headers[@"My-Header"] = @"the header value";
            [transmitter setValue:nil forHTTPHeader:@"My-Header"];
            [transmitter.headers[@"My-Header"] shouldBeNil];
        });
    });
});

describe(@"-queueMethod:path:parameters:completion:", ^{
    it(@"makes an API call with the supplied parameters", ^{
        __block BOOL blockRun = NO;
        stubRequest(@"POST", @"http://test.host/endpoint")
            .withHeaders(@{ @"Content-Type": @"application/json" })
            .withBody(@"{\"foo\":\"bar\"}");
        [[theBlock(^{
            [transmitter queueMethod:@"POST" path:@"/endpoint" parameters:@{ @"foo": @"bar" } completion:^(TransmitStatus status) {
                blockRun = YES;
            }];
        }) shouldNot] raise];
        [[theValue(blockRun) should] beYes];
    });

    context(@"when it succeeds", ^{
        it(@"calls the completion block with TransmitStatusSuccess", ^{
            __block TransmitStatus result = -1;
            stubRequest(@"POST", @"http://test.host/endpoint")
                .withHeaders(@{ @"Content-Type": @"application/json" })
                .andReturn(200);
            [transmitter queueMethod:@"POST" path:@"/endpoint" parameters:nil completion:^(TransmitStatus status) {
                result = status;
            }];
            [[theValue(result) should] equal:theValue(TransmitStatusSuccess)];
        });
    });

    context(@"when it fails with 401 Unauthorized", ^{
        it(@"calls the completion block with TransmitStatusPermanentFailure", ^{
            __block TransmitStatus result = -1;
            stubRequest(@"POST", @"http://test.host/endpoint")
                .withHeaders(@{ @"Content-Type": @"application/json" })
                .andReturn(401);
            [transmitter queueMethod:@"POST" path:@"/endpoint" parameters:nil completion:^(TransmitStatus status) {
                result = status;
            }];
            [[theValue(result) should] equal:theValue(TransmitStatusPermanentFailure)];
        });
    });

    context(@"when it fails with 403 Forbidden", ^{
        it(@"calls the completion block with TransmitStatusPermanentFailure", ^{
            __block TransmitStatus result = -1;
            stubRequest(@"POST", @"http://test.host/endpoint")
                .withHeaders(@{ @"Content-Type": @"application/json" })
                .andReturn(403);
            [transmitter queueMethod:@"POST" path:@"/endpoint" parameters:nil completion:^(TransmitStatus status) {
                result = status;
            }];
            [[theValue(result) should] equal:theValue(TransmitStatusPermanentFailure)];
        });
    });

    context(@"when it fails with 422 Unprocessable Entity", ^{
        it(@"calls the completion block with TransmitStatusPermanentFailure", ^{
            __block TransmitStatus result = -1;
            stubRequest(@"POST", @"http://test.host/endpoint")
                .withHeaders(@{ @"Content-Type": @"application/json" })
                .andReturn(422);
            [transmitter queueMethod:@"POST" path:@"/endpoint" parameters:nil completion:^(TransmitStatus status) {
                result = status;
            }];
            [[theValue(result) should] equal:theValue(TransmitStatusPermanentFailure)];
        });
    });

    context(@"when it fails with some other HTTP error", ^{
        it(@"calls the completion block with TransmitStatusTemporaryFailure", ^{
            __block TransmitStatus result = -1;
            stubRequest(@"POST", @"http://test.host/endpoint")
                .withHeaders(@{ @"Content-Type": @"application/json" })
                .andReturn(500);
            [transmitter queueMethod:@"POST" path:@"/endpoint" parameters:nil completion:^(TransmitStatus status) {
                result = status;
            }];
            [[theValue(result) should] equal:theValue(TransmitStatusTemporaryFailure)];
        });
    });

    context(@"when it fails with a connection error", ^{
        it(@"calls the completion block with TransmitStatusTemporaryFailure", ^{
            __block TransmitStatus result = -1;
            stubRequest(@"POST", @"http://test.host/endpoint")
                .withHeaders(@{ @"Content-Type": @"application/json" })
                .andFailWithError([NSError errorWithDomain:NSCocoaErrorDomain code:0 userInfo:nil]);
            [transmitter queueMethod:@"POST" path:@"/endpoint" parameters:nil completion:^(TransmitStatus status) {
                result = status;
            }];
            [[theValue(result) should] equal:theValue(TransmitStatusTemporaryFailure)];
        });
    });

    it(@"accepts nil parameters", ^{
        stubRequest(@"POST", @"http://test.host/endpoint")
            .withHeaders(@{ @"Content-Type": @"application/json" });
        [[theBlock(^{
            [transmitter queueMethod:@"POST" path:@"/endpoint" parameters:nil completion:^(TransmitStatus status) {}];
        }) shouldNot] raise];
    });

    it(@"accepts a nil block", ^{
        stubRequest(@"POST", @"http://test.host/endpoint")
            .withHeaders(@{ @"Content-Type": @"application/json" });
        [[theBlock(^{
            [transmitter queueMethod:@"POST" path:@"/endpoint" parameters:@{} completion:nil];
        }) shouldNot] raise];
    });
});

describe(@"-queueMethod:path:stream:completion:", ^{
    it(@"makes an API call using the stream as POST data", ^{
        __block BOOL blockRun = NO;
        NSString *body = @"{\"foo\":\"bar\"}";
        NSData *data = [body dataUsingEncoding:NSUTF8StringEncoding];
        NSInputStream *stream = [NSInputStream inputStreamWithData:data];
        stubRequest(@"POST", @"http://test.host/endpoint")
            .withHeaders(@{ @"Content-Type": @"application/json" })
            .withBody(@"{\"foo\":\"bar\"}");
        [[theBlock(^{
            [transmitter queueMethod:@"POST" path:@"/endpoint" stream:stream completion:^(TransmitStatus status) {
                blockRun = YES;
            }];
        }) shouldNot] raise];
        [[theValue(blockRun) should] beYes];
    });

    context(@"when it succeeds", ^{
        it(@"calls the completion block with TransmitStatusSuccess", ^{
            __block TransmitStatus result = -1;
            NSInputStream *stream = [NSInputStream inputStreamWithData:[NSData data]];
            stubRequest(@"POST", @"http://test.host/endpoint")
                .withHeaders(@{ @"Content-Type": @"application/json" })
                .andReturn(200);
            [transmitter queueMethod:@"POST" path:@"/endpoint" stream:stream completion:^(TransmitStatus status) {
                result = status;
            }];
            [[theValue(result) should] equal:theValue(TransmitStatusSuccess)];
        });
    });

    context(@"when it fails with 401 Unauthorized", ^{
        it(@"calls the completion block with TransmitStatusPermanentFailure", ^{
            __block TransmitStatus result = -1;
            NSInputStream *stream = [NSInputStream inputStreamWithData:[NSData data]];
            stubRequest(@"POST", @"http://test.host/endpoint")
                .withHeaders(@{ @"Content-Type": @"application/json" })
                .andReturn(401);
            [transmitter queueMethod:@"POST" path:@"/endpoint" stream:stream completion:^(TransmitStatus status) {
                result = status;
            }];
            [[theValue(result) should] equal:theValue(TransmitStatusPermanentFailure)];
        });
    });

    context(@"when it fails with 403 Forbidden", ^{
        it(@"calls the completion block with TransmitStatusPermanentFailure", ^{
            __block TransmitStatus result = -1;
            NSInputStream *stream = [NSInputStream inputStreamWithData:[NSData data]];
            stubRequest(@"POST", @"http://test.host/endpoint")
                .withHeaders(@{ @"Content-Type": @"application/json" })
                .andReturn(403);
            [transmitter queueMethod:@"POST" path:@"/endpoint" stream:stream completion:^(TransmitStatus status) {
                result = status;
            }];
            [[theValue(result) should] equal:theValue(TransmitStatusPermanentFailure)];
        });
    });

    context(@"when it fails with 422 Unprocessable Entity", ^{
        it(@"calls the completion block with TransmitStatusPermanentFailure", ^{
            __block TransmitStatus result = -1;
            NSInputStream *stream = [NSInputStream inputStreamWithData:[NSData data]];
            stubRequest(@"POST", @"http://test.host/endpoint")
                .withHeaders(@{ @"Content-Type": @"application/json" })
                .andReturn(422);
            [transmitter queueMethod:@"POST" path:@"/endpoint" stream:stream completion:^(TransmitStatus status) {
                result = status;
            }];
            [[theValue(result) should] equal:theValue(TransmitStatusPermanentFailure)];
        });
    });

    context(@"when it fails with some other HTTP error", ^{
        it(@"calls the completion block with TransmitStatusTemporaryFailure", ^{
            __block TransmitStatus result = -1;
            NSInputStream *stream = [NSInputStream inputStreamWithData:[NSData data]];
            stubRequest(@"POST", @"http://test.host/endpoint")
                .withHeaders(@{ @"Content-Type": @"application/json" })
                .andReturn(500);
            [transmitter queueMethod:@"POST" path:@"/endpoint" stream:stream completion:^(TransmitStatus status) {
                result = status;
            }];
            [[theValue(result) should] equal:theValue(TransmitStatusTemporaryFailure)];
        });
    });

    context(@"when it fails with a connection error", ^{
        it(@"calls the completion block with TransmitStatusTemporaryFailure", ^{
            __block TransmitStatus result = -1;
            NSInputStream *stream = [NSInputStream inputStreamWithData:[NSData data]];
            stubRequest(@"POST", @"http://test.host/endpoint")
                .withHeaders(@{ @"Content-Type": @"application/json" })
                .andFailWithError([NSError errorWithDomain:NSCocoaErrorDomain code:0 userInfo:nil]);
            [transmitter queueMethod:@"POST" path:@"/endpoint" stream:stream completion:^(TransmitStatus status) {
                result = status;
            }];
            [[theValue(result) should] equal:theValue(TransmitStatusTemporaryFailure)];
        });
    });
});

describe(@"-queueMarker:", ^{
    it(@"executes the block", ^{
        __block BOOL blockRun = NO;
        [transmitter queueMarker:^{
            blockRun = YES;
        }];
        [[theValue(blockRun) should] beYes];
    });
});

describe(@"queue processing", ^{
    beforeEach(^{
        [UIApplication stub:@selector(sharedApplication) andReturn:[UIApplication nullMock]];
    });

    it(@"begins a background task when starting the first job", ^{
        [[[UIApplication sharedApplication] should] receive:@selector(beginBackgroundTaskWithExpirationHandler:)];
        [transmitter queueMarker:^{}];
    });

    it(@"ends the background task after the last job", ^{
        [[[UIApplication sharedApplication] should] receive:@selector(endBackgroundTask:)];
        [transmitter queueMarker:^{}];
    });
});

SPEC_END
