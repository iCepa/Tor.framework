//
//  TORConfiguration.m
//  Tor
//
//  Created by Conrad Kramer on 8/10/15.
//  Copyright © 2015 Conrad Kramer. All rights reserved.
//

#include <or/or.h>
#include <or/config.h>
#include <or/confparse.h>

#import <objc/runtime.h>

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

- (void)setDataDirectory:(NSString *)dataDirectory {
    NSMutableDictionary *options = [self.options mutableCopy];
    [options setObject:@(dataDirectory.fileSystemRepresentation) forKey:@"DataDirectory"];
    self.options = [options copy];
}

- (NSString *)dataDirectory {
    return [self.options objectForKey:@"DataDirectory"];
}

- (void)setControlSocket:(NSString *)controlSocket {
    NSMutableDictionary *options = [self.options mutableCopy];
    [options setObject:@(controlSocket.fileSystemRepresentation) forKey:@"ControlSocket"];
    self.options = [options copy];
}

- (NSString *)controlSocket {
    return [self.options objectForKey:@"ControlSocket"];
}

- (void)setSocksPath:(NSString *)socksPath {
    NSMutableDictionary *options = [_options mutableCopy];
    [options setObject:[NSString stringWithFormat:@"unix:%s", socksPath.fileSystemRepresentation] forKey:@"SocksPort"];
    self.options = [options copy];
}

- (NSString *)socksPath {
    NSArray *components = [[self.options objectForKey:@"SocksPort"] componentsSeparatedByString:@":"];
    if ([[components firstObject] isEqualToString:@"unix"])
        return [[components subarrayWithRange:NSMakeRange(1, components.count - 1)] componentsJoinedByString:@":"];
    
    return nil;
}

- (void)setCookieAuthentication:(BOOL)cookieAuthentication {
    NSMutableDictionary *options = [self.options mutableCopy];
    [options setObject:(cookieAuthentication ? @"1" : @"0") forKey:@"CookieAuthentication"];
    self.options = [options copy];
}

- (BOOL)cookieAuthentication {
    return [[self.options objectForKey:@"CookieAuthentication"] boolValue];
}

- (void)loadFromData:(NSData *)data {
    NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (!string)
        return;
    
    NSMutableDictionary<NSString *, NSString *> *options = [NSMutableDictionary new];
    
    config_line_t *lines = NULL;
    if (config_get_lines(string.UTF8String, &lines, 0) == 0) {
        for (config_line_t *line = lines; line; line = line->next) {
            if (line->key && line->value) {
                if (option_is_recognized(line->key) != 0) {
                    [options setObject:@(line->value) forKey:@(line->key)];
                }
            }
        }
        config_free_lines(lines);
    }
    
    NSMutableDictionary *merged = [self.options mutableCopy];
    [merged addEntriesFromDictionary:options];
    self.options = merged;
}

- (void)loadFromFileURL:(NSURL *)fileURL {
    [self loadFromData:[NSData dataWithContentsOfURL:fileURL]];
}

@end
