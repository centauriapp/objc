//
//  Centauri.h
//  Centauri
//
//  Created by Steve Madsen on 5/15/13.
//  Copyright (c) 2013 Light Year Software, LLC
//

/*!
 @header
 Centauri is a flexible log capture and session analytics service.
 @author Steve Madsen &lt;steve\@lightyearsoftware.com&gt;
 @copyright (c) 2013 Light Year Software, LLC. All rights reserved.
 @ignorefuncmacro NS_ENUM
 */

#import <Foundation/Foundation.h>

/*!
 @typedef CentauriLogSeverity
 @brief Indicates the severity level of a log message.
 @const CentauriLogError An error, usually unrecoverable.
 @const CentauriLogWarning A warning for something that should not happen, but can be recovered from and is not an error.
 @const CentauriLogInfo Useful information, typically at a high level and very verbose.
 @const CentauriLogDebug Information primarily useful while debugging a problem and otherwise not interesting.
 */
typedef NS_ENUM(NSInteger, CentauriLogSeverity)
{
    CentauriLogError,
    CentauriLogWarning,
    CentauriLogInfo,
    CentauriLogDebug
};

#ifdef __cplusplus
extern "C" {
#endif

    /*!
     @brief The version of the libary.
     */
    extern NSString * const CentauriSDKVersion;

    /*!
     @brief Logs a simple message, with optional arguments.

     This function, just like @link //apple_ref/c/func/NSLog @/link, accepts a format string and optional arguments. It formats the message exactly like @link //apple_ref/occ/cl/NSString @/link, then sends it to @link logSeverity:tags:format:arguments: @/link with severity and tag set to <code>nil</code>.

     A simple way to redirect existing @link //apple_ref/c/func/NSLog @/link statements to this logger is to use this preprocessor macro:

     <code>#define NSLog CENLog</code>
     
     @param format An NSString-style format string.
     */
    void CENLog(NSString *format, ...)
        __attribute__((format(__NSString__, 1, 2)));

    /*!
     @brief Logs a message with tags and optional arguments.

     This function takes an additional argument, <code>tags</code>, over the simpler @link CENLog @/link. When examining logs on the server, you can choose to filter messages by tag. It otherwise acts exactly like @link CENLog @/link.

     How you use tags is entirely your choice. Tags are arbitrary text strings, separated by spaces. They can change from version to version, and show up in some logs and not others. One possible use of tags is for the major components of your app: “network”, “ui”, “core data”, etc. Another is to tag log messages by file. For example, you could redefine @link //apple_ref/c/func/NSLog @/link as:

     <code>#define NSLog(...) CENLogT(\@__FILE__, __VA_ARGS__)</code>

     @param tags A text string that can be used to filter log messages on the server. May be <code>nil</code>, although in that case it’s better to use CENLog().
     @param format An NSString-style format string.
     */
    void CENLogT(NSString *tags, NSString *format, ...)
        __attribute__((format(__NSString__, 2, 3)));

    /*!
     @brief Logs a message at a severity level, with tags and optional arguments.

     This function builds on @link CENLogT @/link, adding a severity level. Severities can also be used to filter messages on the server, but instead of filtering by categorization, it filters on the importantance of the log message.

     @param severity The importance level of the log message.
     @param tags A text string that can be used to filter log messages on the server. May be <code>nil</code>.
     @param format An NSString-style format string.
     */
    void CENLogST(CentauriLogSeverity severity, NSString *tags, NSString *format, ...)
        __attribute__((format(__NSString__, 3, 4)));

#ifdef __cplusplus
}
#endif

/*!
 @brief Primary interface to the Centauri service.
 */
@interface Centauri : NSObject

/*!
 @brief A unique value that you use to identify the person using your app.

 If you wish to associate a given session with a user, set this property to their unique ID. For ad hoc builds, this will often be the UDID. Apps that retrieve the UDID will be rejected from the App Store, so you must consider alternatives when submitting.
 
 The default value for this property is <code>nil</code>.
 */
@property (copy, nonatomic) NSString *userID;

/*!
 @brief Use HTTPS (or not) when communicating with the server.

 When set to <code>YES</code>, all communication with the server use an encrypted connection. When set to <code>NO</code>, regular, unencrypted HTTP is used.

 If you are based in the United States, you should be aware that as of early 2013, using HTTPS and including the library in your App Store build may require you to register your app with the Bureau of Industry and Security; see <a href="http://www.bis.doc.gov/encryption/default.htm">http://www.bis.doc.gov/encryption/default.htm</a>. It is your responsibility to make this judgement for your app.

 The default value for this property is <code>NO</code>.
 */
@property (assign, nonatomic) BOOL useHTTPS;

/*!
 @brief The time (in seconds) that an app can be suspended in the background before resuming starts a new session.
 
 The session idle timeout determines how much time (in seconds) may pass between a user suspending your app (by pressing the home button) and resuming it again for both uses to be considered part of a single session. This allows for brief switches away from your app to maintain a single session and one continuous session log on the server.

 The default value for this property is 300 seconds (5 minutes).
 */
@property (assign, nonatomic) NSTimeInterval sessionIdleTimeout;

/*!
 @brief The maximum number of bytes of messages to buffer before transmitting them to the server.
 
 Log messages are buffered on disk before being sent to the server. When on a cellular network, this reduces the number of times that the cellular radio is powered up to transfer data, which conserves battery power.

 Set this to a large value to further reduce the number of times Centauri hits the network. Set it to a small(er) value to more quickly deliver log messages to the server, at the potential expense of battery power.

 The default value for this property is 65536 bytes (64 KB).
 */
