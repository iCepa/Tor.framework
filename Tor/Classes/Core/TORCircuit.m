//
//  TORCircuit.m
//  Tor
//
//  Created by Benjamin Erhart on 11.12.19.
//

#import "TORCircuit.h"
#import "NSCharacterSet+PredefinedSets.h"

@implementation TORCircuit


// MARK: Class Properties

static NSRegularExpression *_mainInfoRegex;
static NSMutableDictionary<NSString *, NSRegularExpression *> *_optionsRegexes;
static NSDateFormatter *_timestampFormatter;

+ (NSRegularExpression *)mainInfoRegex
{
    if (!_mainInfoRegex)
    {
        _mainInfoRegex =
        [NSRegularExpression
         regularExpressionWithPattern:
         @"(\\w+)\\s+(LAUNCHED|BUILT|GUARD_WAIT|EXTENDED|FAILED|CLOSED)\\s+((?:\\$[\\da-f]+[=~]\\w+(?:,|\\s|\\Z))+)?"
         options:NSRegularExpressionCaseInsensitive error:nil];
    }

    return _mainInfoRegex;
}

+ (NSString *)statusLaunched
{
    return @"LAUNCHED";
}

+ (NSString *)statusBuilt
{
    return @"BUILT";
}

+ (NSString *)statusGuardWait
{
    return @"GUARD_WAIT";
}

+ (NSString *)statusExtended
{
    return @"EXTENDED";
}

+ (NSString *)statusFailed
{
    return @"FAILED";
}

+ (NSString *)statusClosed
{
    return @"CLOSED";
}

+ (NSString *)buildFlagOneHopTunnel
{
    return @"ONEHOP_TUNNEL";
}

+ (NSString *)buildFlagIsInternal
{
    return @"IS_INTERNAL";
}

+ (NSString *)buildFlagNeedCapacity
{
    return @"NEED_CAPACITY";
}

+ (NSString *)buildFlagNeedUptime
{
    return @"NEED_UPTIME";
}

+ (NSString *)purposeGeneral
{
    return @"GENERAL";
}

+ (NSString *)purposeHsClientIntro
{
    return @"HS_CLIENT_INTRO";
}

+ (NSString *)purposeHsClientRend
{
    return @"HS_CLIENT_REND";
}

+ (NSString *)purposeHsServiceIntro
{
    return @"HS_SERVICE_INTRO";
}

+ (NSString *)purposeHsServiceRend
{
    return @"HS_SERVICE_REND";
}

+ (NSString *)purposeHsVanguards
{
    return @"HS_VANGUARDS";
}

+ (NSString *)purposeTesting
{
    return @"TESTING";
}

+ (NSString *)purposeController
{
    return @"CONTROLLER";
}

+ (NSString *)purposeMeasureTimeout
{
    return @"MEASURE_TIMEOUT";
}

+ (NSString *)purposeConfluxLinked
{
    return @"CONFLUX_LINKED";
}

+ (NSString *)purposeConfluxUnlinked
{
    return @"CONFLUX_UNLINKED";
}

+ (NSString *)hsStateHsciConnecting
{
    return @"HSCI_CONNECTING";
}

+ (NSString *)hsStateHsciIntroSent
{
    return @"HSCI_INTRO_SENT";
}

+ (NSString *)hsStateHsciDone
{
    return @"HSCI_DONE";
}

+ (NSString *)hsStateHscrConnecting
{
    return @"HSCR_CONNECTING";
}

+ (NSString *)hsStateHscrEstablishedIdle
{
    return @"HSCR_ESTABLISHED_IDLE";
}

+ (NSString *)hsStateHscrEstablishedWaiting
{
    return @"HSCR_ESTABLISHED_WAITING";
}

+ (NSString *)hsStateHscrJoined
{
    return @"HSCR_JOINED";
}

+ (NSString *)hsStateHssiConnecting
{
    return @"HSSI_CONNECTING";
}

+ (NSString *)hsStateHssiEstablished
{
    return @"HSSI_ESTABLISHED";
}

+ (NSString *)hsStateHssrConnecting
{
    return @"HSSR_CONNECTING";
}

+ (NSString *)hsStateHssrJoined
{
    return @"HSSR_JOINED";
}

+ (NSString *)reasonNone
{
    return @"NONE";
}

+ (NSString *)reasonTorProtocol
{
    return @"TORPROTOCOL";
}

+ (NSString *)reasonInternal
{
    return @"INTERNAL";
}

