//
//  TORController.m
//  Tor
//
//  Created by Conrad Kramer on 5/10/14.
//

#import "TORController.h"

#import <sys/socket.h>
#import <sys/un.h>
#import <netinet/in.h>
#import <arpa/inet.h>

#import "TORControlReplyCode.h"
#import "TORControlCommand.h"
#import "NSCharacterSet+PredefinedSets.h"

NS_ASSUME_NONNULL_BEGIN

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 100000
NSErrorDomain const TORControllerErrorDomain = @"TORControllerErrorDomain";
#else
NSString * const TORControllerErrorDomain = @"TORControllerErrorDomain";
#endif

static NSString * const TORControllerMidReplyLineSeparator = @"-";
static NSString * const TORControllerDataReplyLineSeparator = @"+";
static NSString * const TORControllerEndReplyLineSeparator = @" ";

@implementation TORController {
    NSURL *_url;
    NSString *_host;
    in_port_t _port;
    dispatch_io_t _channel;
    NSMutableArray<TORObserverBlock> *_blocks;
    int sock;
}

+ (dispatch_queue_t)controlQueue {
    static dispatch_queue_t controlQueue = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        controlQueue = dispatch_queue_create("org.torproject.ios.control", DISPATCH_QUEUE_SERIAL);
    });
    return controlQueue;
}

- (instancetype)initWithSocketURL:(NSURL *)url {
    NSParameterAssert(url.fileURL);
    self = [super init];
    if (!self)
        return nil;
    
    _url = [url copy];
    _blocks = [NSMutableArray new];

    [self connect:nil];
    
    return self;
}

- (instancetype)initWithSocketHost:(NSString *)host port:(in_port_t)port {
    NSParameterAssert(host && port);
    self = [super init];
    if (!self)
        return nil;
    
    _host = [host copy];
    _port = port;
    _blocks = [NSMutableArray new];

    [self connect:nil];
    
    return self;
}

- (instancetype)initWithControlPortFile:(NSURL *)file {
    NSParameterAssert(file.fileURL);

    // Expected example content:
    // PORT=127.0.0.1:49651

    NSError *error;
    NSString *content = [[NSString alloc]
                         initWithContentsOfURL:file
                         encoding:NSUTF8StringEncoding error:&error];

    NSAssert(!error, error.localizedDescription);

    NSArray<NSString *> *address = [[[content componentsSeparatedByString:@"="]
                                         .lastObject
                                     stringByTrimmingCharactersInSet:
                                         NSCharacterSet.whitespaceAndNewlineCharacterSet]
                                    componentsSeparatedByString:@":"];

    NSString *host = address.firstObject;
    NSAssert(host, @"Provided file doesn't seem to be a valid control port file as written by Tor!");

    NSInteger port = address.lastObject.integerValue;

    return [self initWithSocketHost:host port:(in_port_t) port];
}

- (void)dealloc {
    if (_channel)
        dispatch_io_close(_channel, DISPATCH_IO_STOP);
}

#pragma mark - Connecting

- (BOOL)isConnected {
    return (_channel != nil);
}

