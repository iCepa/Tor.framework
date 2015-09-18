//
//  TORThread.h
//  Tor
//
//  Created by Conrad Kramer on 7/19/15.
//
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class TORConfiguration;

@interface TORThread : NSThread

+ (nullable instancetype)torThread;

- (instancetype)initWithConfiguration:(nullable TORConfiguration *)configuration;
- (instancetype)initWithArguments:(nullable NSArray *)arguments NS_DESIGNATED_INITIALIZER;

@end

NS_ASSUME_NONNULL_END
