//
//  TORArti.m
//  Tor
//
//  Created by Benjamin Erhart on 02.02.23.
//

#import "TORArti.h"
#import "arti-mobile.h"

@implementation TORArti

NSString *logfilePath;

NSRegularExpression *regex;


+ (void)startWithSocksPort:(NSUInteger)socksPort dnsPort:(NSUInteger)dnsPort logfile:(NSURL * _Nullable)logfile;
{
    logfilePath = logfile.path;

    NSFileManager *fm = NSFileManager.defaultManager;

    if (![fm fileExistsAtPath:logfilePath]) {
        [fm createFileAtPath:logfilePath contents:nil attributes:nil];
    }

    NSString *stateDir = [[[fm URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask]
                           firstObject]
                          URLByAppendingPathComponent:@"org.torproject.Arti"].path;

    NSString *cacheDir = [[[fm URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask]
                           firstObject]
                          URLByAppendingPathComponent:@"org.torproject.Arti"].path;

    // Remove ANSI colors.
    regex = [[NSRegularExpression alloc] initWithPattern:@"\\x1b\\[[0-9;]*m" options:NSRegularExpressionDotMatchesLineSeparators error:nil];

    start_arti([stateDir cStringUsingEncoding:NSUTF8StringEncoding],
               [cacheDir cStringUsingEncoding:NSUTF8StringEncoding],
               (int)socksPort, (int)dnsPort, &loggingCb);
}

void loggingCb(const char * message)
{
    NSMutableString *msg = [[NSMutableString alloc] initWithUTF8String:message];

    [regex replaceMatchesInString:msg options:0 range:NSMakeRange(0, msg.length) withTemplate:@""];

    NSFileHandle *fh = [NSFileHandle fileHandleForUpdatingAtPath: logfilePath];
    [fh seekToEndOfFile];
    [fh writeData:[msg dataUsingEncoding:NSUTF8StringEncoding]];
    [fh closeFile];
}


@end