+ (NSString *)reasonRequested
{
    return @"REQUESTED";
}

+ (NSString *)reasonHibernating
{
    return @"HIBERNATING";
}

+ (NSString *)reasonResourceLimit
{
    return @"RESOURCELIMIT";
}

+ (NSString *)reasonConnectFailed
{
    return @"CONNECTFAILED";
}

+ (NSString *)reasonOrIdentity
{
    return @"OR_IDENTITY";
}

+ (NSString *)reasonOrConnClosed
{
    return @"OR_CONN_CLOSED";
}

+ (NSString *)reasonTimeout
{
    return @"TIMEOUT";
}

+ (NSString *)reasonFinished
{
    return @"FINISHED";
}

+ (NSString *)reasonDestroyed
{
    return @"DESTROYED";
}

+ (NSString *)reasonNoPath
{
    return @"NOPATH";
}

+ (NSString *)reasonNoSuchService
{
    return @"NOSUCHSERVICE";
}

+ (NSString *)reasonMeasurementExpired
{
    return @"MEASUREMENT_EXPIRED";
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

+ (NSDateFormatter *)timestampFormatter
{
    if (!_timestampFormatter)
    {
        _timestampFormatter = [NSDateFormatter new];
        _timestampFormatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss.SSSSSS";
        _timestampFormatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        _timestampFormatter.timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
    }

    return _timestampFormatter;
}

+ (NSArray<TORCircuit *> *)circuitsFromString:(NSString *)circuitsString
{
    NSMutableArray<TORCircuit *> *circuits = [NSMutableArray new];

    for (NSString *circuitString in [circuitsString componentsSeparatedByString:@"\r\n"]) {
        if (circuitString.length > 0)
        {
            [circuits addObject:
             [[TORCircuit alloc] initFromString:circuitString]];
        }
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

        NSTextCheckingResult *match = [TORCircuit.mainInfoRegex
                                                    matchesInString:circuitString options:0
                                                    range:range].firstObject;
        
        if (match && [match rangeAtIndex:1].location != NSNotFound)
        {
            _circuitId = [circuitString substringWithRange:[match rangeAtIndex:1]];
        }
        
        if (match && [match rangeAtIndex:2].location != NSNotFound)
        {
            _status = [circuitString substringWithRange:[match rangeAtIndex:2]];
        }
        
        if (match && [match rangeAtIndex:3].location != NSNotFound)
        {
            NSMutableArray<TORNode *> *nodes = [NSMutableArray new];
            
            NSString *path = [circuitString substringWithRange:[match rangeAtIndex:3]];

            NSArray<NSString *> *nodesStrings = [path componentsSeparatedByString:@","];

            for (NSString *nodeString in nodesStrings)
            {
                [nodes addObject:
                [[TORNode alloc] initFromString:
                    [nodeString stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet]]];
            }

            _nodes = nodes;
        }
        
        match = [[TORCircuit regexForOption:@"BUILD_FLAGS"]
                   matchesInString:circuitString options:0 range:range].firstObject;

        if (match && [match rangeAtIndex:1].location != NSNotFound)
        {
            _buildFlags = [[circuitString substringWithRange:[match rangeAtIndex:1]]
                           componentsSeparatedByString:@","];
        }

        match = [[TORCircuit regexForOption:@"PURPOSE"]
                    matchesInString:circuitString options:0 range:range].firstObject;

        if (match && [match rangeAtIndex:1].location != NSNotFound)
        {
            _purpose = [circuitString substringWithRange:[match rangeAtIndex:1]];
        }

        match = [[TORCircuit regexForOption:@"HS_STATE"]
                    matchesInString:circuitString options:0 range:range].firstObject;

        if (match && [match rangeAtIndex:1].location != NSNotFound)
        {
            _hsState = [circuitString substringWithRange:[match rangeAtIndex:1]];
        }

        match = [[TORCircuit regexForOption:@"REND_QUERY"]
                    matchesInString:circuitString options:0 range:range].firstObject;

        if (match && [match rangeAtIndex:1].location != NSNotFound)
        {
            _rendQuery = [circuitString substringWithRange:[match rangeAtIndex:1]];
        }

        match = [[TORCircuit regexForOption:@"TIME_CREATED"]
                    matchesInString:circuitString options:0 range:range].firstObject;

        if (match && [match rangeAtIndex:1].location != NSNotFound)
        {
            _timeCreated = [TORCircuit.timestampFormatter dateFromString:
                            [circuitString substringWithRange:[match rangeAtIndex:1]]];
        }

        match = [[TORCircuit regexForOption:@"REASON"]
                    matchesInString:circuitString options:0 range:range].firstObject;

        if (match && [match rangeAtIndex:1].location != NSNotFound)
        {
            _reason = [circuitString substringWithRange:[match rangeAtIndex:1]];
        }

        match = [[TORCircuit regexForOption:@"REMOTE_REASON"]
                    matchesInString:circuitString options:0 range:range].firstObject;

        if (match && [match rangeAtIndex:1].location != NSNotFound)
        {
            _remoteReason = [circuitString substringWithRange:[match rangeAtIndex:1]];
        }

        match = [[TORCircuit regexForOption:@"SOCKS_USERNAME"]
                    matchesInString:circuitString options:0 range:range].firstObject;

        if (match && [match rangeAtIndex:1].location != NSNotFound)
        {
            _socksUsername = [[circuitString substringWithRange:[match rangeAtIndex:1]]
                              stringByTrimmingCharactersInSet:NSCharacterSet.doubleQuote];
        }

        match = [[TORCircuit regexForOption:@"SOCKS_PASSWORD"]
                    matchesInString:circuitString options:0 range:range].firstObject;

        if (match && [match rangeAtIndex:1].location != NSNotFound)
        {
            _socksPassword = [[circuitString substringWithRange:[match rangeAtIndex:1]]
                              stringByTrimmingCharactersInSet:NSCharacterSet.doubleQuote];
        }
    }

    return self;
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
        _raw = [coder decodeObjectOfClass:NSString.class forKey:@"raw"];
        _circuitId = [coder decodeObjectOfClass:NSString.class forKey:@"circuitId"];
        _status = [coder decodeObjectOfClass:NSString.class forKey:@"status"];
        _nodes = [coder decodeObjectOfClasses:[NSSet setWithArray:@[NSArray.class, TORNode.class]] forKey:@"nodes"];
        _buildFlags = [coder decodeObjectOfClasses:[NSSet setWithArray:@[NSArray.class, NSString.class]] forKey:@"buildFlags"];
        _purpose = [coder decodeObjectOfClass:NSString.class forKey:@"purpose"];
        _hsState = [coder decodeObjectOfClass:NSString.class forKey:@"hsState"];
        _rendQuery = [coder decodeObjectOfClass:NSString.class forKey:@"rendQuery"];
        _timeCreated = [coder decodeObjectOfClass:NSDate.class forKey:@"timeCreated"];
        _reason = [coder decodeObjectOfClass:NSString.class forKey:@"reason"];
        _remoteReason = [coder decodeObjectOfClass:NSString.class forKey:@"remoteReason"];
        _socksUsername = [coder decodeObjectOfClass:NSString.class forKey:@"socksUsername"];
        _socksPassword = [coder decodeObjectOfClass:NSString.class forKey:@"socksPassword"];
    }

    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:self.raw forKey:@"raw"];
    [coder encodeObject:self.circuitId forKey:@"circuitId"];
    [coder encodeObject:self.status forKey:@"status"];
    [coder encodeObject:self.nodes forKey:@"nodes"];
    [coder encodeObject:self.buildFlags forKey:@"buildFlags"];
    [coder encodeObject:self.purpose forKey:@"purpose"];
    [coder encodeObject:self.hsState forKey:@"hsState"];
    [coder encodeObject:self.rendQuery forKey:@"rendQuery"];
    [coder encodeObject:self.timeCreated forKey:@"timeCreated"];
    [coder encodeObject:self.reason forKey:@"reason"];
    [coder encodeObject:self.remoteReason forKey:@"remoteReason"];
    [coder encodeObject:self.socksUsername forKey:@"socksUsername"];
    [coder encodeObject:self.socksPassword forKey:@"socksPassword"];
}


// MARK: NSObject

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p> circuitId=%@, status=%@, nodes=%@, buildFlags=%@, purpose=%@, hsState=%@, rendQuery=%@, timeCreated=%@, reason=%@, remoteReason=%@, socksUsername=%@, socksPassword=%@, raw=%@]",
            self.class, self, self.circuitId, self.status, self.nodes, self.buildFlags,
            self.purpose, self.hsState, self.rendQuery, self.timeCreated,
            self.reason, self.remoteReason, self.socksUsername, self.socksPassword, self.raw];
}


@end
