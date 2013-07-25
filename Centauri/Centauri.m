//
//  Centauri.m
//  Centauri
//
//  Created by Steve Madsen on 5/15/13.
//  Copyright (c) 2013 Light Year Software, LLC
//

#include <mach/mach_types.h>
#include <pthread.h>
#include <sys/sysctl.h>
#include <asl.h>

#import <UIKit/UIKit.h>

#import "Centauri.h"
#import "CentauriState.h"
#import "CentauriTimestamp.h"
#import "CentauriSanitizer.h"
#import "CentauriWorker.h"
#import "CentauriSession.h"
#import "CentauriTransmitter.h"
#import "CentauriDevLog.h"

void CENLog(NSString *format, ...)
{
    va_list arguments;
    va_start(arguments, format);
    [[Centauri sharedInstance] logSeverity:nil tags:nil format:format arguments:arguments];
}

void CENLogT(NSString *tags, NSString *format, ...)
{
    va_list arguments;
    va_start(arguments, format);
    [[Centauri sharedInstance] logSeverity:nil tags:tags format:format arguments:arguments];
}

void CENLogST(CentauriLogSeverity severity, NSString *tags, NSString *format, ...)
{
    va_list arguments;
    va_start(arguments, format);
    [[Centauri sharedInstance] logSeverity:@(severity) tags:tags format:format arguments:arguments];
}

static NSString * Base64EncodeString(NSString *string);

@interface Centauri ()
@property (nonatomic) CentauriState *state;
@property (nonatomic) CentauriWorker *worker;
@property (nonatomic) CentauriSession *currentSession;
@end

@implementation Centauri
{
    NSString *_appToken;
    NSMutableArray *_sessions;
    BOOL _logging;
}

+ (instancetype) sharedInstance
{
    static Centauri *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[[self class] alloc] init];
    });

    return instance;
}

- (id) init
{
    self = [super init];
    if (self)
    {
        self.state = [[CentauriState alloc] initWithDirectory:NSTemporaryDirectory()];
        self.worker = [[CentauriSerialQueueWorker alloc] initWithName:@"com.centauriapp"];
        [CentauriTransmitter sharedTransmitter].completionWorker = self.worker;

        self.userID = nil;
        self.useHTTPS = NO;
        self.sessionIdleTimeout = 300;
        self.autoFlushThreshold = 65536;
        self.teeToSystemLog = YES;
        self.sessionInfo = nil;
        self.userInfoBlock = nil;

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(lifecycleNotification:) name:UIApplicationDidEnterBackgroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(lifecycleNotification:) name:UIApplicationWillEnterForegroundNotification object:nil];
    }

    return self;
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillEnterForegroundNotification object:nil];
}

- (void) setState:(CentauriState *)state
{
    _state = state;
    _sessions = [[_state loadSessions] mutableCopy];

    for (CentauriSession *session in _sessions)
    {
        if (session.endDate == nil)
        {
            [session end:YES];
        }
    }
}

- (void) setAutoFlushThreshold:(NSUInteger)autoFlushThreshold
{
    _autoFlushThreshold = autoFlushThreshold;
    self.currentSession.maximumBufferSize = autoFlushThreshold;
}

- (void) setSessionInfo:(NSDictionary *)sessionInfo
{
    _sessionInfo = [CentauriSanitizer sanitize:sessionInfo];
}

- (void) setTeeToSystemLog:(BOOL)teeToSystemLog
{
    _teeToSystemLog = teeToSystemLog;

    if (_teeToSystemLog)
    {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            asl_add_log_file(NULL, STDERR_FILENO);
        });
    }
}

- (void) setUseHTTPS:(BOOL)useHTTPS
{
    _useHTTPS = useHTTPS;
    NSString *baseURLString = [NSString stringWithFormat:@"%@://api.centauriapp.com/v1/", useHTTPS ? @"https" : @"http"];
    [CentauriTransmitter sharedTransmitter].baseURLString = baseURLString;
}

