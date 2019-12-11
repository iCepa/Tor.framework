//
//  TORCircuit.h
//  Tor
//
//  Created by Benjamin Erhart on 11.12.19.
//  Copyright © 2019 Conrad Kramer. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Tor/TORNode.h>

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(TorCircuit)
@interface TORCircuit : NSObject

/**
 Regular expression to find the beginning of a circuit line in a string soup as returned by "GETINFO circuit-status".
 */
@property (class, readonly) NSRegularExpression *circuitSplitRegex;

/**
 Regular expression to identify and extract a circuit path of a `BUILT` circuit consisting of "LongNames".

 A usable circuit has status "BUILT":
 https://torproject.gitlab.io/torspec/control-spec.html#circuit-status-changed

 Syntax of node "LongNames":
 https://torproject.gitlab.io/torspec/control-spec.html#general-use-tokens
 */
@property (class, readonly) NSRegularExpression *statusAndPathRegex;


@property (readonly) NSString *raw;
@property (readonly) NSString *status;
@property (readonly) NSArray<TORNode *> *nodes;
@property (readonly) NSString *buildFlags;
@property (readonly) NSString *purpose;
@property (readonly) NSString *hsState;
@property (readonly) NSString *rendQuery;
@property (readonly) NSString *timeCreated;
@property (readonly) NSString *reason;
@property (readonly) NSString *remoteReason;
@property (readonly) NSString *socksUsername;
@property (readonly) NSString *socksPassword;


/**
Extracts all circuit info from a string which should be the response to a "GETINFO circuit-status".

See https://torproject.gitlab.io/torspec/control-spec.html#getinfo

@param circuits: A string as returned by "GETINFO circuit-status".
*/
+ (NSArray<TORCircuit *> *)circuitsFromString:(NSString *)circuitsString;


- (instancetype)initFromString:(NSString *)circuitString;


@end

NS_ASSUME_NONNULL_END
