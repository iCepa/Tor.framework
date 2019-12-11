//
//  TORCircuit.m
//  Tor
//
//  Created by Benjamin Erhart on 11.12.19.
//  Copyright © 2019 Conrad Kramer. All rights reserved.
//

#import "TORCircuit.h"

@implementation TORCircuit


// MARK: Class Properties

static NSRegularExpression *_circuitSplitRegex;
static NSRegularExpression *_statusAndPathRegex;
static NSMutableDictionary<NSString *, NSRegularExpression *> *_optionsRegexes;

+ (NSRegularExpression *)circuitSplitRegex
{
    if (!_circuitSplitRegex)
    {
        _circuitSplitRegex =
        [NSRegularExpression
         regularExpressionWithPattern:@"(?:LAUNCHED|BUILT|GUARD_WAIT|EXTENDED|FAILED|CLOSED)"
         options:NSRegularExpressionCaseInsensitive error:nil];
    }

    return _circuitSplitRegex;
}

+ (NSRegularExpression *)statusAndPathRegex
{
    if (!_statusAndPathRegex)
    {
        _statusAndPathRegex =
        [NSRegularExpression
         regularExpressionWithPattern:
         @"(LAUNCHED|BUILT|GUARD_WAIT|EXTENDED|FAILED|CLOSED)\\s+((?:\\$[\\da-f]+[=~]\\w+(?:,|\\s|\\Z))+)"
         options:NSRegularExpressionCaseInsensitive error:nil];
    }

    return _statusAndPathRegex;
}


// MARK: Class Methods

+ (NSRegularExpression *)regexForOption:(NSString *)option
{
    if (!_optionsRegexes)
    {
        _optionsRegexes = [NSMutableDictionary new];
    }

    if (!_optionsRegexes[option])
    {
        _optionsRegexes[option] =
        [NSRegularExpression
         regularExpressionWithPattern:[NSString stringWithFormat:@"(?:%@=(.+?)(?:\\s|\\Z))", option]
         options:NSRegularExpressionCaseInsensitive error:nil];
    }

    return _optionsRegexes[option];
}

+ (NSArray<TORCircuit *> *)circuitsFromString:(NSString *)circuitsString
{
    NSMutableArray<TORCircuit *> *circuits = [NSMutableArray new];

    NSArray<NSTextCheckingResult *> *matches = [TORCircuit.circuitSplitRegex
                                                matchesInString:circuitsString
                                                options:0
                                                range:NSMakeRange(0, circuitsString.length)];

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

        [circuits addObject:
         [[TORCircuit alloc] initFromString:
          [[circuitsString substringWithRange:range]
           stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]]];
    }

    return circuits;
}


// MARK: Initializers

- (instancetype)initFromString:(NSString *)circuitString
{
    self = [super init];

    if (self)
    {
        _raw = circuitString;

        NSRange range = NSMakeRange(0, circuitString.length);

        NSArray<NSTextCheckingResult *> *matches = [TORCircuit.statusAndPathRegex
                                                    matchesInString:circuitString options:0
                                                    range:range];

        if (matches.firstObject.numberOfRanges > 1)
        {
            _status = [circuitString substringWithRange:[matches.firstObject rangeAtIndex:1]];
        }

        if (matches.firstObject.numberOfRanges > 2)
        {
            NSMutableArray<TORNode *> *nodes = [NSMutableArray new];

            NSString *path = [circuitString substringWithRange:[matches.firstObject rangeAtIndex:2]];

            NSArray<NSString *> *nodesStrings = [path componentsSeparatedByString:@","];

            for (NSString *nodeString in nodesStrings)
            {
                [nodes addObject:
                 [[TORNode alloc] initFromString:
                  [nodeString stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet]]];
            }

            _nodes = nodes;
        }

        matches = [[TORCircuit regexForOption:@"BUILD_FLAGS"]
                   matchesInString:circuitString options:0 range:range];

        if (matches.firstObject.numberOfRanges > 1)
        {
            _buildFlags = [circuitString substringWithRange:[matches.firstObject rangeAtIndex:1]];
        }

        matches = [[TORCircuit regexForOption:@"PURPOSE"]
                   matchesInString:circuitString options:0 range:range];

        if (matches.firstObject.numberOfRanges > 1)
        {
            _purpose = [circuitString substringWithRange:[matches.firstObject rangeAtIndex:1]];
        }

        matches = [[TORCircuit regexForOption:@"HS_STATE"]
                   matchesInString:circuitString options:0 range:range];

        if (matches.firstObject.numberOfRanges > 1)
        {
            _hsState = [circuitString substringWithRange:[matches.firstObject rangeAtIndex:1]];
        }

        matches = [[TORCircuit regexForOption:@"REND_QUERY"]
                   matchesInString:circuitString options:0 range:range];

        if (matches.firstObject.numberOfRanges > 1)
        {
            _rendQuery = [circuitString substringWithRange:[matches.firstObject rangeAtIndex:1]];
        }

        matches = [[TORCircuit regexForOption:@"TIME_CREATED"]
                   matchesInString:circuitString options:0 range:range];

        if (matches.firstObject.numberOfRanges > 1)
        {
            _timeCreated = [circuitString substringWithRange:[matches.firstObject rangeAtIndex:1]];
        }

        matches = [[TORCircuit regexForOption:@"REASON"]
                   matchesInString:circuitString options:0 range:range];

        if (matches.firstObject.numberOfRanges > 1)
        {
            _reason = [circuitString substringWithRange:[matches.firstObject rangeAtIndex:1]];
        }

        matches = [[TORCircuit regexForOption:@"REMOTE_REASON"]
                   matchesInString:circuitString options:0 range:range];

        if (matches.firstObject.numberOfRanges > 1)
        {
            _remoteReason = [circuitString substringWithRange:[matches.firstObject rangeAtIndex:1]];
        }

        matches = [[TORCircuit regexForOption:@"SOCKS_USERNAME"]
                   matchesInString:circuitString options:0 range:range];

        if (matches.firstObject.numberOfRanges > 1)
        {
            _socksUsername = [circuitString substringWithRange:[matches.firstObject rangeAtIndex:1]];
        }

        matches = [[TORCircuit regexForOption:@"SOCKS_PASSWORD"]
                   matchesInString:circuitString options:0 range:range];

        if (matches.firstObject.numberOfRanges > 1)
        {
            _socksPassword = [circuitString substringWithRange:[matches.firstObject rangeAtIndex:1]];
        }
    }

    return self;
}


// MARK: NSObject

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p> status=%@, nodes=%@, buildFlags=%@, purpose=%@, hsState=%@, rendQuery=%@, timeCreated=%@, reason=%@, remoteReason=%@, socksUsername=%@, socksPassword=%@]",
            self.class, self, self.status, self.nodes, self.buildFlags,
            self.purpose, self.hsState, self.rendQuery, self.timeCreated,
            self.reason, self.remoteReason, self.socksUsername, self.socksPassword];
}

- (NSString *)debugDescription
{
    return [NSString stringWithFormat:@"<%@: %p> raw=%@", self.class, self, self.raw];
}


@end