- (void) beginSession:(NSString *)appToken
{
    _appToken = [appToken copy];
    [self.worker doBlock:^{
        [self.currentSession end:NO];
        CentauriSession *newSession = [[CentauriSession alloc] initWithAppToken:appToken info:self.sessionInfo userID:self.userID];
        NSString *basicAuth = [NSString stringWithFormat:@"Basic %@", Base64EncodeString([NSString stringWithFormat:@"%@:", appToken])];
        [[CentauriTransmitter sharedTransmitter] setValue:basicAuth forHTTPHeader:@"Authorization"];
        self.currentSession = newSession;
        if (self.currentSession)
        {
            CentauriDevLog(@"Started new session %@", newSession.uuid);
            self.currentSession.maximumBufferSize = self.autoFlushThreshold;
            [_sessions addObject:self.currentSession];
            [self saveState];
        }
    }];
    [self flush];
}

- (void) endSession
{
    [self.worker doBlock:^{
        [self.currentSession end:NO];
        self.currentSession = nil;
        [self saveState];
        [self flush];
    }];
}

- (void) flush
{
    [self.worker doBlock:^{
        CentauriDevLog(@"Flushing %d sessions", [_sessions count]);
        for (CentauriSession *session in _sessions)
        {
            [session sendToServerWithCompletion:^(BOOL readyForCleanup) {
                CentauriDevLog(@"Session %@ readyForCleanup=%@", session.uuid, readyForCleanup ? @"YES" : @"NO");
                if (readyForCleanup && session != self.currentSession)
                {
                    [session cleanup];
                    [_sessions removeObject:session];
                }

                [self saveState];
            }];
        }
    }];
}

- (void) beginLogging
{
    _logging = YES;
}

- (void) endLogging
{
    _logging = NO;
    [self flush];
}

- (void) logSeverity:(NSNumber *)severity tags:(NSString *)tags message:(NSString *)message, ...
{
    va_list arguments;
    va_start(arguments, message);
    [self logSeverity:severity tags:tags format:message arguments:arguments];
}

- (void) logSeverity:(NSNumber *)severity tags:(NSString *)tags format:(NSString *)format arguments:(va_list)arguments
{
    if (_logging || self.teeToSystemLog)
    {
        NSString *timestamp = [CentauriTimestamp ISO8601Timestamp];
        NSString *message = [[NSString alloc] initWithFormat:format arguments:arguments];

        if (self.teeToSystemLog)
        {
            int level = ASL_LEVEL_ERR;
            if (severity)
            {
                NSInteger severityInt = [severity integerValue];
                if (severityInt == CentauriLogWarning)
                {
                    level = ASL_LEVEL_WARNING;
                }
                else if (severityInt == CentauriLogInfo)
                {
                    level = ASL_LEVEL_INFO;
                }
                else if (severityInt == CentauriLogDebug)
                {
                    level = ASL_LEVEL_DEBUG;
                }
            }

            asl_log(NULL, NULL, level, "%s", [message UTF8String]);
        }

        if (self.currentSession && _logging)
        {
            @autoreleasepool
            {
                NSMutableDictionary *dict = [NSMutableDictionary dictionary];
                NSMutableDictionary *info = [NSMutableDictionary dictionary];

                dict[@"timestamp"] = timestamp;
                info[@"process_id"] = @(getpid());
                thread_port_t threadport = pthread_mach_thread_np(pthread_self());
                info[@"thread_id"] = @(threadport);
                if (severity)
                {
                    dict[@"severity"] = severity;
                }
                if (tags)
                {
                    dict[@"tags"] = tags;
                }
                if (!message)
                {
                    message = @"(null)";
                }
                dict[@"message"] = message;

                NSOperationQueue *operationQueue = [NSOperationQueue currentQueue];
                dispatch_queue_t dispatchQueue = dispatch_get_current_queue();
                if (operationQueue != [NSOperationQueue mainQueue])
                {
                    info[@"queue"] = [operationQueue name];
                }
                else if (dispatchQueue != dispatch_get_main_queue())
                {
                    const char *queueName = dispatch_queue_get_label(dispatchQueue);
                    if (queueName != NULL && *queueName != '\0')
                    {
                        info[@"queue"] = [NSString stringWithCString:queueName encoding:NSUTF8StringEncoding];
                    }
                    else
                    {
                        info[@"queue"] = [NSString stringWithFormat:@"%p", dispatchQueue];
                    }
                }
                else
                {
                    info[@"queue"] = @"main";
                }

                if (self.userInfoBlock)
                {
                    self.userInfoBlock(info);
                }

                [self.worker doBlock:^{
                    dict[@"user_info"] = [CentauriSanitizer sanitize:info];
                    if ([self.currentSession bufferMessage:dict])
                    {
                        [self flush];
                    }
                }];
            }
        }
    }
}