- (BOOL)connect:(out NSError **)error {
    if (_channel)
    {
        return NO;
    }
    
    self->sock = -1;
    
    _events = [NSOrderedSet new];
    
    if (_url)
    {
        struct sockaddr_un control_addr = {};
        control_addr.sun_family = AF_UNIX;
        strncpy(control_addr.sun_path, _url.fileSystemRepresentation, sizeof(control_addr.sun_path) - 1);
        control_addr.sun_len = (unsigned char)SUN_LEN(&control_addr);
        
        self->sock = socket(AF_UNIX, SOCK_STREAM, 0);

        if (connect(self->sock, (struct sockaddr *)&control_addr, control_addr.sun_len) == -1)
        {
            if (error)
            {
                *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
            }

            return NO;
        }
    }
    else if (_host && _port) {
        struct in_addr addr;

        if (inet_aton(_host.UTF8String, &addr) == 0)
        {
            if (error)
            {
                *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
            }

            return NO;
        }
        
        struct sockaddr_in control_addr = {};
        control_addr.sin_family = AF_INET;
        control_addr.sin_port = htons(_port);
        control_addr.sin_addr = addr;
        control_addr.sin_len = (__uint8_t)sizeof(control_addr);
        
        self->sock = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
        
        if (connect(self->sock, (struct sockaddr *)&control_addr, control_addr.sin_len) == -1)
        {
            if (error)
            {
                *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
            }

            return NO;
        }
    }
    else {
        return NO;
    }
    
    __weak TORController *weakSelf = self;

    _channel = dispatch_io_create(DISPATCH_IO_STREAM, self->sock, [self.class controlQueue], ^(int __unused error) {
        close(self->sock);
        
        TORController *strongSelf = weakSelf;
        if (strongSelf)
        {
            strongSelf->_channel = nil;
        }
    });

    if (!_channel)
    {
        return NO;
    }
    
    NSData *separator = [NSData dataWithBytes:"\x0d\x0a" length:2]; // also known as CR-LF or "\r\n"
    NSData *period = [NSData dataWithBytes:"." length:1];

    NSSet<NSString *> *lineSeparators = [NSSet setWithObjects:TORControllerMidReplyLineSeparator,
                                         TORControllerDataReplyLineSeparator,
                                         TORControllerEndReplyLineSeparator, nil];
    
    __block NSMutableData *buffer = [NSMutableData new];
    __block NSMutableArray<NSNumber *> *codes = [NSMutableArray new];
    __block NSMutableArray<NSData *> *lines = [NSMutableArray new];
    __block BOOL dataBlock = NO;
    
    dispatch_io_set_low_water(_channel, 1);
    dispatch_io_read(_channel, 0, SIZE_MAX, [self.class controlQueue], ^(bool __unused done, dispatch_data_t data, int __unused error) {
        [buffer appendData:(NSData *)data];
        
        NSRange separatorRange;
        NSRange remainingRange = NSMakeRange(0, buffer.length);

        while ((separatorRange = [buffer rangeOfData:separator options:0 range:remainingRange]).location != NSNotFound)
        {
            NSUInteger lineLength = separatorRange.location - remainingRange.location;
            NSRange lineRange = NSMakeRange(remainingRange.location, lineLength);
            remainingRange = NSMakeRange(remainingRange.location + lineLength + separator.length,
                                         remainingRange.length - lineLength - separator.length);
            
            if (dataBlock)
            {
                NSData *lineData = [buffer subdataWithRange:lineRange];

                if ([lineData isEqualToData:period])
                {
                    dataBlock = NO;
                }
                else {
                    if (lines.count > 0)
                    {
                        if (lines.lastObject.length > 0)
                        {
                            NSMutableData *lastData = lines.lastObject.mutableCopy;

                            // BUGFIX: Add in separator again. It is needed to pick apart multi-line results later!
                            [lastData appendData:separator];
                            [lastData appendData:lineData];

                            [lines replaceObjectAtIndex:(lines.count - 1) withObject:lastData];
                        }
                        else {
                            [lines replaceObjectAtIndex:(lines.count - 1) withObject:lineData];
                        }
                    }
                    else {
                        [lines addObject:lineData];
                    }
                }

                continue;
            }
            
            if (lineRange.length < 4)
            {
                continue;
            }

            NSString *statusCodeString = [[NSString alloc] initWithData:[buffer subdataWithRange:NSMakeRange(lineRange.location, 3)]
                                                               encoding:NSUTF8StringEncoding];

            if ([statusCodeString rangeOfCharacterFromSet:NSCharacterSet.decimalDigitCharacterSet.invertedSet].location != NSNotFound)
            {
                continue;
            }
            
            NSString *lineTypeString = [[NSString alloc] initWithData:[buffer subdataWithRange:NSMakeRange(lineRange.location + 3, 1)]
                                                             encoding:NSUTF8StringEncoding];

            if (![lineSeparators containsObject:lineTypeString])
            {
                continue;
            }

            [codes addObject:@(statusCodeString.integerValue)];
            [lines addObject:[buffer subdataWithRange:NSMakeRange(lineRange.location + 4, lineRange.length - 4)]];
            
            [buffer replaceBytesInRange:NSMakeRange(0, remainingRange.location) withBytes:NULL length:0];
            remainingRange.location = 0;

            if ([lineTypeString isEqualToString:TORControllerDataReplyLineSeparator])
            {
                dataBlock = YES;
            }
            
            if ([lineTypeString isEqualToString:TORControllerEndReplyLineSeparator])
            {
                NSArray<NSNumber *> *commandCodes = codes;
                NSArray<NSData *> *commandLines = lines;
                codes = [NSMutableArray new];
                lines = [NSMutableArray new];
                
                TORController *strongSelf = weakSelf;
                if (!strongSelf)
                {
                    continue;
                }
                
                for (TORObserverBlock observer in [strongSelf->_blocks copy]) {
                    BOOL stop = NO;
                    BOOL handled = observer(commandCodes, commandLines, &stop);

                    if (stop)
                    {
                        [strongSelf->_blocks removeObject:observer];
                    }

                    if (handled)
                    {
                        break;
                    }
                }
            }
        }
    });
    
    return YES;
}

