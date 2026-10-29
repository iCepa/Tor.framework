//
//  TORArti.m
//  Tor
//
//  Created by Benjamin Erhart on 02.02.23.
//

#import "TORArti.h"
#import "arti-mobile.h"
//#import "arti-rpc-client-core.h"

@implementation TORArti

NSString *logfilePath;

NSRegularExpression *regex;

typedef void (^Completed)(void);

Completed completedBlock;


+ (void)startWithSocksPort:(NSUInteger)socksPort
                   dnsPort:(NSUInteger)dnsPort
                 obfs4Port:(NSUInteger)obfs4Port
             snowflakePort:(NSUInteger)snowflakePort
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
    regex = [[NSRegularExpression alloc]
             initWithPattern:@"\\x1b\\[[0-9;]*m"
             options:NSRegularExpressionDotMatchesLineSeparators error:nil];

    start_arti([stateDir.path cStringUsingEncoding:NSUTF8StringEncoding],
               [cacheDir.path cStringUsingEncoding:NSUTF8StringEncoding],
               (int)obfs4Port,
               (int)snowflakePort,
               [obfs4proxyPath.path cStringUsingEncoding:NSUTF8StringEncoding],
               [bridge cStringUsingEncoding:NSUTF8StringEncoding],
               (int)socksPort,
               (int)dnsPort,
               &loggingCb);
}

+ (void)startWithConfiguration:(TORConfiguration * _Nonnull)configuration
                     completed:(nullable void (^)(void))completed
{
    NSUInteger obfs4Port = 0;
    NSUInteger snowflakePort = 0;
    NSURL *obfs4proxyPath = nil;
    NSString *bridge = nil;

    if ([configuration valueOf:@"UseBridges"]) {
        NSString *ctp = [configuration valueOf:@"ClientTransportPlugin"];
        NSArray<NSString *> *pieces = [ctp componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceCharacterSet];

        NSRegularExpression *socksRegex = [[NSRegularExpression alloc]
                                           initWithPattern:@"^socks[45]$"
                                           options:NSRegularExpressionCaseInsensitive error:nil];

        if (pieces.count > 0) {
            if (pieces.count > 2
                && [socksRegex numberOfMatchesInString:pieces[1] options:0 range:NSMakeRange(0, pieces[1].length)] > 0
            ) {
                NSRegularExpression *addrRegex = [[NSRegularExpression alloc]
                                                  initWithPattern:@"^.+:(\\d{1,5})$"
                                                  options:0
                                                  error:nil];

                NSArray<NSTextCheckingResult *> *matches = [addrRegex matchesInString:pieces[2] options:0 range:NSMakeRange(0, pieces[2].length)];

                if (matches.count > 0 && matches[0].numberOfRanges > 1) {
                    NSRange range = [matches[0] rangeAtIndex:1];

                    NSString *port = [pieces[2] substringWithRange:range];

                    if ([pieces[0] caseInsensitiveCompare:@"snowflake"] == NSOrderedSame) {
                        snowflakePort = [port integerValue];
                    }
                    else if ([pieces[0] caseInsensitiveCompare:@"obfs4"] == NSOrderedSame) {
                        obfs4Port = [port integerValue];
                    }
                }
            }
            else if (pieces.count > 1
                     && [pieces[0] caseInsensitiveCompare:@"obfs4"] == NSOrderedSame
             ) {
                obfs4proxyPath = [[NSURL alloc] initFileURLWithPath:pieces[1] isDirectory:NO];
            }
        }

        bridge = [configuration valueOf:@"Bridge"];
    }

    [self startWithSocksPort:configuration.socksPort
                     dnsPort:configuration.dnsPort
                   obfs4Port:obfs4Port
               snowflakePort:snowflakePort
                     logfile:configuration.logfile
                    stateDir:configuration.dataDirectory
                    cacheDir:configuration.cacheDirectory
              obfs4proxyPath:obfs4proxyPath
                      bridge:bridge
                   completed:completed];
}

+ (void)stop
{
    stop_arti();
}

// Experimental! Not working.
//+ (NSError *)status
//{
//    ArtiRpcConnBuilder *builder;
//    ArtiRpcError *error;
//
//    if (arti_rpc_conn_builder_new(&builder, &error) != ARTI_RPC_STATUS_SUCCESS)
//    {
//        return [self nsErrorFromArti:error];
//    }
//
//    ArtiRpcConn *conn;
//
//    if (arti_rpc_conn_builder_connect(builder, &conn, &error) != ARTI_RPC_STATUS_SUCCESS)
//    {
//        arti_rpc_conn_builder_free(builder);
//
//        return [self nsErrorFromArti:error];
//    }
//
//    arti_rpc_conn_builder_free(builder);
//
//    const char *sessionId = arti_rpc_conn_get_session_id(conn);
//
//    NSLog(@"sessionId=%s", sessionId);
//
//    ArtiRpcStr *response;
//
//    if (arti_rpc_conn_execute(conn, [@"arti:get_client_status" cStringUsingEncoding:NSUTF8StringEncoding], &response, &error) != ARTI_RPC_STATUS_SUCCESS)
//    {
//        arti_rpc_conn_free(conn);
//
//        return [self nsErrorFromArti:error];
//    }
//
//    NSLog(@"response=%s", arti_rpc_str_get(response));
//
//    arti_rpc_str_free(response);
//
//    arti_rpc_conn_free(conn);
//
//    return nil;
//}
//
//+ (NSError *)nsErrorFromArti:(ArtiRpcError *)error
//{
//    NSString *msg = [NSString stringWithCString:arti_rpc_err_message(error) encoding:NSUTF8StringEncoding];
//    ArtiRpcStatus code = arti_rpc_err_status(error);
//
//    NSError *err = [[NSError alloc] initWithDomain:@"Arti" code:code userInfo:@{NSLocalizedDescriptionKey: msg}];
//
//    arti_rpc_err_free(error);
//
//    NSLog(@"Arti Error=%@", err);
//
//    return err;
//}

void loggingCb(const char * message)
{
    NSMutableString *msg = [[NSMutableString alloc] initWithUTF8String:message];

    if (completedBlock && [msg.lowercaseString containsString:@"directory is complete"]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completedBlock();
            completedBlock = nil;
        });
    }

    if (logfilePath.length < 1) return;

    [regex replaceMatchesInString:msg options:0 range:NSMakeRange(0, msg.length) withTemplate:@""];

    NSFileHandle *fh = [NSFileHandle fileHandleForUpdatingAtPath: logfilePath];
    [fh seekToEndOfFile];
    [fh writeData:[msg dataUsingEncoding:NSUTF8StringEncoding]];
    [fh closeFile];
}


@end
