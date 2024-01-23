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

typedef void (^Completed)(void);

Completed completedBlock;


+ (void)startWithSocksPort:(NSUInteger)socksPort
                   dnsPort:(NSUInteger)dnsPort
                   logfile:(NSURL * _Nullable)logfile
                  stateDir:(NSURL * _Nullable)stateDir
                  cacheDir:(NSURL * _Nullable)cacheDir
           obfs4proxyPath:(NSURL * _Nullable)obfs4proxyPath
                    bridge:(NSString * _Nullable)bridge
                 completed:(nullable void (^)(void))completed
{
    logfilePath = logfile.path;
    completedBlock = completed;

    NSFileManager *fm = NSFileManager.defaultManager;

    if (![fm fileExistsAtPath:logfilePath]) {
        [fm createFileAtPath:logfilePath contents:nil attributes:nil];
    }

    if (!stateDir) {
        stateDir = [[[fm URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask]
                     firstObject]
                    URLByAppendingPathComponent:@"org.torproject.Arti"];
    }

    if (!cacheDir) {
        cacheDir = [[[fm URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask]
                     firstObject]
                    URLByAppendingPathComponent:@"org.torproject.Arti"];
    }

    // Remove ANSI colors.
    regex = [[NSRegularExpression alloc] initWithPattern:@"\\x1b\\[[0-9;]*m" options:NSRegularExpressionDotMatchesLineSeparators error:nil];

    start_arti([stateDir.path cStringUsingEncoding:NSUTF8StringEncoding],
               [cacheDir.path cStringUsingEncoding:NSUTF8StringEncoding],
               [obfs4proxyPath.path cStringUsingEncoding:NSUTF8StringEncoding],
               [bridge cStringUsingEncoding:NSUTF8StringEncoding],
               (int)socksPort, (int)dnsPort, &loggingCb);
}

+ (void)startWithConfiguration:(TORConfiguration * _Nonnull)configuration
                     completed:(nullable void (^)(void))completed
{
    NSURL *obfs4proxyPath = nil;
    NSString *bridge = nil;

    if ([configuration valueOf:@"UseBridges"]) {
        NSString *ctp = [configuration valueOf:@"ClientTransportPlugin"];
        NSArray* pieces = [ctp componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceCharacterSet];

        if (pieces.count > 1 && ((NSString *)pieces[1]).length > 0) {
            obfs4proxyPath = [[NSURL alloc] initFileURLWithPath:pieces[1] isDirectory:NO];

            bridge = [configuration valueOf:@"Bridge"];
        }
    }

    [self startWithSocksPort:configuration.socksPort
                     dnsPort:configuration.dnsPort
                     logfile:configuration.logfile
                    stateDir:configuration.dataDirectory
                    cacheDir:configuration.cacheDirectory
              obfs4proxyPath:obfs4proxyPath
                      bridge:bridge
                   completed:completed];
}

void loggingCb(const char * message)
{
    NSMutableString *msg = [[NSMutableString alloc] initWithUTF8String:message];

    if (completedBlock && [msg containsString:@"Directory is complete"]) {
        completedBlock();
        completedBlock = nil;
    }

    if (logfilePath.length < 1) return;

    [regex replaceMatchesInString:msg options:0 range:NSMakeRange(0, msg.length) withTemplate:@""];

    NSFileHandle *fh = [NSFileHandle fileHandleForUpdatingAtPath: logfilePath];
    [fh seekToEndOfFile];
    [fh writeData:[msg dataUsingEncoding:NSUTF8StringEncoding]];
    [fh closeFile];
}


@end
