//
//  AppDelegate.m
//  Tor
//
//  Created by Benjamin Erhart on 01/13/2022.
//  Copyright (c) 2022 Benjamin Erhart. All rights reserved.
//

#import "AppDelegate.h"
#import <Tor/NSBundle+GeoIP.h>
#import <Tor/TORConfiguration.h>
#import <Tor/TORController.h>
#import <Tor/TORThread.h>

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
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
            {
                return;
            }

            [c addObserverForCircuitEstablished:^(BOOL established) {
                NSLog(@"established=%d", established);

                if (!established)
                {
                    return;
                }

                [c getCircuits:^(NSArray<TORCircuit *> * _Nonnull circuits) {
                    NSLog(@"Circuits: %@", circuits);
                }];

//                CFTimeInterval startTime = CACurrentMediaTime();
//
//                [c getInfoForKeys:@[@"ns/all"] completion:^(NSArray<NSString *> * _Nonnull values) {
//                    NSLog(@"Line count: %lu", values.count);
//                    NSLog(@"Elapsed Time: %f", CACurrentMediaTime() - startTime);
//
//
//                    NSArray<TORNode *> *nodes = [TORNode parseFromNsString:values.firstObject];
//
//                    NSMutableArray<TORNode *> *exitNodes = [NSMutableArray new];
//
//                    for (TORNode *node in nodes)
//                    {
//                        if (node.isExit)
//                        {
//                            [exitNodes addObject:node];
//                        }
//                    }
//
//                    NSLog(@"#Nodes: %lu, #Exit Nodes: %lu", nodes.count, exitNodes.count);
//                    NSLog(@"Elapsed Time: %f", CACurrentMediaTime() - startTime);
//
//                    [c resolveCountriesOfNodes:exitNodes testCapabilities:NO completion:^{
//                        for (TORNode *node in nodes) {
//                            NSLog(@"Node: %@", node);
//                        }
//
//                        NSLog(@"Elapsed Time: %f", CACurrentMediaTime() - startTime);
//                    }];
//                }];
            }];
        }];
    });

    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
