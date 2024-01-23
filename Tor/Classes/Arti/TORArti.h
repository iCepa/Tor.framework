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
 @param obfs4proxyPath The path to the Obfs4proxy binary. OPTIONAL. Only for MacOS! iOS apps are not allowed to start other processes!
 @param bridge A bridge configuration line needed for the provided Obfs4proxy. OPTIONAL.
 @param completed Callback when Arti is ready to connect.
 */
+ (void)startWithSocksPort:(NSUInteger)socksPort 
                   dnsPort:(NSUInteger)dnsPort
                   logfile:(NSURL * _Nullable)logfile
                  stateDir:(NSURL * _Nullable)stateDir
                  cacheDir:(NSURL * _Nullable)cacheDir
            obfs4proxyPath:(NSURL * _Nullable)obfs4proxyPath
                    bridge:(NSString * _Nullable)bridge
                 completed:(nullable void (^)(void))completed;

+ (void)startWithConfiguration:(TORConfiguration * _Nonnull)configuration completed:(nullable void (^)(void))completed;

@end

NS_ASSUME_NONNULL_END
