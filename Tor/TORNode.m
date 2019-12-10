//
//  TORNode.m
//  Tor
//
//  Created by Benjamin Erhart on 09.12.19.
//  Copyright © 2019 Conrad Kramer. All rights reserved.
//

#import "TORNode.h"

@implementation TORNode

// MARK: Class Properties

static NSRegularExpression *_pathRegex;
static NSRegularExpression *_ipv4Regex;
static NSRegularExpression *_ipv6Regex;

+ (NSRegularExpression *)pathRegex
{
    if (!_pathRegex)
    {
        _pathRegex = [[NSRegularExpression alloc]
                      initWithPattern:@"built.*?((?:\\$[\\da-f]+[=~]\\w+[\\s,])+).*(?:launched|built|guard_wait|extended|failed|closed|\\Z)"
                      options:NSRegularExpressionCaseInsensitive
                      error:nil];
    }

    return _pathRegex;
}

+ (NSRegularExpression *)ipv4Regex
{
    if (!_ipv4Regex)
    {
        _ipv4Regex = [[NSRegularExpression alloc]
                      initWithPattern:@"(?:(?:25[0-5]|2[0-4]\\d|[01]?\\d\\d?)\\.){3}(?:25[0-5]|2[0-4]\\d|[01]?\\d\\d?)"
                      options:0 error:nil];
    }

    return _ipv4Regex;
}

+ (NSRegularExpression *)ipv6Regex
{
    if (!_ipv6Regex)
    {
        _ipv6Regex = [[NSRegularExpression alloc]
                      initWithPattern:@"((([\\da-f]{1,4}:){7}([\\da-f]{1,4}|:))|(([\\da-f]{1,4}:){6}(:[\\da-f]{1,4}|((25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]?\\d)(\\.(25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]?\\d)){3})|:))|(([\\da-f]{1,4}:){5}(((:[\\da-f]{1,4}){1,2})|:((25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]?\\d)(\\.(25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]?\\d)){3})|:))|(([\\da-f]{1,4}:){4}(((:[\\da-f]{1,4}){1,3})|((:[\\da-f]{1,4})?:((25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]?\\d)(\\.(25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]?\\d)){3}))|:))|(([\\da-f]{1,4}:){3}(((:[\\da-f]{1,4}){1,4})|((:[\\da-f]{1,4}){0,2}:((25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]?\\d)(\\.(25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]?\\d)){3}))|:))|(([\\da-f]{1,4}:){2}(((:[\\da-f]{1,4}){1,5})|((:[\\da-f]{1,4}){0,3}:((25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]?\\d)(\\.(25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]?\\d)){3}))|:))|(([\\da-f]{1,4}:){1}(((:[\\da-f]{1,4}){1,6})|((:[\\da-f]{1,4}){0,4}:((25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]?\\d)(\\.(25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]?\\d)){3}))|:))|(:(((:[\\da-f]{1,4}){1,7})|((:[\\da-f]{1,4}){0,5}:((25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]?\\d)(\\.(25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]?\\d)){3}))|:)))(%.+)?"
                      options:NSRegularExpressionCaseInsensitive
                      error:nil];
    }

    return _ipv6Regex;
}


// MARK: Static Methods

+ (NSArray<TORNode *> *)firstBuiltPathFromCircuits:(NSString *)circuits
{
    NSMutableArray<TORNode *> *nodes = [NSMutableArray new];

    NSArray<NSTextCheckingResult *> *matches = [TORNode.pathRegex
                                                matchesInString:circuits
                                                options:0
                                                range:NSMakeRange(0, circuits.length)];

    if (matches.firstObject.numberOfRanges > 1)
    {
        NSString *path = [circuits substringWithRange:[matches.firstObject rangeAtIndex:1]];

        NSArray<NSString *> *nodesStrings = [path componentsSeparatedByString:@","];

        for (NSString *node in nodesStrings) {
            [nodes addObject:
             [[TORNode alloc] initFromString:
              [node stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet]]];
        }
    }

    return nodes;
}


// MARK: Initializers

- (instancetype)initFromString:(NSString *)longName
{
    self = [super init];

    if (self)
    {
        NSArray<NSString *> *components = [longName componentsSeparatedByCharactersInSet:
                                           [NSCharacterSet characterSetWithCharactersInString:@"~="]];

        if (components.count > 0)
        {
            self.fingerprint = components[0];
        }

        if (components.count > 1)
        {
            self.nickName = components[1];
        }
    }

    return self;
}


// MARK: Public Methods

- (void)acquireIpAddressesFromNsResponse:(NSString *)response
{
    NSArray<NSTextCheckingResult *> *matches;
    NSRange range = NSMakeRange(0, response.length);

    matches = [TORNode.ipv4Regex matchesInString:response options:0
                                            range:range];

    if (matches.firstObject.numberOfRanges > 0)
    {
        self.ipv4Address = [response substringWithRange:[matches.firstObject rangeAtIndex:0]];
    }

    matches = [TORNode.ipv6Regex matchesInString:response options:0
                                           range:range];

    if (matches.firstObject.numberOfRanges > 0)
    {
        self.ipv6Address = [response substringWithRange:[matches.firstObject rangeAtIndex:0]];
    }
}

- (NSString *)localizedCountryName
{
    if (!self.countryCode)
    {
        return nil;
    }

    if (@available(iOS 10.0, *)) {
        return [NSLocale.currentLocale localizedStringForCountryCode:self.countryCode];
    } else {
        return [NSLocale.currentLocale displayNameForKey:NSLocaleCountryCode value:self.countryCode];
    }
}


// MARK: NSObject

- (NSString *)description
{
    return [NSString stringWithFormat:@"[%@] fingerprint=%@, nickName=%@, ipv4Address=%@, ipv6Address=%@, countryCode=%@, localizedCountryName=%@",
            NSStringFromClass(self.class), self.fingerprint, self.nickName,
            self.ipv4Address, self.ipv6Address, self.countryCode, self.localizedCountryName];
}

@end
