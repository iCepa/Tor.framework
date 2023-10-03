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

ReaderCb readerBlock;

WriterCb writerBlock;

EventCb eventBlock;

LogCb logBlock;

NSRegularExpression *regex;

+ (void)startWithReader:(ReaderCb)readerCallback
                 writer:(WriterCb)writerCallback
               stateDir:(NSURL * _Nullable)stateDir
               cacheDir:(NSURL * _Nullable)cacheDir
               pcapFile:(NSURL * _Nullable)pcapFile
                onEvent:(nullable EventCb)eventCallback
                  onLog:(nullable LogCb)logCallback
{
    readerBlock = readerCallback;
    writerBlock = writerCallback;
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

    assert(stateDir.isFileURL);
    assert(cacheDir.isFileURL);

    if (!initialized) {
        // Remove ANSI colors.
        regex = [[NSRegularExpression alloc] initWithPattern:@"\\x1b\\[[0-9;]*m" options:NSRegularExpressionDotMatchesLineSeparators error:nil];

        init(&eventCb, &logCb);

        if (pcapFile) {
            [self setPcapPath:pcapFile];
        }
    }

    runProxy(&readerCb,
             &writerCb,
             [cacheDir.path cStringUsingEncoding:NSUTF8StringEncoding],
             [stateDir.path cStringUsingEncoding:NSUTF8StringEncoding]);
}

+ (void)stop
{
    closeProxy();

    readerBlock = nil;
    writerBlock = nil;
    eventBlock = nil;
    logBlock = nil;
}

+ (void)refreshCircuits
{
    refreshCircuits();
}

+ (void)setPcapPath:(NSURL *)path
{
    assert(path.isFileURL);

    NSFileManager *fm = NSFileManager.defaultManager;

    if (![fm fileExistsAtPath:path.path]) {
        [fm createFileAtPath:path.path contents:nil attributes:nil];
    }

    setPcapPath([path.path cStringUsingEncoding:NSUTF8StringEncoding]);
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

+ (void)receive:(NSArray<NSData *> *)packets
{
    const uint8_t * pointers[packets.count];
    unsigned long lens[packets.count];

    for (NSUInteger i = 0; i < packets.count; i++) {
        pointers[i] = packets[i].bytes;
        lens[i] = packets[i].length;
    }

    receive(pointers, lens, packets.count);
}


void readerCb(void)
{
    if (readerBlock)
    {
        readerBlock();
    }
}

bool writerCb(const uint8_t *packet, size_t len)
{
    if (writerBlock)
    {
        NSData *data = [[NSData alloc] initWithBytes:packet length:len];

        NSNumber *v = [[NSNumber alloc] initWithShort:((const unsigned char *)data.bytes)[0] >> 4];

        return writerBlock(data, v);
    }
    else {
        return false;
    }
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