- (void)disconnect {
    [self sendCommand:TORCommandSignalShutdown arguments:nil data:nil observer:^BOOL(NSArray<NSNumber *> * __unused codes, NSArray<NSData *> * __unused lines, BOOL * __unused stop) {
        shutdown(self->sock, SHUT_RDWR);
        self->_channel = nil;
     
        return YES;
     }];
}

#pragma mark - Receiving Responses

- (id)addObserverForCircuitEstablished:(void (^)(BOOL established))block {
    NSParameterAssert(block);
    
    NSString *event = @"STATUS_CLIENT";
    id observer = [self addObserverForStatusEvents:^(NSString *type, NSString * __unused severity, NSString *action, NSDictionary<NSString *, NSString *> * __unused arguments) {
        if ([type isEqualToString:event]) {
            if ([action isEqualToString:@"CIRCUIT_ESTABLISHED"]) {
                block(YES);
                return YES;
            } else if ([action isEqualToString:@"CIRCUIT_NOT_ESTABLISHED"]) {
                block(NO);
                return YES;
            }
        }
        
        return NO;
    }];
    
    void (^completion)(BOOL, NSError *) = ^(BOOL success, NSError * __unused error) {
        if (!success)
            [self removeObserver:observer];
        
        [self getInfoForKeys:@[@"status/circuit-established"] completion:^(NSArray<NSString *> *values) {
            if (values.count != 1)
                return [self removeObserver:observer];
            
            if (block)
                block([values[0] boolValue]);
        }];
    };
    
    dispatch_async([self.class controlQueue], ^{
        if ([self->_events containsObject:event]) {
            completion(YES, nil);
        } else {
            NSMutableOrderedSet *events = [self->_events mutableCopy];
            [events addObject:event];
            [self listenForEvents:events.array completion:completion];
        }
    });
    
    return observer;
}

