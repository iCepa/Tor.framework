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
    if (!_options) _options = [NSDictionary new];
    
    return _options;
}

- (NSArray *)arguments {
    if (!_arguments) _arguments = [NSArray new];
    
    return _arguments;
}

- (nullable NSURL *)controlPortFile {
    return [self.dataDirectory URLByAppendingPathComponent:@"controlport"];
}

- (nullable NSData *)cookie {
    NSURL *url = [self.dataDirectory URLByAppendingPathComponent:@"control_auth_cookie"];

    if (!url) return nil;

    return [[NSData alloc] initWithContentsOfURL:url];
}

- (NSArray<NSString *> *)compile {
    NSMutableArray<NSString *> *arguments = [NSMutableArray new];

    if (self.ignoreMissingTorrc) {
        [arguments addObjectsFromArray:@[@"--allow-missing-torrc", @"--ignore-missing-torrc"]];
    }

    NSString *dataDir = self.dataDirectory.path;
    if (dataDir) {
        [arguments addObjectsFromArray:@[@"--DataDirectory", dataDir]];
    }

    if (self.cookieAuthentication) {
        [arguments addObjectsFromArray:@[@"--CookieAuthentication", @"1"]];
    }

    NSString *controlPortFile = self.controlPortFile.path;
    if (self.autoControlPort && self.controlPortFile.isFileURL && controlPortFile) {
        [arguments addObjectsFromArray:@[@"--ControlPort", @"auto", @"--ControlPortWriteToFile", controlPortFile]];
    }

    NSString *controlSocket = self.controlSocket.path;
    if (self.controlSocket.isFileURL && controlSocket) {
        [arguments addObjectsFromArray:@[@"--ControlSocket", controlSocket]];
    }

    NSString *socksPath = self.socksURL.path;
    if (self.socksURL.isFileURL && socksPath) {
        [arguments addObjectsFromArray:@[@"--SocksPort", [NSString stringWithFormat:@"unix:%@", socksPath]]];
    }

    NSString *clientAuthDir = self.clientAuthDirectory.path;
    if (clientAuthDir) {
        [arguments addObjectsFromArray:@[@"--ClientOnionAuthDir", clientAuthDir]];
    }

    [arguments addObjectsFromArray:self.arguments];

    for (NSString *key in self.options.allKeys) {
        [arguments addObject:[NSString stringWithFormat:@"--%@", key]];

        NSString *value = self.options[key];
        if (value) [arguments addObject:value];
    }

    return arguments;
}

@end

NS_ASSUME_NONNULL_END
