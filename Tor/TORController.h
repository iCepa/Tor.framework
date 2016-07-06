//
//  TORController.h
//  Tor
//
//  Created by Conrad Kramer on 5/10/14.
//

#import <Tor/Tor.h>

NS_ASSUME_NONNULL_BEGIN

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

// Commands
- (void)authenticateWithData:(NSData *)data completion:(void (^__nullable)(BOOL success, NSError * __nullable error))completion;
- (void)listenForEvents:(NSArray<NSString *> *)events completion:(void (^__nullable)(BOOL success, NSError * __nullable error))completion;
- (void)getInfoForKeys:(NSArray<NSString *> *)keys completion:(void (^)(NSArray<NSString *> *values))completion; // TODO: Provide errors
- (void)getSessionConfiguration:(void (^)(NSURLSessionConfiguration * __nullable configuration))completion;

// Observers
- (id)addObserverForCircuitEstablished:(void (^)(BOOL established))block;
- (id)addObserverForStatusEvents:(BOOL (^)(NSString *type, NSString *severity, NSString *action, NSDictionary<NSString *, NSString *> * __nullable arguments))block;
- (void)removeObserver:(nullable id)observer;

@end

NS_ASSUME_NONNULL_END
