//
//  TORConfiguration.m
//  Tor
//
//  Created by Conrad Kramer on 8/10/15.
//

#import "TORConfiguration.h"

NS_ASSUME_NONNULL_BEGIN

@implementation TORConfiguration

static NSString * const kDataDirectory = @"DataDirectory";
static NSString * const kControlSocket = @"ControlSocket";
static NSString * const kSocksPort = @"SocksPort";
static NSString * const kCookieAuthentication = @"CookieAuthentication";

- (NSDictionary *)options {
    if (!_options)
        _options = [NSDictionary new];
    
    return _options;
}

- (NSArray *)arguments {
    if (!_arguments)
        _arguments = [NSArray new];
    
    return _arguments;
}

- (void)setDataDirectory:(nullable NSURL *)dataDirectory {
    NSMutableDictionary *options = [self.options mutableCopy];
    if (!dataDirectory) {
        [options removeObjectForKey:kDataDirectory];
    } else {
        options[kDataDirectory] = @((const char * _Nonnull)dataDirectory.fileSystemRepresentation);
    }
    self.options = options;
}

- (nullable NSURL *)dataDirectory {
    NSString *path = self.options[kDataDirectory];
    return (path ? [NSURL fileURLWithPath:path] : nil);
}

- (void)setControlSocket:(nullable NSURL *)controlSocket {
    NSMutableDictionary *options = [self.options mutableCopy];
    if (!controlSocket) {
        [options removeObjectForKey:kControlSocket];
    } else {
        options[kControlSocket] = @((const char * _Nonnull)controlSocket.fileSystemRepresentation);
    }
    self.options = options;
}

- (nullable NSURL *)controlSocket {
    NSString *path = self.options[kControlSocket];
    return (path ? [NSURL fileURLWithPath:path] : nil);
}

- (void)setSocksURL:(nullable NSURL *)socksURL {
    NSMutableDictionary *options = [_options mutableCopy];
    [options setObject:[NSString stringWithFormat:@"unix:%s", socksURL.fileSystemRepresentation] forKey:kSocksPort];
    self.options = options;
}

- (nullable NSURL *)socksURL {
    NSArray<NSString *> *components = [self.options[kSocksPort] componentsSeparatedByString:@":"];
    if ([components.firstObject isEqualToString:@"unix"])
        return [NSURL fileURLWithPath:[[components subarrayWithRange:NSMakeRange(1, components.count - 1)] componentsJoinedByString:@":"]];
    
    return nil;
}

- (void)setCookieAuthentication:(nullable NSNumber *)cookieAuthentication {
    NSMutableDictionary *options = [self.options mutableCopy];
    options[kCookieAuthentication] = (cookieAuthentication.boolValue ? @"1" : @"0");
    self.options = options;
}

- (nullable NSNumber *)cookieAuthentication {
    NSString *cookieAuthentication = self.options[kCookieAuthentication];
    return (cookieAuthentication ? @(cookieAuthentication.boolValue) : nil);
}

@end

NS_ASSUME_NONNULL_END
