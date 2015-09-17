//
//  TORThread.m
//  Tor
//
//  Created by Conrad Kramer on 7/19/15.
//
//

#include <or/or.h>
#include <or/main.h>

#import "TORThread.h"
#import "TORConfiguration.h"

static TORThread *_thread = nil;

@interface TORThread ()

@property (nonatomic, readonly, copy) NSArray *arguments;

@end

@implementation TORThread

+ (instancetype)torThread {
    return _thread;
}

- (instancetype)init {
    return [self initWithArguments:nil];
}

- (instancetype)initWithConfiguration:(TORConfiguration *)configuration {
    NSMutableArray *arguments = [configuration.arguments mutableCopy];
    for (NSString *key in configuration.options) {
        [arguments addObject:[NSString stringWithFormat:@"--%@", key]];
        [arguments addObject:[configuration.options objectForKey:key]];
    }
    return [self initWithArguments:arguments];
}

- (instancetype)initWithArguments:(NSArray *)arguments {
    NSAssert(_thread == nil, @"There can only be one TORThread per process");
    self = [super init];
    if (self) {
        _thread = self;
        _arguments = [arguments copy];
        
        self.name = @"Tor";
    }
    return self;
}

- (void)main {
    NSArray *arguments = self.arguments;
    int argc = (int)(arguments.count + 1);
    char *argv[argc];
    argv[0] = "tor";
    for (NSUInteger idx = 0; idx < arguments.count; idx++)
        argv[idx + 1] = (char *)[arguments[idx] UTF8String];
    argv[argc] = NULL;
    
    tor_main(argc, argv);
}

@end
