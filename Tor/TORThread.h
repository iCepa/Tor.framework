//
//  TORThread.h
//  Tor
//
//  Created by Conrad Kramer on 7/19/15.
//
//

#import <Foundation/Foundation.h>

@class TORConfiguration;

@interface TORThread : NSThread

+ (instancetype)torThread;

- (instancetype)initWithConfiguration:(TORConfiguration *)configuration;
- (instancetype)initWithArguments:(NSArray *)arguments NS_DESIGNATED_INITIALIZER;

@end
