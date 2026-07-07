//
//  TORNode.m
//  Tor
//
//  Created by Benjamin Erhart on 09.12.19.
//

#import "TORNode.h"
#import "NSCharacterSet+PredefinedSets.h"

@implementation TORNode

// MARK: Class Properties

static NSRegularExpression *_ipv4Regex;
static NSRegularExpression *_ipv6Regex;

+ (NSRegularExpression *)ipv4Regex
{
    if (!_ipv4Regex)
    {
        _ipv4Regex =
        [NSRegularExpression
         regularExpressionWithPattern:@"(?:(?:25[0-5]|2[0-4]\\d|[01]?\\d\\d?)\\.){3}(?:25[0-5]|2[0-4]\\d|[01]?\\d\\d?)"
         options:0 error:nil];
    }

    return _ipv4Regex;
}

+ (NSRegularExpression *)ipv6Regex
{
    if (!_ipv6Regex)
    {
        _ipv6Regex =
        [NSRegularExpression
         regularExpressionWithPattern:
         @"((([\\da-f]{1,4}:){7}([\\da-f]{1,4}|:))|(([\\da-f]{1,4}:){6}(:[\\da-f]{1,4}|((25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]?\\d)(\\.(25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]?\\d)){3})|:))|(([\\da-f]{1,4}:){5}(((:[\\da-f]{1,4}){1,2})|:((25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]?\\d)(\\.(25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]?\\d)){3})|:))|(([\\da-f]{1,4}:){4}(((:[\\da-f]{1,4}){1,3})|((:[\\da-f]{1,4})?:((25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]?\\d)(\\.(25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]?\\d)){3}))|:))|(([\\da-f]{1,4}:){3}(((:[\\da-f]{1,4}){1,4})|((:[\\da-f]{1,4}){0,2}:((25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]?\\d)(\\.(25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]?\\d)){3}))|:))|(([\\da-f]{1,4}:){2}(((:[\\da-f]{1,4}){1,5})|((:[\\da-f]{1,4}){0,3}:((25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]?\\d)(\\.(25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]?\\d)){3}))|:))|(([\\da-f]{1,4}:){1}(((:[\\da-f]{1,4}){1,6})|((:[\\da-f]{1,4}){0,4}:((25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]?\\d)(\\.(25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]?\\d)){3}))|:))|(:(((:[\\da-f]{1,4}){1,7})|((:[\\da-f]{1,4}){0,5}:((25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]?\\d)(\\.(25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]?\\d)){3}))|:)))(%.+)?"
         options:NSRegularExpressionCaseInsensitive error:nil];
    }

    return _ipv6Regex;
}

// MARK: Class Methods:

+ (NSArray<TORNode *>  * _Nonnull)parseFromNsString:(NSString * _Nullable)nsString exitOnly:(BOOL)exitOnly
{
    NSMutableArray<TORNode *> *nodes = [NSMutableArray new];
    NSMutableArray<NSString *> *raw = [NSMutableArray new];

    // A typical NS string for a Tor node might look like this:
    //  (Line breaks are not for readability but contained in original!)
    //
    // r ForPrivacyNET ADb6NqtDX9XQ9kBiZjaGfr+3LGg epP7Gxm+NYhwC3V7SPORQCPoVgc 2022-11-18 00:01:48 185.220.101.33 10133 0
    // a [2a0b:f4c2:2::33]:10133
    // s Exit Fast Running V2Dir Valid
    // w Bandwidth=37000
    //
    // So, we watch out for a "r" line and add all lines which start with a valid prefix until the
    // next "r" line to get the full description.
    // But since we currently don't use the "w" line information, we ignore that as an optimization.

    for (NSString *line in [nsString componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet]) {
        if ([line hasPrefix:@"r"])
        {
            if (raw.count > 0)
            {
                if (!exitOnly || [raw.lastObject rangeOfString:@"Exit"].location != NSNotFound)
                {
                    [nodes addObject:[[TORNode alloc] initFromNsString:[raw componentsJoinedByString:@"\n"]]];
                }

                raw = [[NSMutableArray alloc] initWithObjects:line, nil];
            }
        }
        else if ([line hasPrefix:@"a"] || [line hasPrefix:@"s"])
        {
            [raw addObject:line];
        }
    }

    if (raw.count > 0 && (!exitOnly || [raw.lastObject rangeOfString:@"Exit"].location != NSNotFound))
    {
        [nodes addObject:[[TORNode alloc] initFromNsString:[raw componentsJoinedByString:@"\n"]]];
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
                                           NSCharacterSet.longNameDivider];

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

- (instancetype)initFromNsString:(NSString *)nsString
{
    self = [super init];

    if (self)
    {
        NSRange r1 = [nsString rangeOfCharacterFromSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];

        if (r1.location != NSNotFound)
        {
            NSUInteger p1 = r1.location + r1.length;

            NSRange r2 = [nsString rangeOfCharacterFromSet:NSCharacterSet.whitespaceAndNewlineCharacterSet
                                                   options:0 range:NSMakeRange(p1, nsString.length - p1)];

            if (r2.location != NSNotFound)
            {
                self.nickName = [nsString substringWithRange:NSMakeRange(p1, r2.location - p1)];
            }
        }

        [self acquireIpAddressesFromNsResponse:nsString];
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

    if ([response rangeOfString:@"Exit"].location != NSNotFound)
    {
        self.isExit = YES;
    }
}

- (NSString *)localizedCountryName
{
    if (!self.countryCode)
    {
        return nil;
    }

    NSString *countryCode = (NSString * _Nonnull)self.countryCode;
    if (@available(iOS 10.0, macOS 10.12, *)) {
        return [NSLocale.currentLocale localizedStringForCountryCode:countryCode];
    } else {
        return [NSLocale.currentLocale displayNameForKey:NSLocaleCountryCode value:countryCode];
    }
}


// MARK: NSSecureCoding

+ (BOOL)supportsSecureCoding
{
  return YES;
}

- (id)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init]))
    {
        _fingerprint = [coder decodeObjectOfClass:NSString.class forKey:@"fingerprint"];
        _nickName = [coder decodeObjectOfClass:NSString.class forKey:@"nickName"];
        _ipv4Address = [coder decodeObjectOfClass:NSString.class forKey:@"ipv4Address"];
        _ipv6Address = [coder decodeObjectOfClass:NSString.class forKey:@"ipv6Address"];
        _countryCode = [coder decodeObjectOfClass:NSString.class forKey:@"countryCode"];
    }

    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:self.fingerprint forKey:@"fingerprint"];
    [coder encodeObject:self.nickName forKey:@"nickName"];
    [coder encodeObject:self.ipv4Address forKey:@"ipv4Address"];
    [coder encodeObject:self.ipv6Address forKey:@"ipv6Address"];
    [coder encodeObject:self.countryCode forKey:@"countryCode"];
}


// MARK: NSObject

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p> fingerprint=%@, nickName=%@, ipv4Address=%@, ipv6Address=%@, countryCode=%@, localizedCountryName=%@",
            self.class, self, self.fingerprint, self.nickName, self.ipv4Address,
            self.ipv6Address, self.countryCode, self.localizedCountryName];
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

    return [self.fingerprint isEqualToString:(NSString * _Nonnull)((TORNode *)other).fingerprint];
}

- (NSUInteger)hash
{
    return self.fingerprint.hash;
}

@end
