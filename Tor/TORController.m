//
//  TORController.m
//  Tor
//
//  Created by Conrad Kramer on 5/10/14.
//

#import "TORController.h"

#import <or/or.h>
#import "TORThread.h"

const char tor_git_revision[] =
#ifndef _MSC_VER
#import "micro-revision.i"
#endif
"";

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
        return NO;
    
    int sock = -1;
    
    _events = [NSOrderedSet new];
    
    if (_url) {
        struct sockaddr_un control_addr = {};
        control_addr.sun_family = AF_UNIX;
        strncpy(control_addr.sun_path, _url.fileSystemRepresentation, sizeof(control_addr.sun_path) - 1);
        control_addr.sun_len = (unsigned char)SUN_LEN(&control_addr);
        
        sock = socket(AF_UNIX, SOCK_STREAM, 0);
        
        if (connect(sock, (struct sockaddr *)&control_addr, control_addr.sun_len) == -1) {
            if (error)
                *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
            return NO;
        }
    } else if (_host && _port) {
        struct in_addr addr;
        if (inet_aton(_host.UTF8String, &addr) == 0) {
            if (error)
                *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
            return NO;
        }
        
        struct sockaddr_in control_addr = {};
        control_addr.sin_family = AF_INET;
        control_addr.sin_port = htons(_port);
        control_addr.sin_addr = addr;
        control_addr.sin_len = (__uint8_t)sizeof(control_addr);
        
        sock = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
        
        if (connect(sock, (struct sockaddr *)&control_addr, control_addr.sin_len) == -1) {
            if (error)
                *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
            return NO;
        }
    } else {
        return NO;
    }
    
    __weak TORController *weakSelf = self;
    _channel = dispatch_io_create(DISPATCH_IO_STREAM, sock, [[self class] controlQueue], ^(int __unused error) {
        close(sock);
        
        TORController *strongSelf = weakSelf;
        if (strongSelf) {
            strongSelf->_channel = nil;
        }
    });
    if (!_channel)
        return NO;
    
    NSData *separator = [NSData dataWithBytes:"\x0d\x0a" length:2];
    NSSet<NSString *> *lineSeparators = [NSSet setWithObjects:TORControllerMidReplyLineSeparator,
                                         TORControllerDataReplyLineSeparator,
                                         TORControllerEndReplyLineSeparator, nil];
    
    __block NSMutableData *buffer = [NSMutableData new];
    __block NSMutableArray<NSNumber *> *codes = [NSMutableArray new];
    __block NSMutableArray<NSData *> *lines = [NSMutableArray new];
    __block BOOL dataBlock = NO;
    
    dispatch_io_set_low_water(_channel, 1);
    dispatch_io_read(_channel, 0, SIZE_MAX, [[self class] controlQueue], ^(bool __unused done, dispatch_data_t data, int __unused error) {
        [buffer appendData:(NSData *)data];
        
        NSRange separatorRange;
        NSRange remainingRange = NSMakeRange(0, buffer.length);
        while ((separatorRange = [buffer rangeOfData:separator options:0 range:remainingRange]).location != NSNotFound) {
            NSUInteger lineLength = separatorRange.location - remainingRange.location;
            NSRange lineRange = NSMakeRange(remainingRange.location, lineLength);
            remainingRange = NSMakeRange(remainingRange.location + lineLength + separator.length, remainingRange.length - lineLength - separator.length);
            
            NSData *lineData = [buffer subdataWithRange:lineRange];
            
            if (dataBlock) {
                if ([lineData isEqualToData:[NSData dataWithBytes:"." length:1]]) {
                    dataBlock = NO;
                } else {
                    NSMutableData *lastData = lines.lastObject.mutableCopy;
                    if (lastData) {
                        [lastData appendData:lineData];
                        [lines replaceObjectAtIndex:(lines.count - 1) withObject:lastData];
                    } else {
                        [lines addObject:lineData];
                    }
                }
                continue;
            }
            
            if (lineData.length < 4)
                continue;
            
            NSString *statusCodeString = [[NSString alloc] initWithData:[lineData subdataWithRange:NSMakeRange(0, 3)] encoding:NSUTF8StringEncoding];
            if ([statusCodeString rangeOfCharacterFromSet:[[NSCharacterSet decimalDigitCharacterSet] invertedSet]].location != NSNotFound)
                continue;
            
            NSString *lineTypeString = [[NSString alloc] initWithData:[lineData subdataWithRange:NSMakeRange(3, 1)] encoding:NSUTF8StringEncoding];
            if (![lineSeparators containsObject:lineTypeString])
                continue;
            
            buffer = [[buffer subdataWithRange:remainingRange] mutableCopy];
            remainingRange.location = 0;

            [codes addObject:@(statusCodeString.integerValue)];
            [lines addObject:[lineData subdataWithRange:NSMakeRange(4, lineData.length - 4)]];
            
            if ([lineTypeString isEqualToString:TORControllerDataReplyLineSeparator]) {
                dataBlock = YES;
            }
            
            if ([lineTypeString isEqualToString:TORControllerEndReplyLineSeparator]) {
                NSArray<NSNumber *> *commandCodes = [codes copy];
                NSArray<NSData *> *commandLines = [lines copy];
                codes = [NSMutableArray new];
                lines = [NSMutableArray new];
                
                TORController *strongSelf = weakSelf;
                if (!strongSelf)
                    continue;
                
                for (TORObserverBlock observer in [strongSelf->_blocks copy]) {
                    BOOL stop = NO;
                    BOOL handled = observer(commandCodes, commandLines, &stop);
                    if (stop)
                        [strongSelf->_blocks removeObject:observer];
                    if (handled)
                        break;
                }
            }
        }
    });
    
    return YES;
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
    
    dispatch_async([[self class] controlQueue], ^{
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
        
        NSString *replyString = [[NSString alloc] initWithData:lines.firstObject encoding:NSUTF8StringEncoding];
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
        
        return block(components.firstObject, components[1], components[2], arguments);
    }];
}

