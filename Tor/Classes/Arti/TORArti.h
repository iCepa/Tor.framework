//
//  TORArti.h
//  Tor
//
//  Created by Benjamin Erhart on 02.02.23.
//

#import <Foundation/Foundation.h>
#import <Tor/TORConfiguration.h>

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(TorArti)
@interface TORArti : NSObject

/**
 Start Arti.

 @param socksPort The port to use for accepting SOCKS5 requests.
 @param dnsPort The port to use for accepting DNS requests.
 @param logfile A logfile to write to. OPTIONAL
 @param stateDir Directory, where Arti can store its state. OPTIONAL. If not provided, will use \c Library/Application \c Support/org.torproject.Arti.
 @param cacheDir Directory, where Arti can store its caching data. OPTIONAL. If not providied, will use \c Library/Cache/org.torproject.Arti.
 @param completed Callback when Arti is ready to connect.
 */
+ (void)startWithSocksPort:(NSUInteger)socksPort dnsPort:(NSUInteger)dnsPort logfile:(NSURL * _Nullable)logfile stateDir:(NSURL * _Nullable)stateDir cacheDir:(NSURL * _Nullable)cacheDir completed:(nullable void (^)(void))completed;

+ (void)startWithConfiguration:(TORConfiguration * _Nonnull)configuration completed:(nullable void (^)(void))completed;

@end

NS_ASSUME_NONNULL_END
