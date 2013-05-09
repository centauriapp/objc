//
//  CentauriState.h
//  Centauri
//
//  Created by Steve Madsen on 5/15/13.
//  Copyright (c) 2013 Light Year Software, LLC
//

#import <Foundation/Foundation.h>

@interface CentauriState : NSObject

- (id) initWithDirectory:(NSString *)directory;
- (NSArray *) loadSessions;
- (void) saveSessions:(NSArray *)sessions;

@end
