//
//  CentauriWorker.h
//  Centauri
//
//  Created by Steve Madsen on 5/15/13.
//  Copyright (c) 2013 Light Year Software, LLC
//

#import <Foundation/Foundation.h>

@interface CentauriWorker : NSObject

@property (copy) NSString *name;
@property NSOperationQueue *queue;

- (id) initWithName:(NSString *)name;
- (void) doBlock:(void (^)(void))block;

@end

@interface CentauriSerialQueueWorker : CentauriWorker

@end