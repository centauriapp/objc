//
//  CentauriInMemoryState.h
//  Centauri
//
//  Created by Steve Madsen on 5/16/13.
//  Copyright (c) 2013 Light Year Software, LLC
//

#import "CentauriState.h"

@interface CentauriInMemoryState : CentauriState

@property (copy, nonatomic) NSArray *savedSessions;

@end
