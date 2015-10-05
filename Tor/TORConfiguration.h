//
//  TORConfiguration.h
//  Tor
//
//  Created by Conrad Kramer on 8/10/15.
//  Copyright © 2015 Conrad Kramer. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TORConfiguration : NSObject

@property (nonatomic, copy) NSString *dataDirectory;
@property (nonatomic, copy) NSString *controlSocket;

@property (nonatomic, copy) NSString *socksPath;
@property (nonatomic, copy) NSString *socksHost;
@property (nonatomic) in_port_t socksPort;

@property (nonatomic) BOOL cookieAuthentication;


@property (nonatomic, copy) NSDictionary<NSString *, NSString *> *options;
@property (nonatomic, copy) NSArray<NSString *> *arguments;

#if TARGET_OS_IPHONE
- (void)loadFromData:(NSData *)data;
- (void)loadFromFileURL:(NSURL *)fileURL;
#endif

@end

NS_ASSUME_NONNULL_END