- (id)addObserverForStatusEvents:(BOOL (^)(NSString *type, NSString *severity, NSString *action, NSDictionary<NSString *, NSString *> *arguments))block {
    NSParameterAssert(block);
    return [self addObserver:^(NSArray<NSNumber *> *codes, NSArray<NSData *> *lines, BOOL * __unused stop) {
        if (codes.firstObject.integerValue != 650)
            return NO;
        
        NSString *replyString = lines.firstObject ? [[NSString alloc] initWithData:(NSData * _Nonnull)lines.firstObject encoding:NSUTF8StringEncoding] : @"";
        if (![replyString hasPrefix:@"STATUS_"])
            return NO;
        
        NSArray<NSString *> *components = [replyString componentsSeparatedByString:@" "];
        if (components.count < 3)
            return NO;
        
        NSMutableDictionary<NSString *, NSString *> *arguments = nil;
        if (components.count > 3) {
            arguments = [NSMutableDictionary new];
            for (NSString *argument in [components subarrayWithRange:NSMakeRange(3, components.count - 3)]) {
                NSArray<NSString *> *keyValuePair = [argument componentsSeparatedByString:@"="];
                if (keyValuePair.count == 2) {
                    [arguments setObject:keyValuePair[1] forKey:keyValuePair[0]];
                }
            }
        }

        NSString *type = (NSString * _Nonnull)components.firstObject;
        return block(type, components[1], components[2], arguments);
    }];
}

- (id)addObserver:(TORObserverBlock)observer {
    NSParameterAssert(observer);
    dispatch_async([self.class controlQueue], ^{
        [self->_blocks addObject:observer];
    });
    return observer;
}

- (void)removeObserver:(nullable id)observer {
    if (!observer)
        return;
    
    dispatch_async([self.class controlQueue], ^{
        [self->_blocks removeObject:(id _Nonnull)observer];
    });
}

#pragma mark - Sending Commands

- (void)authenticateWithData:(NSData *)data completion:(void (^__nullable)(BOOL success, NSError * __nullable error))completion {
    NSMutableString *hexString = [NSMutableString new];
    for (NSUInteger idx = 0; idx < data.length; idx++)
        [hexString appendFormat:@"%02x", ((const unsigned char *)data.bytes)[idx]];
    
    [self sendCommand:TORCommandAuthenticate arguments:(hexString.length ? @[hexString] : nil) data:nil observer:^BOOL(NSArray<NSNumber *> *codes, NSArray<NSData *> *lines, BOOL *stop) {
        NSUInteger code = codes.firstObject.unsignedIntegerValue;
        if (code != TORControlReplyCodeOK && code != TORControlReplyCodeBadAuthentication)
            return NO;
        
        NSString *message = lines.firstObject ? [[NSString alloc] initWithData:(NSData * _Nonnull)lines.firstObject encoding:NSUTF8StringEncoding] : @"";
        NSDictionary<NSString *, NSString *> *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:message, NSLocalizedDescriptionKey, nil];
        BOOL success = (code == TORControlReplyCodeOK && [message isEqualToString:@"OK"]);
        if (completion)
            completion(success, success ? nil : [NSError errorWithDomain:TORControllerErrorDomain code:code userInfo:userInfo]);
        
        *stop = YES;
        return YES;
    }];
}

- (void)resetConfForKey:(NSString *)key completion:(void (^__nullable)(BOOL success, NSError * __nullable error))completion {
	[self sendCommand:TORCommandResetConf arguments:@[key] data:nil observer:^BOOL(NSArray<NSNumber *> *codes, NSArray<NSData *> *lines, BOOL *stop) {
		NSUInteger code = codes.firstObject.unsignedIntegerValue;
		if (code != TORControlReplyCodeOK && code != TORControlReplyCodeBadAuthentication)
			return NO;

		NSString *message = lines.firstObject ? [[NSString alloc] initWithData:(NSData * _Nonnull)lines.firstObject encoding:NSUTF8StringEncoding] : @"";
		NSDictionary<NSString *, NSString *> *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:message, NSLocalizedDescriptionKey, nil];
		BOOL success = (code == TORControlReplyCodeOK && [message isEqualToString:@"OK"]);
		if (completion)
			completion(success, success ? nil : [NSError errorWithDomain:TORControllerErrorDomain code:code userInfo:userInfo]);

		*stop = YES;
		return YES;
	}];
}

