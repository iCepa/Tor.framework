//
//  TORController.h
//  Tor
//
//  Created by Conrad Kramer on 5/10/14.
//
//

#import <Tor/Tor.h>

NS_ASSUME_NONNULL_BEGIN

TOR_EXTERN NSString * const TORControllerErrorDomain;

@interface TORController : NSObject

@property (nonatomic, readonly, getter=isConnected) BOOL connected;

- (instancetype)initWithSocketURL:(NSURL *)url;
- (instancetype)initWithSocketHost:(NSString *)host port:(in_port_t)port;

- (BOOL)connect:(out NSError **)error;

// Commands
- (void)authenticateWithData:(NSData *)data completion:(void (^__nullable)(BOOL success, NSError * __nullable error))completion;
- (void)listenForEvents:(NSArray *)events completion:(void (^__nullable)(BOOL success, NSError * __nullable error))completion;
- (void)getInfoForKeys:(NSArray *)keys completion:(void (^)(NSArray *values))completion;
- (void)getSessionConfiguration:(void (^)(NSURLSessionConfiguration *configuration))completion;

// Observers
- (id)addObserverForCircuitEstablished:(void (^)(BOOL established))block;
- (id)addObserverForStatusEvents:(BOOL (^)(NSString *type, NSString *severity, NSString *action, NSDictionary * __nullable arguments))block;
- (void)removeObserver:(nullable id)observer;

@end

NS_ASSUME_NONNULL_END
