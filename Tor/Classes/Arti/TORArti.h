//
//  TORArti.h
//  Tor
//
//  Created by Benjamin Erhart on 02.02.23.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(TorArti)
@interface TORArti : NSObject

+ (void)startWithSocksPort:(NSUInteger)socksPort dnsPort:(NSUInteger)dnsPort logfile:(NSURL * _Nullable)logfile;

@end

NS_ASSUME_NONNULL_END