- (void)setConfForKey:(NSString *)key withValue:(NSString *)value completion:(void (^__nullable)(BOOL success, NSError * __nullable error))completion {
	NSString *arg = [NSString stringWithFormat:@"%@=%@", key, value];

	[self sendCommand:TORCommandSetConf arguments:@[arg] data:nil observer:^BOOL(NSArray<NSNumber *> *codes, NSArray<NSData *> *lines, BOOL *stop) {
		NSUInteger code = codes.firstObject.unsignedIntegerValue;
		if (code != TORControlReplyCodeOK && code != TORControlReplyCodeBadAuthentication)
			return NO;

		NSString *message = lines.firstObject ? [[NSString alloc] initWithData:(NSData * _Nonnull)lines.firstObject encoding:NSUTF8StringEncoding] : @"";
		NSDictionary<NSString *, NSString *> *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:message, NSLocalizedDescriptionKey, nil];
		BOOL success = (code == TORControlReplyCodeOK && [message isEqualToString:@"OK"]);
		if (completion)
			completion(success, success ? nil : [NSError errorWithDomain:TORControllerErrorDomain code:code userInfo:userInfo]);

		*stop = YES;
		return YES;
	}];
}
- (void)setConfs:(NSArray<NSDictionary *> *)configs completion:(void (^__nullable)(BOOL success, NSError * __nullable error))completion {
    NSMutableArray *conf_arg = [[NSMutableArray alloc] init];
    for (NSDictionary *config in configs) {
        NSString *key = [config objectForKey:@"key"];
        NSString *value = [config objectForKey:@"value"];
        NSString *arg = [NSString stringWithFormat:@"%@=%@", key, value];
        [conf_arg addObject:arg];
    }

    [self sendCommand:TORCommandSetConf arguments:conf_arg data:nil observer:^BOOL(NSArray<NSNumber *> *codes, NSArray<NSData *> *lines, BOOL *stop) {
        NSUInteger code = codes.firstObject.unsignedIntegerValue;
        if (code != TORControlReplyCodeOK && code != TORControlReplyCodeBadAuthentication)
            return NO;
        
        NSString *message = lines.firstObject ? [[NSString alloc] initWithData:(NSData * _Nonnull)lines.firstObject encoding:NSUTF8StringEncoding] : @"";
        NSDictionary<NSString *, NSString *> *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:message, NSLocalizedDescriptionKey, nil];
        BOOL success = (code == TORControlReplyCodeOK && [message isEqualToString:@"OK"]);
        if (completion)
            completion(success, success ? nil : [NSError errorWithDomain:TORControllerErrorDomain code:code userInfo:userInfo]);
        
        *stop = YES;
        return YES;
    }];

}

- (void)listenForEvents:(NSArray<NSString *> *)events completion:(void (^__nullable)(BOOL success, NSError * __nullable error))completion {
    [self sendCommand:TORCommandSetEvents arguments:events data:nil observer:^BOOL(NSArray<NSNumber *> *codes, NSArray<NSData *> *lines, BOOL *stop) {
        NSUInteger code = codes.firstObject.unsignedIntegerValue;
        if (code != TORControlReplyCodeOK && code != TORControlReplyCodeUnrecognizedEntity)
            return NO;

        NSString *message = lines.firstObject ? [[NSString alloc] initWithData:(NSData * _Nonnull)lines.firstObject encoding:NSUTF8StringEncoding] : @"";
        NSDictionary<NSString *, NSString *> *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:message, NSLocalizedDescriptionKey, nil];
        BOOL success = (code == TORControlReplyCodeOK && [message isEqualToString:@"OK"]);
        if (success)
            self->_events = [NSOrderedSet orderedSetWithArray:events];
        if (completion)
            completion(success, success ? nil : [NSError errorWithDomain:TORControllerErrorDomain code:code userInfo:userInfo]);
        
        *stop = YES;
        return YES;
    }];
}

