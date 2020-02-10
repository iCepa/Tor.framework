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

    if (@available(iOS 10.0, macOS 10.12, *)) {
        return [NSLocale.currentLocale localizedStringForCountryCode:self.countryCode];
    } else {
        return [NSLocale.currentLocale displayNameForKey:NSLocaleCountryCode value:self.countryCode];
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

    return [self.fingerprint isEqualToString:((TORNode *)other).fingerprint];
}

- (NSUInteger)hash
{
    return self.fingerprint.hash;
}

@end
