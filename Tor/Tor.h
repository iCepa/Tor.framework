//
//  Tor.h
//  Tor
//
//  Created by Conrad Kramer on 8/10/15.
//
//

#import <Foundation/Foundation.h>

#ifdef __cplusplus
#define TOR_EXTERN    extern "C" __attribute__((visibility ("default")))
#else
#define TOR_EXTERN    extern __attribute__((visibility ("default")))
#endif

#import <Tor/TORController.h>
#import <Tor/TORConfiguration.h>
#import <Tor/TORThread.h>
#import <Tor/TORLogging.h>