- (void)getInfoForKeys:(NSArray<NSString *> *)keys completion:(void (^)(NSArray<NSString *> *values))completion
{
    NSData *ok = [NSData dataWithBytes:"OK" length:2];

    [self sendCommand:TORCommandGetInfo arguments:keys data:nil observer:^BOOL(NSArray<NSNumber *> *codes, NSArray<NSData *> *lines, BOOL *stop) {
        *stop = YES;

        if (lines.count - 1 != keys.count || codes.count != lines.count)
        {
            if (completion)
            {
                completion(@[]);
            }

            return NO;
        }

        if (codes.lastObject.integerValue != TORControlReplyCodeOK || ![lines.lastObject isEqual:ok])
        {
            if (completion)
            {
                completion(@[]);
            }

            return NO;
        }

        NSMutableDictionary<NSString *, NSString *> *info = [NSMutableDictionary new];

        for (NSUInteger i = 0; i < codes.count - 1; i++)
        {
            if (codes[i].integerValue == TORControlReplyCodeOK)
            {
                NSString *string = [[NSString alloc] initWithData:lines[i] encoding:NSUTF8StringEncoding];

                if (!string)
                {
                    completion(@[]);

                    return NO;
                }

                NSRange pos = [string rangeOfString:@"="];

                if (pos.location != NSNotFound)
                {
                    NSString *key = [[string substringToIndex:pos.location] stringByTrimmingCharactersInSet:
                                     NSCharacterSet.doubleQuote];

                    if ([keys containsObject:key])
                    {
                        info[key] = [[string substringFromIndex:pos.location + pos.length]
                                     stringByTrimmingCharactersInSet:NSCharacterSet.doubleQuote];
                    }
                    else {
                        if (completion)
                        {
                            completion(@[]);

                            return NO;
                        }
                    }
                }
            }
        }

        NSMutableArray *values = [NSMutableArray new];

        for (NSString *key in keys)
        {
            [values addObject:(info[key] ?: [NSNull null])];
        }

        if (completion)
        {
            completion(values);
        }

        return YES;
    }];
}

- (void)getSessionConfiguration:(void (^)(NSURLSessionConfiguration * __nullable configuration))completion
{
    [self getInfoForKeys:@[@"net/listeners/socks"] completion:^(NSArray<NSString *> *values) {
        if (values.count != 1)
            return completion(nil);
        
        NSArray<NSString *> *components = [values.firstObject componentsSeparatedByString:@":"];
        if (components.count != 2)
            return completion(nil);
        
        if ([components[0] isEqualToString:@"unix"])
            return completion(nil); // TODO: Provide error
        
        if ([components[1] rangeOfCharacterFromSet:[[NSCharacterSet decimalDigitCharacterSet] invertedSet]].location != NSNotFound)
            return completion(nil); // TODO: Provide error

        NSString *host = components[0];

        // Replace 127.0.0.1 with localhost, as without this, there's a strange bug
        // triggered: It won't resolve .onion addresses, but *only on real devices*.
        // So, on a real device, there's probably the wrong DNS resolver used, which
        // would mean, DNS queries were leaking, too.
        if ([host isEqualToString:@"127.0.0.1"])
        {
            host = @"localhost";
        }

        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
        configuration.connectionProxyDictionary = @{(id)kCFProxyTypeKey: (id)kCFProxyTypeSOCKS,
                                                    (id)kCFStreamPropertySOCKSProxyHost: host,
                                                    (id)kCFStreamPropertySOCKSProxyPort: @([components[1] integerValue])};
        completion(configuration);
    }];
}

