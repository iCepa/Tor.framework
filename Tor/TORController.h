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
 Get a list of all currently available circuits with detailed information about their nodes.

 @note There's no clear way to determine, which circuit actually was used by a specific request.

 @param completion: The callback upon completion of the task.
 @param circuits: A list of `TORCircuit`s . Empty if no circuit could be found.
 */
- (void)getCircuits:(void (^)(NSArray<TORCircuit *> * _Nonnull circuits))completion;

/**
 Resets the Tor connection: Sends "SIGNAL RELOAD" and "SIGNAL NEWNYM" to the Tor thread.

 See https://torproject.gitlab.io/torspec/control-spec.html#signal

 @param completion: Completion callback.
 @param success: true, if signal calls where successful, false if not.
 */
- (void)resetConnection:(void (^__nullable)(BOOL success))completion;

/**
 Try to close a list of circuits identified by their IDs.

 If some closings weren't successful, the most obvious reason would be, that the circuit with the given
 ID doesn't exist (anymore). So in many circumstances, you can still consider that an ok outcome.

 @param circuitIds: List of circuit IDs.
 @param completion: Completion callback.
 @param success: true, if *all* closings were successful, false, if *at least one* closing failed.
 */
- (void)closeCircuitsByIds:(NSArray<NSString *> *)circuitIds completion:(void (^__nullable)(BOOL success))completion;

/**
 Try to close a list of given circuits.

 The given circuits are invalid afterwards, as you just closed them. You should throw them away on completion.

@param circuits: List of circuits to close.
@param completion: Completion callback.
@param success: true, if *all* closings were successful, false, if *at least one* closing failed.
*/
- (void)closeCircuits:(NSArray<TORCircuit *> *)circuits completion:(void (^__nullable)(BOOL success))completion;

// Observers
- (id)addObserverForCircuitEstablished:(void (^)(BOOL established))block;
- (id)addObserverForStatusEvents:(BOOL (^)(NSString *type, NSString *severity, NSString *action, NSDictionary<NSString *, NSString *> * __nullable arguments))block;
- (void)removeObserver:(nullable id)observer;

@end

NS_ASSUME_NONNULL_END
