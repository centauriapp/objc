//
//  CentauriWorker.m
//  Centauri
//
//  Created by Steve Madsen on 5/15/13.
//  Copyright (c) 2013 Light Year Software, LLC
//

#import "CentauriWorker.h"
#import "CentauriDevLog.h"

@implementation CentauriWorker

- (id) initWithName:(NSString *)name
{
    self = [super init];
    if (self)
    {
        self.name = name;
        self.queue = [NSOperationQueue mainQueue];
    }

    return self;
}

- (void) doBlock:(void (^)(void))block
{
    block();
}

@end

@implementation CentauriSerialQueueWorker

- (id) initWithName:(NSString *)name
{
    self = [super initWithName:name];
    if (self)
    {
        self.queue = [[NSOperationQueue alloc] init];
        self.queue.name = name;
        self.queue.maxConcurrentOperationCount = 1;
    }

    return self;
}

- (void) doBlock:(void (^)(void))block
{
    [self.queue addOperationWithBlock:block];
}

@end