- (void)sendCommand:(NSString *)command
          arguments:(nullable NSArray<NSString *> *)arguments
               data:(nullable NSData *)data observer:(TORObserverBlock)observer
{
    NSParameterAssert(command.length);
    if (!_channel)
    {
        return;
    }

    if (arguments == nil)
    {
        arguments = @[];
    }

    NSString *argumentsString = [[@[command] arrayByAddingObjectsFromArray:(NSArray * _Nonnull)arguments]
                                 componentsJoinedByString:@" "];
    
    NSMutableData *commandData = [NSMutableData new];
    if (data.length)
    {
        [commandData appendBytes:"+" length:1];
    }
    [commandData appendData:(NSData * _Nonnull)[argumentsString dataUsingEncoding:NSUTF8StringEncoding]];
    [commandData appendBytes:"\r\n" length:2];

    if (data.length)
    {
        [commandData appendData:(NSData * _Nonnull)data];
        [commandData appendBytes:"\r\n.\r\n" length:5];
    }
    
    dispatch_data_t dispatchData = dispatch_data_create(commandData.bytes,
                                                        commandData.length,
                                                        [self.class controlQueue],
                                                        DISPATCH_DATA_DESTRUCTOR_DEFAULT);

    dispatch_io_write(_channel, 0, dispatchData, [self.class controlQueue], ^(bool done, dispatch_data_t __unused data, int error) {
        if (done && !error && observer) {
            [self->_blocks insertObject:observer atIndex:0];
        }
    });
}


- (void)getCircuits:(void (^)(NSArray<TORCircuit *> * _Nonnull circuits))completion
{
    [self getInfoForKeys:@[@"circuit-status"] completion:^(NSArray<NSString *> * _Nonnull values) {
        if (values.count < 1)
        {
            if (completion)
            {
                completion(@[]);
            }

            return;
        }

        NSArray<TORCircuit *> *circuits = [TORCircuit circuitsFromString:(NSString * _Nonnull)values.firstObject];

        NSMutableArray<NSString *> *ipResolveCalls = [NSMutableArray new];
        NSMutableArray<TORNode *> *map = [NSMutableArray new];

        for (TORCircuit *circuit in circuits)
        {
            for (TORNode *node in circuit.nodes)
            {
                [ipResolveCalls addObject:[NSString stringWithFormat:@"ns/id/%@", node.fingerprint]];
                [map addObject:node];
            }
        }

        [self getInfoForKeys:ipResolveCalls completion:^(NSArray<NSString *> * _Nonnull values) {
            for (NSUInteger i = 0; i < values.count; i++) {
                [map[i] acquireIpAddressesFromNsResponse:values[i]];
            }

            NSMutableArray<TORNode *> *nodes = [NSMutableArray new];

            for (TORCircuit *circuit in circuits)
            {
                [nodes addObjectsFromArray:circuit.nodes];
            }

            [self resolveCountriesOfNodes:nodes testCapabilities:YES completion:^{
                if (completion)
                {
                    completion(circuits);
                }
            }];
        }];
    }];
}

- (void)resetConnection:(void (^__nullable)(BOOL success))completion
{
    [self sendCommand:TORCommandSignalReload arguments:nil data:nil observer:
     ^BOOL(NSArray<NSNumber *> * _Nonnull codes, NSArray<NSData *> * _Nonnull __unused lines, BOOL * _Nonnull stop) {

        if (codes.firstObject.integerValue == TORControlReplyCodeOK)
        {
            [self sendCommand:TORCommandSignalNewnym arguments:nil data:nil observer:
             ^BOOL(NSArray<NSNumber *> * _Nonnull codes, NSArray<NSData *> * _Nonnull __unused lines, BOOL * _Nonnull stop) {

                if (completion)
                {
                    completion(codes.firstObject.integerValue == TORControlReplyCodeOK);
                }

                *stop = YES;
                return YES;
            }];
        }
        else {
            if (completion)
            {
                completion(NO);
            }
        }

        *stop = YES;
        return YES;
    }];
}