- (id)addObserver:(TORObserverBlock)observer {
    NSParameterAssert(observer);
    dispatch_async([[self class] controlQueue], ^{
        [self->_blocks addObject:observer];
    });
    return observer;
}

- (void)removeObserver:(nullable id)observer {
    if (!observer)
        return;
    
    dispatch_async([[self class] controlQueue], ^{
        [self->_blocks removeObject:observer];
    });
}

#pragma mark - Sending Commands

- (void)authenticateWithData:(NSData *)data completion:(void (^__nullable)(BOOL success, NSError * __nullable error))completion {
    NSMutableString *hexString = [NSMutableString new];
    for (NSUInteger idx = 0; idx < data.length; idx++)
        [hexString appendFormat:@"%02x", ((const unsigned char *)data.bytes)[idx]];
    
    [self sendCommand:@"AUTHENTICATE" arguments:(hexString.length ? @[hexString] : nil) data:nil observer:^BOOL(NSArray<NSNumber *> *codes, NSArray<NSData *> *lines, BOOL *stop) {
        NSUInteger code = codes.firstObject.unsignedIntegerValue;
        if (code != 250 && code != 515)
            return NO;
        
        NSString *message = [[NSString alloc] initWithData:lines.firstObject encoding:NSUTF8StringEncoding];
        NSDictionary<NSString *, NSString *> *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:message, NSLocalizedDescriptionKey, nil];
        BOOL success = (code == 250 && [message isEqualToString:@"OK"]);
        if (completion)
            completion(success, success ? nil : [NSError errorWithDomain:TORControllerErrorDomain code:code userInfo:userInfo]);
        
        *stop = YES;
        return YES;
    }];
}

- (void)resetConfForKey:(NSString *)key completion:(void (^__nullable)(BOOL success, NSError * __nullable error))completion {
	[self sendCommand:@"RESETCONF" arguments:@[key] data:nil observer:^BOOL(NSArray<NSNumber *> *codes, NSArray<NSData *> *lines, BOOL *stop) {
		NSUInteger code = codes.firstObject.unsignedIntegerValue;
		if (code != 250 && code != 515)
			return NO;

		NSString *message = [[NSString alloc] initWithData:lines.firstObject encoding:NSUTF8StringEncoding];
		NSDictionary<NSString *, NSString *> *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:message, NSLocalizedDescriptionKey, nil];
		BOOL success = (code == 250 && [message isEqualToString:@"OK"]);
		if (completion)
			completion(success, success ? nil : [NSError errorWithDomain:TORControllerErrorDomain code:code userInfo:userInfo]);

		*stop = YES;
		return YES;
	}];
}

- (void)setConfForKey:(NSString *)key withValue:(NSString *)value completion:(void (^__nullable)(BOOL success, NSError * __nullable error))completion {
	NSString *arg = [NSString stringWithFormat:@"%@=%@", key, value];

	[self sendCommand:@"SETCONF" arguments:@[arg] data:nil observer:^BOOL(NSArray<NSNumber *> *codes, NSArray<NSData *> *lines, BOOL *stop) {
		NSUInteger code = codes.firstObject.unsignedIntegerValue;
		if (code != 250 && code != 515)
			return NO;

		NSString *message = [[NSString alloc] initWithData:lines.firstObject encoding:NSUTF8StringEncoding];
		NSDictionary<NSString *, NSString *> *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:message, NSLocalizedDescriptionKey, nil];
		BOOL success = (code == 250 && [message isEqualToString:@"OK"]);
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

    [self sendCommand:@"SETCONF" arguments:conf_arg data:nil observer:^BOOL(NSArray<NSNumber *> *codes, NSArray<NSData *> *lines, BOOL *stop) {
        NSUInteger code = codes.firstObject.unsignedIntegerValue;
        if (code != 250 && code != 515)
            return NO;
        
        NSString *message = [[NSString alloc] initWithData:lines.firstObject encoding:NSUTF8StringEncoding];
        NSDictionary<NSString *, NSString *> *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:message, NSLocalizedDescriptionKey, nil];
        BOOL success = (code == 250 && [message isEqualToString:@"OK"]);
        if (completion)
            completion(success, success ? nil : [NSError errorWithDomain:TORControllerErrorDomain code:code userInfo:userInfo]);
        
        *stop = YES;
        return YES;
    }];

}

