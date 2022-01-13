//
//  AppDelegate.m
//  Tor_Example_Mac
//
//  Created by Benjamin Erhart on 13.01.22.
//  Copyright © 2022 Benjamin Erhart. All rights reserved.
//

#import "AppDelegate.h"
#import <Tor.h>

@interface AppDelegate ()


@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    TORConfiguration *configuration = [TORConfiguration new];
    configuration.ignoreMissingTorrc = YES;
    configuration.avoidDiskWrites = YES;
    configuration.clientOnly = YES;
    configuration.cookieAuthentication = YES;
    configuration.autoControlPort = YES;
    configuration.dataDirectory = [NSURL fileURLWithPath:NSTemporaryDirectory()];
    configuration.geoipFile = NSBundle.geoIpBundle.geoipFile;
    configuration.geoip6File = NSBundle.geoIpBundle.geoip6File;

    TORThread *thread = [[TORThread alloc] initWithConfiguration:configuration];
    [thread start];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        NSData *cookie = configuration.cookie;
        TORController *controller = [[TORController alloc] initWithControlPortFile:configuration.controlPortFile];
        [controller authenticateWithData:cookie completion:^(BOOL success, NSError *error) {
            __weak TORController *c = controller;

            NSLog(@"authenticated success=%d", success);

            if (!success)
                return;

            [c addObserverForCircuitEstablished:^(BOOL established) {
                NSLog(@"established=%d", established);

                if (!established)
                    return;

                [c getCircuits:^(NSArray<TORCircuit *> * _Nonnull circuits) {
                    NSLog(@"Circuits: %@", circuits);
                }];
            }];
        }];
    });
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}


- (BOOL)applicationSupportsSecureRestorableState:(NSApplication *)app {
    return YES;
}


@end
