//
//  Onionmasq.h
//  Tor
//
//  Created by Benjamin Erhart on 30.08.23.
//

#import <Foundation/Foundation.h>
#import <Tor/TORConfiguration.h>

NS_ASSUME_NONNULL_BEGIN

@interface Onionmasq : NSObject


typedef void (^EventCb)(id);


/**
 Start Onionmasq.

 @param fd The file descriptor of the TUN interface.
 @param stateDir Directory, where Arti can store its state. OPTIONAL. If not provided, will use \c Library/Application \c Support/org.torproject.Arti.
 @param cacheDir Directory, where Arti can store its caching data. OPTIONAL. If not providied, will use \c Library/Cache/org.torproject.Arti.
 @param callback Callback, when an event happens.
 */
+ (void)startWithFd:(int32_t)fd stateDir:(NSURL * _Nullable)stateDir cacheDir:(NSURL * _Nullable)cacheDir onEvent:(nullable EventCb)callback;

/**
 Stop Onionmasq.
 */
+ (void)stop;

/**
 Refresh all circuits.

 This causes all new connections after the command is sent to use different circuits to the set currently used.
 */
+ (void)refreshCircuits;

/**
 Get the current count of received bytes since last reset.
 */
+ (long long)getBytesReceived;

/**
 Get the current count of sent bytes since last reset.
 */
+ (long long)getBytesSent;

/**
 Reset the global bandwidth counter.
 */
+ (void)resetCounters;

/**
 Set the country code that proxied connections should use.

 You can clear it back to "no country code" by passing in `nil`.
 */
+ (void)setCountryCodeWith:(NSString * _Nullable)countryCode;


@end

NS_ASSUME_NONNULL_END
