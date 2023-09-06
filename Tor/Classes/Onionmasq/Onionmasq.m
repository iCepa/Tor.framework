//
//  Onionmasq.m
//  Tor
//
//  Created by Benjamin Erhart on 30.08.23.
//

#import "Onionmasq.h"
#import "onionmasq_apple.h"

@implementation Onionmasq

BOOL initialized;

EventCb eventBlock;

LogCb logBlock;

NSRegularExpression *regex;


+ (void)startWithFd:(int32_t)fd
           stateDir:(NSURL * _Nullable)stateDir
           cacheDir:(NSURL * _Nullable)cacheDir
            onEvent:(nullable EventCb)eventCallback
              onLog:(nullable LogCb)logCallback
{
    eventBlock = eventCallback;
    logBlock = logCallback;

    NSFileManager *fm = NSFileManager.defaultManager;

    if (!stateDir) {
        stateDir = [[fm URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask]
                     firstObject];
    }

    if (!cacheDir) {
        cacheDir = [[fm URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask]
                     firstObject];
    }

    if (!initialized) {
        // Remove ANSI colors.
        regex = [[NSRegularExpression alloc] initWithPattern:@"\\x1b\\[[0-9;]*m" options:NSRegularExpressionDotMatchesLineSeparators error:nil];

        init(&eventCb, &logCb);
    }

    runProxy(fd,
             [cacheDir.path cStringUsingEncoding:NSUTF8StringEncoding],
             [stateDir.path cStringUsingEncoding:NSUTF8StringEncoding]);
}

+ (void)stop
{
    closeProxy();

    eventBlock = nil;
}

+ (void)refreshCircuits
{
    refreshCircuits();
}

+ (long long)getBytesReceived
{
    return getBytesReceived();
}

+ (long long)getBytesSent
{
    return getBytesSent();
}

+ (void)resetCounters
{
    resetCounters();
}

+ (void)setCountryCodeWith:(NSString *)countryCode
{
    setCountryCode([countryCode cStringUsingEncoding:NSUTF8StringEncoding]);
}



void eventCb(const char * event)
{
    if (eventBlock)
    {
        NSString *evt = [[NSString alloc] initWithUTF8String:event];
        NSData *data = [evt dataUsingEncoding:NSUTF8StringEncoding];
        NSError *error = nil;

        id object = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];

        if (error)
        {
            eventBlock(evt);
        }
        else {
            eventBlock(object);
        }
    }
}

void logCb(const char * log)
{
    if (logBlock)
    {
        NSMutableString *msg = [[NSMutableString alloc] initWithUTF8String:log];

        [regex replaceMatchesInString:msg options:0 range:NSMakeRange(0, msg.length) withTemplate:@""];

        logBlock(msg);
    }
}


@end
