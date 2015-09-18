//
//  TORController.h
//  Tor
//
//  Created by Conrad Kramer on 5/10/14.
//
//

#import <Tor/Tor.h>

TOR_EXTERN NSString * const TORControllerErrorDomain;

@interface TORController : NSObject

@property (nonatomic, readonly, getter=isConnected) BOOL connected;

- (instancetype)initWithControlSocketPath:(NSString *)path;
- (instancetype)initWithControlSocketPort:(in_port_t)port;

- (BOOL)connect:(out NSError **)error;

// Commands
- (void)authenticateWithData:(NSData *)data completion:(void (^)(BOOL success, NSError *error))completion;
- (void)listenForEvents:(NSArray *)events completion:(void (^)(BOOL success, NSError *error))completion;
- (void)getInfoForKeys:(NSArray *)keys completion:(void (^)(NSArray *values))completion;
- (void)getSessionConfiguration:(void (^)(NSURLSessionConfiguration *configuration))completion;

// Observers
- (id)addObserverForCircuitEstablished:(void (^)(BOOL established))block;
- (id)addObserverForStatusEvents:(BOOL (^)(NSString *type, NSString *severity, NSString *action, NSDictionary *arguments))block;
- (void)removeObserver:(id)observer;

@end
