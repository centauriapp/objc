//
//  CentauriInMemoryState.m
//  Centauri
//
//  Created by Steve Madsen on 5/16/13.
//  Copyright (c) 2013 Light Year Software, LLC
//

#import "CentauriInMemoryState.h"

@implementation CentauriInMemoryState

- (id) initWithDirectory:(NSString *)directory
{
    self = [super init];
    if (self)
    {
        self.savedSessions = [NSArray array];
    }

    return self;
}

- (NSArray *) loadSessions
{
    return self.savedSessions;
}

- (void) saveSessions:(NSArray *)sessions
{
    self.savedSessions = sessions;
}

@end