- (void)closeCircuitsByIds:(NSArray<NSString *> *)circuitIds completion:(void (^__nullable)(BOOL success))completion
{
    long queueId;

    if (@available(macOS 10.10, *)) {
        queueId = QOS_CLASS_USER_INITIATED;
    }
    else {
        queueId = DISPATCH_QUEUE_PRIORITY_HIGH;
    }

    dispatch_async(dispatch_get_global_queue(queueId, 0), ^{
        __block BOOL success = YES;

        dispatch_group_t group = dispatch_group_create();

        for (NSString *circuitId in circuitIds)
        {
            dispatch_group_enter(group);

            [self sendCommand:TORCommandCloseCircuit arguments:@[circuitId] data:nil observer:
             ^BOOL(NSArray<NSNumber *> * _Nonnull codes, NSArray<NSData *> * _Nonnull __unused lines, BOOL * _Nonnull stop) {

                success = success && codes.firstObject.integerValue == TORControlReplyCodeOK;

                // Need to deparallelize to not mix up responses.
                dispatch_group_leave(group);

                *stop = YES;
                return YES;
            }];
        }

        dispatch_group_wait(group, dispatch_time(DISPATCH_TIME_NOW, 10000000000)); // Wait 10 seconds.

        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion)
            {
                completion(success);
            }
        });
    });
}

- (void)closeCircuits:(NSArray<TORCircuit *> *)circuits completion:(void (^__nullable)(BOOL success))completion
{
    NSMutableArray<NSString *> *circuitIds = [NSMutableArray new];

    for (TORCircuit *circuit in circuits)
    {
        if (circuit.circuitId.length > 0)
        {
            [circuitIds addObject:(NSString * _Nonnull)circuit.circuitId];
        }
    }

    [self closeCircuitsByIds:circuitIds completion:completion];
}

- (void)resolveCountriesOfNodes:(NSArray<TORNode *> * _Nullable)nodes testCapabilities:(BOOL)testCapabilities completion:(void (^__nullable)(void))completion
{
    BOOL __block ipv4Available = YES;
    BOOL __block ipv6Available = YES;

    if (testCapabilities)
    {
        dispatch_group_t group = dispatch_group_create();
        dispatch_group_enter(group);

        [self getInfoForKeys:@[@"ip-to-country/ipv4-available", @"ip-to-country/ipv6-available"] completion:^(NSArray<NSString *> * _Nonnull values) {

            ipv4Available = [values.firstObject isEqualToString:@"1"];
            ipv6Available = [values.lastObject isEqualToString:@"1"];

            dispatch_group_leave(group);
        }];

        dispatch_group_wait(group, dispatch_time(DISPATCH_TIME_NOW, 1000000000)); // Wait 1 second.
    }

    if (!ipv4Available && !ipv6Available)
    {
        if (completion)
        {
            completion();
        }

        return;
    }

    NSMutableArray<NSString *> *geoipResolveCalls = [NSMutableArray new];
    NSMutableArray<TORNode *> *map = [NSMutableArray new];

    for (TORNode *node in nodes)
    {
        if (node.countryCode.length)
        {
            continue;
        }

        if (ipv4Available && node.ipv4Address.length)
        {
            [geoipResolveCalls addObject:[NSString stringWithFormat:@"ip-to-country/%@", node.ipv4Address]];
            [map addObject:node];
        }
        else if (ipv6Available && node.ipv6Address.length)
        {
            [geoipResolveCalls addObject:[NSString stringWithFormat:@"ip-to-country/%@", node.ipv6Address]];
            [map addObject:node];
        }
    }

    if (geoipResolveCalls.count < 1)
    {
        if (completion)
        {
            completion();
        }

        return;
    }

    [self getInfoForKeys:geoipResolveCalls completion:^(NSArray<NSString *> * _Nonnull values) {
        for (NSUInteger i = 0; i < values.count; i++)
        {
            map[i].countryCode = values[i];
        }

        if (completion)
        {
            completion();
        }
    }];
}

@end

NS_ASSUME_NONNULL_END
