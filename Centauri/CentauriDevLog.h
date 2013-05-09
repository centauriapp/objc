//
//  CentauriDevLog.h
//  Centauri
//
//  Created by Steve Madsen on 6/2/13.
//  Copyright (c) 2013 Light Year Software, LLC
//

/*
 If you are working on the Centauri client library and change this to enable debug logging within the library itself, be careful not to commit this file back to the repository.

 One good way to protect yourself from an accidental commit is to tell Git to ignore changes to this file with "git update-index --assume-unchanged CentauriDevLog.h".
 */
#if 0

#ifdef NSLog
#undef NSLog
#endif

#define CentauriDevLog NSLog

#else

#define CentauriDevLog(...) do {} while(0)

#endif