- (void) lifecycleNotification:(NSNotification *)notification
{
    [self.worker doBlock:^{
        [[CentauriTransmitter sharedTransmitter] resume];
    }];

    if (self.currentSession)
    {
        if ([notification.name isEqualToString:UIApplicationWillEnterForegroundNotification])
        {
            if (self.currentSession.idleSeconds > self.sessionIdleTimeout)
            {
                [self beginSession:_appToken];
            }
            else
            {
                [self.worker doBlock:^{
                    [self.currentSession resume];
                }];
            }
        }
        else if ([notification.name isEqualToString:UIApplicationDidEnterBackgroundNotification])
        {
            [self.worker doBlock:^{
                [self.currentSession suspend];
                [self flush];
            }];
        }
    }
}

- (void) saveState
{
    [self.state saveSessions:_sessions];
}

@end

/*
 Base64 encoding originally written and copyright (c) 2009 by Matt Gallagher. Modified to encode from/to NSString instead of NSData, and removed the code to generate line breaks.
 */

static unsigned char base64EncodeLookup[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

static NSString * Base64EncodeString(NSString *string)
{
    const int BINARY_UNIT_SIZE = 3;
    const int BASE64_UNIT_SIZE = 4;

    const unsigned char *inputBuffer = (const unsigned char *)[string cStringUsingEncoding:NSUTF8StringEncoding];
    size_t length = strlen((const char *)inputBuffer);

	//
	// Byte accurate calculation of final buffer size
	//
	size_t outputBufferSize = ((length / BINARY_UNIT_SIZE) +
                               ((length % BINARY_UNIT_SIZE) ? 1 : 0))
    * BASE64_UNIT_SIZE;

	//
	// Include space for a terminating zero
	//
	outputBufferSize += 1;

	//
	// Allocate the output buffer
	//
	char *outputBuffer = (char *)malloc(outputBufferSize);
	if (!outputBuffer)
	{
		return nil;
	}

	size_t i = 0;
	size_t j = 0;

    for (; i + BINARY_UNIT_SIZE - 1 < length; i += BINARY_UNIT_SIZE)
    {
        //
        // Inner loop: turn 48 bytes into 64 base64 characters
        //
        outputBuffer[j++] = base64EncodeLookup[(inputBuffer[i] & 0xFC) >> 2];
        outputBuffer[j++] = base64EncodeLookup[((inputBuffer[i] & 0x03) << 4)
                                               | ((inputBuffer[i + 1] & 0xF0) >> 4)];
        outputBuffer[j++] = base64EncodeLookup[((inputBuffer[i + 1] & 0x0F) << 2)
                                               | ((inputBuffer[i + 2] & 0xC0) >> 6)];
        outputBuffer[j++] = base64EncodeLookup[inputBuffer[i + 2] & 0x3F];
    }

	if (i + 1 < length)
	{
		//
		// Handle the single '=' case
		//
		outputBuffer[j++] = base64EncodeLookup[(inputBuffer[i] & 0xFC) >> 2];
		outputBuffer[j++] = base64EncodeLookup[((inputBuffer[i] & 0x03) << 4)
                                               | ((inputBuffer[i + 1] & 0xF0) >> 4)];
		outputBuffer[j++] = base64EncodeLookup[(inputBuffer[i + 1] & 0x0F) << 2];
		outputBuffer[j++] =	'=';
	}
	else if (i < length)
	{
		//
		// Handle the double '=' case
		//
		outputBuffer[j++] = base64EncodeLookup[(inputBuffer[i] & 0xFC) >> 2];
		outputBuffer[j++] = base64EncodeLookup[(inputBuffer[i] & 0x03) << 4];
		outputBuffer[j++] = '=';
		outputBuffer[j++] = '=';
	}
	outputBuffer[j] = 0;

	//
	// Set the output length and return the buffer
	//
    NSUInteger outputLength = j;

    NSString *result = [[NSString alloc] initWithBytes:outputBuffer
                                                length:outputLength
                                              encoding:NSASCIIStringEncoding];
    free(outputBuffer);

    return result;
}
