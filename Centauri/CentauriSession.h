//
//  CentauriSession.h
//  Centauri
//
//  Created by Steve Madsen on 5/15/13.
//  Copyright (c) 2013 Light Year Software, LLC
//

#import <Foundation/Foundation.h>

@class CentauriWorker;

@interface CentauriSession : NSObject <NSCoding>

@property (copy, nonatomic) NSString *appToken;
@property (copy, nonatomic) NSDictionary *info;
@property (copy, nonatomic) NSString *userID;
@property (copy, nonatomic) NSString *uuid;
@property (nonatomic) NSDate *beginDate;
@property (nonatomic) NSDate *lastActivity;
@property (nonatomic) NSDate *suspendedDate;
@property (assign, nonatomic) BOOL invalid;
@property (nonatomic) NSDate *endDate;
@property (assign, nonatomic) BOOL beginPosted;
@property (assign, nonatomic) BOOL endPosted;
@property (nonatomic) NSMutableArray *unpostedBuffers;
@property (assign, nonatomic) NSUInteger maximumBufferSize;
@property (assign, nonatomic) NSInteger bufferSequenceNumber;

- (id) initWithAppToken:(NSString *)appToken info:(NSDictionary *)info userID:(NSString *)userID;
- (NSTimeInterval) duration;
- (void) suspend;
- (NSTimeInterval) idleSeconds;
- (void) resume;
- (void) invalidate;
- (void) end:(BOOL)abnormal;
- (void) sendToServerWithCompletion:(void (^)(BOOL readyForCleanup))block;
- (void) cleanup;

- (BOOL) bufferMessage:(NSDictionary *)message;

@end
