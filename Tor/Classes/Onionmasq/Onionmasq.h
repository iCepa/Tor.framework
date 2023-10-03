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


typedef void (^ReaderCb)(void);
typedef bool (^WriterCb)(NSData *packet, NSNumber *version);
typedef void (^EventCb)(id);
typedef void (^LogCb)(NSString *message);

/**
 Start Onionmasq.

 @param readerCallback Called, when Onionmasq wants to read to the TUN interface. After read, this method **needs to call** `receive`!
 @param writerCallback Called, when Onionmasq wants to write to the TUN interface.
 @param stateDir Directory, where Arti can store its state. OPTIONAL. If not provided, will use \c Library/Application \c Support/org.torproject.Arti.
 @param cacheDir Directory, where Arti can store its caching data. OPTIONAL. If not providied, will use \c Library/Cache/org.torproject.Arti.
 @param pcapFile File to write a network trace in PCAP format to.
 @param eventCallback Callback, when an event happens.
 @param logCallback Callback, when a log message arrives.
 */
+ (void)startWithReader:(ReaderCb)readerCallback
                 writer:(WriterCb)writerCallback
               stateDir:(NSURL * _Nullable)stateDir
               cacheDir:(NSURL * _Nullable)cacheDir
               pcapFile:(NSURL * _Nullable)pcapFile
                onEvent:(nullable EventCb)eventCallback
                  onLog:(nullable LogCb)logCallback;

/**
 Stop Onionmasq.
 */
+ (void)stop;

/**
 Refresh all circuits.

 This causes all new connections after the command is sent to use different circuits to the set currently used.
 */
+ (void)refreshCircuits;


+ (void)setPcapPath:(NSURL *)path;


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

/**
 You need to call this, when your `readerCallback` has read data from the TUN device.

 @param packets Packets of data.
 */
+ (void)receive:(NSArray<NSData *> *)packets;


@end

NS_ASSUME_NONNULL_END