@property (assign, nonatomic) NSUInteger autoFlushThreshold;

/*!
 @brief Controls whether log messages are sent to @link //apple_ref/c/func/NSLog @/link.

 When set to <code>YES</code>, log messages are also sent to the Apple System Log and stderr. This is equivalent to calling @link //apple_ref/c/func/NSLog @/link.
 
 The default value for this property is <code>YES</code>. For shipping apps, you probably want to set this to <code>NO</code>.
 */
@property (assign, nonatomic) BOOL teeToSystemLog;

/*!
 @brief A arbitrary dictionary to associate with every new session.

 Whenever a new session is started, various information about the environment that does not change for the lifetime of the session is collected and sent to the server. This includes the hardware model, OS version, your app version, and the current locale.

 If there is other information you’d like to have available when browsing the logs later, assign a dictionary of that information to this property before calling @link beginSession: @/link.

 Keys with an underscore prefix are reserved and may be overwritten.
 */
@property (copy, nonatomic) NSDictionary *sessionInfo;

/*!
 @brief Provides a hook to supply state information every time a message is logged.

 Every time you log a message, various information about the running state is collected. This information includes a timestamp, the thread ID and dispatch/NSOperation queue name. If there is additional information you wish to capture, you can assign a block to this property that will be invoked every time you log a message. It is passed a mutable dictionary to which you can add your own data.

 The default value for this property is <code>nil</code>.

 @performance A block assigned to this property is called <em>every time</em> you log a message. The block is called on the same thread that you logged the message. The block should be thread-safe and do as little work as possible. <strong>Do not</strong> log additional messages from this block: your app will infinitely recurse and eventually crash when stack is exhausted.
 */
@property (copy, nonatomic) void (^userInfoBlock)(NSMutableDictionary *);

/*!
 @brief Returns the global shared instance.
 */
+ (instancetype) sharedInstance;

/*!
 @brief Marks the beginning of a new user session.

 Call this method when your app first launches to mark the beginning of a new session.

 @param appToken Your app’s unique token
 */
- (void) beginSession:(NSString *)appToken;

/*!
 @brief Marks the end of a user session.

 Call this method when you want to explicitly end a user session. On iOS, this is generally not required. When the user presses the home button to switch away from your app, Centauri automatically suspends the session. If the user returns within the configured idle timeout, the previous session is resumed. Otherwise, a new session is automatically started.

 If your app opts out of background execution, you should call this method from your application delegate’s @link //apple_doc/occ/intfm/UIApplicationDelegate/applicationWillTerminate: @/link.
 */
- (void) endSession;

/*!
 @brief Initiates transmission of data to the server.

 Centauri buffers session and log data to disk until the @link autoFlushThreshold @/link is reached. If your app has just used the network and you know that now is a good time to perform additional network operations, you can call this method to transmit data to the server before the auto-flush threshold is reached.
 */
- (void) flush;

/*!
 @brief Begins buffering log messages.

 Centauri separates session data from log data. While testing your app, there is rarely a reason to differentiate, but the story changes once you ship your app.

 A shipping app can easily have thousands of active users. While log data from production can be extraordinarily helpful to track down a bug, that many users will generate too much data to be useful. Instead, your production app should only turn logging on for users that need it.

 If your app has a server component and users are identifiable (perhaps through an account), add a flag to the server that allows you to turn logging on for individual users. Call this method after fetching the user’s account information when the flag is turned on.

 Another option is to create a custom URL scheme. This URL launches your app, sets a flag to enable logging, probably for a limited duration, then continues normally.
 */
- (void) beginLogging;

/*!
 @brief Ends buffering log messages.

 Call this method to explicitly stop buffering log messages.
 */
- (void) endLogging;

/*!
 @brief Buffers a log message with optional arguments.

 This method is the pure Objective-C interface to log a message. It provides the same functionality as @link CENLogST @/link.

 @param severity The importance level of the log message, boxed in an @link //apple_ref/occ/cl/NSNumber @/link. May be <code>nil</code>.
 @param tags A text string that can be used to filter log messages on the server. May be <code>nil</code>.
 @param message An NSString-style format string.
 */
- (void) logSeverity:(NSNumber *)severity tags:(NSString *)tags message:(NSString *)message, ...
    __attribute__((format(__NSString__, 3, 4)));

/*!
 @brief Buffers a log message (<code>va_list</code> interface).

 This method provides a <code>va_list</code> interface to logging, similar to @link //apple_ref/c/func/NSLogv @/link. It is useful if you have your own logging wrapper that needs a <code>va_list</code> API. Otherwise, the C functions @link CENLog @/link, @link CENLogT @/link or @link CENLogST @/link, or the Objective-C method @link logSeverity:tags:message: @/link, are better choices.

 @param severity The importance level of the log message, boxed in an @link //apple_ref/occ/cl/NSNumber @/link. May be <code>nil</code>.
 @param tags A text string that can be used to filter log messages on the server. May be <code>nil</code>.
 @param format An NSString-style format string.
 @param arguments The variable argument list prepared by <code>va_start</code>.
 */
- (void) logSeverity:(NSNumber *)severity tags:(NSString *)tags format:(NSString *)format arguments:(va_list)arguments;

@end
