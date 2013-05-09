//
//  CentauriBuffer.h
//  Centauri
//
//  Created by Steve Madsen on 5/15/13.
//  Copyright (c) 2013 Light Year Software, LLC
//

#import <Foundation/Foundation.h>

@interface CentauriBuffer : NSObject <NSCoding>

@property (copy, nonatomic) NSString *sessiondUUID;
@property (assign, nonatomic) NSInteger sequenceNumber;
@property (copy, nonatomic) NSString *bufferFilePath;
@property (assign, nonatomic) NSUInteger bytesBuffered;
@property (assign, nonatomic) BOOL frozen;

- (id) initWithSessionUUID:(NSString *)uuid sequenceNumber:(NSInteger)sequenceNumber;
- (void) addMessage:(NSDictionary *)message;
- (void) freeze;
- (NSInputStream *) inputStream;
- (void) cleanup;

@end