- (void)listenForEvents:(NSArray<NSString *> *)events completion:(void (^__nullable)(BOOL success, NSError * __nullable error))completion {
    [self sendCommand:@"SETEVENTS" arguments:events data:nil observer:^BOOL(NSArray<NSNumber *> *codes, NSArray<NSData *> *lines, BOOL *stop) {
        NSUInteger code = codes.firstObject.unsignedIntegerValue;
        if (code != 250 && code != 552)
            return NO;
        
        NSString *message = [[NSString alloc] initWithData:lines.firstObject encoding:NSUTF8StringEncoding];
        NSDictionary<NSString *, NSString *> *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:message, NSLocalizedDescriptionKey, nil];
        BOOL success = (code == 250 && [message isEqualToString:@"OK"]);
        if (success)
            self->_events = [NSOrderedSet orderedSetWithArray:events];
        if (completion)
            completion(success, success ? nil : [NSError errorWithDomain:TORControllerErrorDomain code:code userInfo:userInfo]);
        
        *stop = YES;
        return YES;
    }];
}

- (void)getInfoForKeys:(NSArray<NSString *> *)keys completion:(void (^)(NSArray<NSString *> *values))completion {
    [self sendCommand:@"GETINFO" arguments:keys data:nil observer:^BOOL(NSArray<NSNumber *> *codes, NSArray<NSData *> *lines, BOOL *stop) {
        if ((lines.count - 1) != keys.count)
            return NO;
        
        NSMutableArray<NSString *> *strings = [NSMutableArray new];
        for (NSData *line in lines) {
            NSString *string = [[NSString alloc] initWithData:line encoding:NSUTF8StringEncoding];
            if (!string)
                return NO;
            
            [strings addObject:string];
        }
        
        if (codes.lastObject.integerValue != 250 || ![strings.lastObject isEqualToString:@"OK"])
            return NO;
        
        NSMutableDictionary<NSString *, NSString *> *info = [NSMutableDictionary new];
        for (NSUInteger idx = 0; idx < strings.count - 1; idx++) {
            NSUInteger code = codes[idx].unsignedIntegerValue;
            if (code == 250) {
                NSString *pair = strings[idx];
                NSArray<NSString *> *components = [pair componentsSeparatedByString:@"="];
                if (components.count == 2) {
                    NSCharacterSet *quotes = [NSCharacterSet characterSetWithCharactersInString:@"\""];
                    NSString *key = [components[0] stringByTrimmingCharactersInSet:quotes];
                    NSString *value = [components[1] stringByTrimmingCharactersInSet:quotes];
                    if (![keys containsObject:key])
                        return NO;
                    
                    if ([keys containsObject:key])
                        [info setObject:value forKeyedSubscript:key];
                }
            }
        }
        
        NSMutableArray *values = [NSMutableArray new];
        for (NSString *key in keys)
            [values addObject:([info objectForKey:key] ?: [NSNull null])];
        
        if (completion)
            completion(values);
        
        *stop = YES;
        return YES;
    }];
}

- (void)getSessionConfiguration:(void (^)(NSURLSessionConfiguration * __nullable configuration))completion {
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

        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
        configuration.connectionProxyDictionary = @{(id)kCFProxyTypeKey: (id)kCFProxyTypeSOCKS,
                                                    (id)kCFStreamPropertySOCKSProxyHost: components[0],
                                                    (id)kCFStreamPropertySOCKSProxyPort: @([components[1] integerValue])};
        completion(configuration);
    }];
}

- (void)sendCommand:(NSString *)command arguments:(nullable NSArray<NSString *> *)arguments data:(nullable NSData *)data observer:(TORObserverBlock)observer {
    NSParameterAssert(command.length);
    if (!_channel)
        return;
    
    NSString *argumentsString = [[@[command] arrayByAddingObjectsFromArray:arguments] componentsJoinedByString:@" "];
    
    NSMutableData *commandData = [NSMutableData new];
    if (data.length) {
        [commandData appendBytes:"+" length:1];
    }
    [commandData appendData:[argumentsString dataUsingEncoding:NSUTF8StringEncoding]];
    [commandData appendBytes:"\r\n" length:2];
    if (data.length) {
        [commandData appendData:data];
        [commandData appendBytes:"\r\n.\r\n" length:5];
    }
    
    dispatch_data_t dispatchData = dispatch_data_create(commandData.bytes, commandData.length, [[self class] controlQueue], DISPATCH_DATA_DESTRUCTOR_DEFAULT);
    dispatch_io_write(_channel, 0, dispatchData, [[self class] controlQueue], ^(bool done, dispatch_data_t __unused data, int error) {
        if (done && !error && observer) {
            [self->_blocks insertObject:observer atIndex:0];
        }
    });
}

@end

NS_ASSUME_NONNULL_END
