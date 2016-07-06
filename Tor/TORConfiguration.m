//
//  TORConfiguration.m
//  Tor
//
//  Created by Conrad Kramer on 8/10/15.
//

#import "TORConfiguration.h"

NS_ASSUME_NONNULL_BEGIN

@implementation TORConfiguration

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
    options[@"DataDirectory"] = @(dataDirectory.fileSystemRepresentation);
    self.options = options;
}

- (nullable NSURL *)dataDirectory {
    NSString *path = self.options[@"DataDirectory"];
    return (path ? [NSURL fileURLWithPath:path] : nil);
}

- (void)setControlSocket:(nullable NSURL *)controlSocket {
    NSMutableDictionary *options = [self.options mutableCopy];
    options[@"ControlSocket"] = @(controlSocket.fileSystemRepresentation);
    self.options = options;
}

- (nullable NSURL *)controlSocket {
    NSString *path = self.options[@"ControlSocket"];
    return (path ? [NSURL fileURLWithPath:path] : nil);
}

- (void)setSocksURL:(nullable NSURL *)socksURL {
    NSMutableDictionary *options = [_options mutableCopy];
    [options setObject:[NSString stringWithFormat:@"unix:%s", socksURL.fileSystemRepresentation] forKey:@"SocksPort"];
    self.options = options;
}

- (nullable NSURL *)socksURL {
    NSArray<NSString *> *components = [self.options[@"SocksPort"] componentsSeparatedByString:@":"];
    if ([components.firstObject isEqualToString:@"unix"])
        return [NSURL fileURLWithPath:[[components subarrayWithRange:NSMakeRange(1, components.count - 1)] componentsJoinedByString:@":"]];
    
    return nil;
}

- (void)setCookieAuthentication:(nullable NSNumber *)cookieAuthentication {
    NSMutableDictionary *options = [self.options mutableCopy];
    options[@"CookieAuthentication"] = (cookieAuthentication.boolValue ? @"1" : @"0");
    self.options = options;
}

- (nullable NSNumber *)cookieAuthentication {
    NSString *cookieAuthentication = self.options[@"CookieAuthentication"];
    return (cookieAuthentication ? @(cookieAuthentication.boolValue) : nil);
}

@end

NS_ASSUME_NONNULL_END
