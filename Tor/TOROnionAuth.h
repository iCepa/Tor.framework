//
//  TOROnionAuth.h
//  Tor
//
//  Created by Benjamin Erhart on 29.09.21.
//

#import <Foundation/Foundation.h>
#import <Tor/TORAuthKey.h>

NS_ASSUME_NONNULL_BEGIN

/**
 Support for Onion v3 service authentication configuration files.
 */
NS_SWIFT_NAME(TorOnionAuth)
@interface TOROnionAuth : NSObject

/**
 The base directory where this instance operates on.
 */
@property (nonatomic, nonnull, readonly) NSURL *directory;

/**
 The found public and/or private keys in the base \c directory.

 @see -directory
 */
@property (nonatomic, nonnull, readonly) NSArray<TORAuthKey *> *keys;


/**
 Initialize with a given directory. Will immediately read all keys on disk.

 If you have a lot of keys, you might want to do this in a background thread!

 @param url  The base directory where the configuration files live.
 Should be the same as you set in \c <ClientOnionAuthDir> for clients  or the
 \c <HiddenServiceDir>/authorized_clients directory for servers.

 @see https://2019.www.torproject.org/docs/tor-manual.html.en#ClientOnionAuthDir

 @see https://2019.www.torproject.org/docs/tor-manual.html.en#HiddenServiceDir

 @see https://2019.www.torproject.org/docs/tor-manual.html.en#_client_authorization
 */
- (instancetype)initWithDirUrl:(NSURL *)url;

/**
 Initialize with a given directory. Will immediately read all keys on disk.

 If you have a lot of keys, you might want to do this in a background thread!

 @param path  The base directory where the configuration files live.
 Should be the same as you set in \c <ClientOnionAuthDir> for clients  or the
 \c <HiddenServiceDir>/authorized_clients directory for servers.

 @see https://2019.www.torproject.org/docs/tor-manual.html.en#ClientOnionAuthDir

 @see https://2019.www.torproject.org/docs/tor-manual.html.en#HiddenServiceDir

 @see https://2019.www.torproject.org/docs/tor-manual.html.en#_client_authorization
 */
- (instancetype)initWithDir:(NSString *)path;


/**
 Add an authentication key (public or private) to the configuration.

 If a key with the same file name already exists, it will be overwritten. If not, it will be added at the end of the
 \c keys array.

 @param key A new or modified key.
 */
- (void)set:(TORAuthKey *)key;

/**
 Remove the key at the specified index.

 @param idx The index of the key in \c keys.

 @returns \c YES on success, \c NO on failure.
 */
- (BOOL)removeKeyAtIndex:(NSInteger)idx;

@end

NS_ASSUME_NONNULL_END
