//
//  TORConfiguration.m
//  Tor
//
//  Created by Conrad Kramer on 8/10/15.
//  Copyright © 2015 Conrad Kramer. All rights reserved.
//

#import "TORConfiguration.h"

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

- (void)setDataDirectory:(NSURL *)dataDirectory {
    NSMutableDictionary *options = [self.options mutableCopy];
    [options setObject:@(dataDirectory.fileSystemRepresentation) forKey:@"DataDirectory"];
    self.options = [options copy];
}

- (NSURL *)dataDirectory {
    return [NSURL fileURLWithPath:[self.options objectForKey:@"DataDirectory"]];
}

- (void)setControlSocket:(NSURL *)controlSocket {
    NSMutableDictionary *options = [self.options mutableCopy];
    [options setObject:@(controlSocket.fileSystemRepresentation) forKey:@"ControlSocket"];
    self.options = [options copy];
}

- (NSURL *)controlSocket {
    return [NSURL fileURLWithPath:[self.options objectForKey:@"ControlSocket"]];
}

- (void)setSocksURL:(NSURL *)socksURL {
    NSMutableDictionary *options = [_options mutableCopy];
    [options setObject:[NSString stringWithFormat:@"unix:%s", socksURL.fileSystemRepresentation] forKey:@"SocksPort"];
    self.options = [options copy];
}

- (NSURL *)socksURL {
    NSArray *components = [[self.options objectForKey:@"SocksPort"] componentsSeparatedByString:@":"];
    if ([[components firstObject] isEqualToString:@"unix"])
        return [NSURL fileURLWithPath:[[components subarrayWithRange:NSMakeRange(1, components.count - 1)] componentsJoinedByString:@":"]];
    
    return nil;
}

- (void)setCookieAuthentication:(NSNumber *)cookieAuthentication {
    NSMutableDictionary *options = [self.options mutableCopy];
    [options setObject:(cookieAuthentication.boolValue ? @"1" : @"0") forKey:@"CookieAuthentication"];
    self.options = [options copy];
}

- (NSNumber *)cookieAuthentication {
    return @([[self.options objectForKey:@"CookieAuthentication"] boolValue]);
}

@end
