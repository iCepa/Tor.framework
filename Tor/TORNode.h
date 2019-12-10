//
//  TORNode.h
//  Tor
//
//  Created by Benjamin Erhart on 09.12.19.
//  Copyright © 2019 Conrad Kramer. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(TorNode)
@interface TORNode : NSObject

/**
 Regular expression to identify and extract a circuit path of a `BUILT` circuit consisting of "LongNames".

 A usable circuit has status "BUILT":
 https://torproject.gitlab.io/torspec/control-spec.html#circuit-status-changed

 Syntax of node "LongNames":
 https://torproject.gitlab.io/torspec/control-spec.html#general-use-tokens
 */
@property (class, nonatomic, readonly) NSRegularExpression *pathRegex;

/**
Regular expression to identify and extract a valid IPv4 address.

Taken from https://nbviewer.jupyter.org/github/rasbt/python_reference/blob/master/tutorials/useful_regex.ipynb
*/
@property (class, nonatomic, readonly) NSRegularExpression *ipv4Regex;

/**
Regular expression to identify and extract a valid IPv6 address.

Taken from https://nbviewer.jupyter.org/github/rasbt/python_reference/blob/master/tutorials/useful_regex.ipynb
*/
@property (class, nonatomic, readonly) NSRegularExpression *ipv6Regex;

/**
 The fingerprint aka. ID of a Tor node.
 */
@property (nonatomic) NSString *fingerprint;

/**
 The nickname of a Tor node.
 */
@property (nonatomic) NSString *nickName;

/**
 The IPv4 address of a Tor node.
 */
@property (nonatomic) NSString *ipv4Address;

/**
 The IPv6 address of a Tor node.
 */
@property (nonatomic) NSString *ipv6Address;

/**
 The country code of a Tor node's country.
 */
@property (nonatomic) NSString *countryCode;

/**
 The localized country name of a Tor node's country.
 */
@property (nonatomic, readonly) NSString *localizedCountryName;

+ (NSArray<TORNode *> *)builtPathFromCircuits:(NSString *)circuits;

/**
 Create a `TORNode` object from a "LongName" node string which should contain the fingerprint and the nickname.

 See https://torproject.gitlab.io/torspec/control-spec.html#general-use-tokens

 - parameter longName: A "LongName" identifying a Tor node.
 */
- (instancetype)initFromString:(NSString *)longName;

/**
 Acquires IPv4 and IPv6 addresses from the given string.

 See https://torproject.gitlab.io/torspec/control-spec.html#getinfo

 - parameter response: Should be the response of a `ns/id/<fingerprint>` call.
 */
- (void)acquireIpAddressesFromNsResponse:(NSString *)response;

@end

NS_ASSUME_NONNULL_END
