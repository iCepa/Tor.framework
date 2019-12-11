//
//  TORController.h
//  Tor
//
//  Created by Conrad Kramer on 5/10/14.
//

#import <Tor/Tor.h>

NS_ASSUME_NONNULL_BEGIN

typedef BOOL (^TORObserverBlock)(NSArray<NSNumber *> *codes, NSArray<NSData *> *lines, BOOL *stop);

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 100000 || __MAC_OS_X_VERSION_MAX_ALLOWED >= 101200
TOR_EXTERN NSErrorDomain const TORControllerErrorDomain;
#else
TOR_EXTERN NSString * const TORControllerErrorDomain;
#endif

NS_SWIFT_NAME(TorController)
@interface TORController : NSObject

@property (nonatomic, readonly, copy) NSOrderedSet<NSString *> *events;
@property (nonatomic, readonly, getter=isConnected) BOOL connected;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithSocketURL:(NSURL *)url NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithSocketHost:(NSString *)host port:(in_port_t)port NS_DESIGNATED_INITIALIZER;

- (BOOL)connect:(out NSError **)error;
- (void)disconnect;

// Commands
- (void)authenticateWithData:(NSData *)data completion:(void (^__nullable)(BOOL success, NSError * __nullable error))completion;
- (void)resetConfForKey:(NSString *)key completion:(void (^__nullable)(BOOL success, NSError * __nullable error))completion;
- (void)setConfForKey:(NSString *)key withValue:(NSString *)value completion:(void (^__nullable)(BOOL success, NSError * __nullable error))completion;
- (void)setConfs:(NSArray<NSDictionary *> *)configs completion:(void (^__nullable)(BOOL success, NSError * __nullable error))completion;
- (void)listenForEvents:(NSArray<NSString *> *)events completion:(void (^__nullable)(BOOL success, NSError * __nullable error))completion;
- (void)getInfoForKeys:(NSArray<NSString *> *)keys completion:(void (^)(NSArray<NSString *> *values))completion; // TODO: Provide errors
- (void)getSessionConfiguration:(void (^)(NSURLSessionConfiguration * __nullable configuration))completion;
- (void)sendCommand:(NSString *)command arguments:(nullable NSArray<NSString *> *)arguments data:(nullable NSData *)data observer:(TORObserverBlock)observer;

/**
 Get a list of built circuits as a list of `TorNodes` containing detailed information about the node.

 @note There's no clear way to determine, which circuit actually was used by a specific request.

 @param completion: The callback upon completion of the task.
 @param circuits: A list of circuits as a list of `TORNodes` . Empty if no circuit could be found.
 */
- (void)getBuiltCircuits:(void (^)(NSArray<NSArray<TORNode *> *> * _Nonnull circuits))completion;

/**
 Resets the Tor connection: Sends "SIGNAL RELOAD" and "SIGNAL NEWNYM" to the Tor thread.

 See https://torproject.gitlab.io/torspec/control-spec.html#signal

 @param success: true, if signal calls where successful, false if not.
 */
- (void)resetConnection:(void (^__nullable)(BOOL success))completion;

// Observers
- (id)addObserverForCircuitEstablished:(void (^)(BOOL established))block;
- (id)addObserverForStatusEvents:(BOOL (^)(NSString *type, NSString *severity, NSString *action, NSDictionary<NSString *, NSString *> * __nullable arguments))block;
- (void)removeObserver:(nullable id)observer;

@end

NS_ASSUME_NONNULL_END
