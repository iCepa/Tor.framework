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

static NSRegularExpression *_circuitSplitRegex;
static NSRegularExpression *_pathRegex;
static NSRegularExpression *_ipv4Regex;
static NSRegularExpression *_ipv6Regex;

+ (NSRegularExpression *)circuitSplitRegex
{
    if (!_circuitSplitRegex)
    {
        _circuitSplitRegex = [NSRegularExpression
                              regularExpressionWithPattern:@"(?:launched|built|guard_wait|extended|failed|closed)"
                              options:NSRegularExpressionCaseInsensitive
                              error:nil];
    }

    return _circuitSplitRegex;

}

+ (NSRegularExpression *)pathRegex
{
    if (!_pathRegex)
    {
        _pathRegex = [NSRegularExpression
                      regularExpressionWithPattern:@"built.*?((?:\\$[\\da-f]+[=~]\\w+[\\s,])+)"
                      options:NSRegularExpressionCaseInsensitive
                      error:nil];
    }

    return _pathRegex;
}

+ (NSRegularExpression *)ipv4Regex
{
    if (!_ipv4Regex)
    {
        _ipv4Regex = [NSRegularExpression
                      regularExpressionWithPattern:@"(?:(?:25[0-5]|2[0-4]\\d|[01]?\\d\\d?)\\.){3}(?:25[0-5]|2[0-4]\\d|[01]?\\d\\d?)"
                      options:0 error:nil];
    }

    return _ipv4Regex;
}

+ (NSRegularExpression *)ipv6Regex
{
    if (!_ipv6Regex)
    {
        _ipv6Regex = [NSRegularExpression
                      regularExpressionWithPattern:@"((([\\da-f]{1,4}:){7}([\\da-f]{1,4}|:))|(([\\da-f]{1,4}:){6}(:[\\da-f]{1,4}|((25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]?\\d)(\\.(25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]?\\d)){3})|:))|(([\\da-f]{1,4}:){5}(((:[\\da-f]{1,4}){1,2})|:((25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]?\\d)(\\.(25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]?\\d)){3})|:))|(([\\da-f]{1,4}:){4}(((:[\\da-f]{1,4}){1,3})|((:[\\da-f]{1,4})?:((25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]?\\d)(\\.(25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]?\\d)){3}))|:))|(([\\da-f]{1,4}:){3}(((:[\\da-f]{1,4}){1,4})|((:[\\da-f]{1,4}){0,2}:((25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]?\\d)(\\.(25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]?\\d)){3}))|:))|(([\\da-f]{1,4}:){2}(((:[\\da-f]{1,4}){1,5})|((:[\\da-f]{1,4}){0,3}:((25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]?\\d)(\\.(25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]?\\d)){3}))|:))|(([\\da-f]{1,4}:){1}(((:[\\da-f]{1,4}){1,6})|((:[\\da-f]{1,4}){0,4}:((25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]?\\d)(\\.(25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]?\\d)){3}))|:))|(:(((:[\\da-f]{1,4}){1,7})|((:[\\da-f]{1,4}){0,5}:((25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]?\\d)(\\.(25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]?\\d)){3}))|:)))(%.+)?"
                      options:NSRegularExpressionCaseInsensitive
                      error:nil];
    }

    return _ipv6Regex;
}


// MARK: Static Methods

+ (NSArray<NSArray<TORNode *> *> *)builtPathsFromCircuits:(NSString *)circuitsString
{
    // First step: Split circuits.
    NSArray<NSTextCheckingResult *> *matches = [TORNode.circuitSplitRegex
                                                matchesInString:circuitsString
                                                options:0
                                                range:NSMakeRange(0, circuitsString.length)];

    NSMutableArray<NSString *> *circuitStrings = [NSMutableArray new];

    for (NSUInteger i = 0; i < matches.count; i++)
    {
        NSUInteger location = [matches[i] rangeAtIndex:0].location;
        NSRange range;

        // Last one. Take everything until the end!
        if (i >= matches.count - 1)
        {
            range = NSMakeRange(location, circuitsString.length - location);
        }
        else {
            range = NSMakeRange(location, [matches[i + 1] rangeAtIndex:0].location - location);
        }

        [circuitStrings addObject:[circuitsString substringWithRange:range]];
    }


    // Second step: Identify "BUILT" circuits, extract path, create TORNode
    // objects from that and return an array of arrays of TORNodes.
    NSMutableArray<NSMutableArray<TORNode *> *> * circuits = [NSMutableArray new];
    NSMutableArray<TORNode *> *map = [NSMutableArray new];

    for (NSString *circuit in circuitStrings)
    {
        matches = [TORNode.pathRegex
                   matchesInString:circuit options:0
                   range:NSMakeRange(0, circuit.length)];

        if (matches.firstObject.numberOfRanges > 1)
        {
            NSString *path = [circuit substringWithRange:[matches.firstObject rangeAtIndex:1]];

            NSArray<NSString *> *nodesStrings = [path componentsSeparatedByString:@","];
            NSMutableArray<TORNode *> * nodes = [NSMutableArray new];

            for (NSString *nodeString in nodesStrings)
            {
                TORNode *node = [[TORNode alloc] initFromString:
                                 [nodeString stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet]];

                // Don't duplicate objects, link by reference!
                if ([map containsObject:node])
                {
                    [nodes addObject:[map objectAtIndex:[map indexOfObject:node]]];
                }
                else {
                    [map addObject:node];
                    [nodes addObject:node];
                }
            }

            if (nodes.count > 0)
            {
                [circuits addObject:nodes];
            }
        }
    }

    return circuits;
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

- (BOOL)isEqual:(id)other
{
    if (other == self)
    {
        return YES;
    }

    if (!other || ![other isKindOfClass:self.class])
    {
        return NO;
    }

    return [self.fingerprint isEqualToString:((TORNode *)other).fingerprint];
}

- (NSUInteger)hash
{
    return self.fingerprint.hash;
}

@end
