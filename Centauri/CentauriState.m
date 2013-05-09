//
//  CentauriState.m
//  Centauri
//
//  Created by Steve Madsen on 5/15/13.
//  Copyright (c) 2013 Light Year Software, LLC
//

#import "CentauriState.h"
#import "CentauriDevLog.h"

@implementation CentauriState
{
    NSString *_archiveFile;
}

- (id) initWithDirectory:(NSString *)directory
{
    self = [super init];
    if (self)
    {
        _archiveFile = [directory stringByAppendingPathComponent:@"centauri.state"];
    }

    return self;
}

- (NSArray *) loadSessions
{
    NSArray *sessions = [NSKeyedUnarchiver unarchiveObjectWithFile:_archiveFile];
    if (sessions == nil)
    {
        CentauriDevLog(@"Initializing new session list");
        sessions = [NSArray array];
    }

    CentauriDevLog(@"Loaded saved sessions: %@", sessions);

    return sessions;
}

- (void) saveSessions:(NSArray *)sessions
{
    CentauriDevLog(@"Saving sessions: %@", sessions);
    [NSKeyedArchiver archiveRootObject:sessions toFile:_archiveFile];
}

@end
