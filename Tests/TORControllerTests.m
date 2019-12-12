//
//  Tests.m
//  Tests
//
//  Created by Conrad Kramer on 8/10/15.
//

#import <XCTest/XCTest.h>
#import <Tor/Tor.h>

@interface TORControllerTests : XCTestCase

@property (nonatomic, strong) TORController *controller;
@property (readonly) NSData *cookie;

@end

@implementation TORControllerTests

+ (TORConfiguration *)configuration {
#if TARGET_IPHONE_SIMULATOR
    NSString *homeDirectory = nil;
    for (NSString *variable in @[@"IPHONE_SIMULATOR_HOST_HOME", @"SIMULATOR_HOST_HOME"]) {
        char *value = getenv(variable.UTF8String);
        if (value) {
            homeDirectory = @(value);
            break;
        }
    }
#else
    NSString *homeDirectory = NSHomeDirectory();
#endif

    TORConfiguration *configuration = [TORConfiguration new];
    configuration.cookieAuthentication = @YES;
    configuration.dataDirectory = [NSURL fileURLWithPath:NSTemporaryDirectory()];
    configuration.controlSocket = [[NSURL fileURLWithPath:homeDirectory] URLByAppendingPathComponent:@".Trash/control_port"];
    configuration.arguments = @[
        @"--ignore-missing-torrc",
        @"--GeoIPFile", [NSBundle.mainBundle pathForResource:@"geoip" ofType:nil],
        @"--GeoIPv6File", [NSBundle.mainBundle pathForResource:@"geoip6" ofType:nil],
    ];
    return configuration;
}

+ (void)setUp {
    [super setUp];

    TORThread *thread = [[TORThread alloc] initWithConfiguration:self.configuration];
    [thread start];

    [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5f]];
}

- (void)setUp {
    [super setUp];

    self.controller = [[TORController alloc] initWithSocketURL:[[[self class] configuration] controlSocket]];
}

- (void)testCookieAuthenticationFailure {
    XCTestExpectation *expectation = [self expectationWithDescription:@"authenticate callback"];
    [self.controller authenticateWithData:[@"invalid" dataUsingEncoding:NSUTF8StringEncoding] completion:^(BOOL success, NSError *error) {
        XCTAssertFalse(success);
        XCTAssertEqualObjects(error.domain, TORControllerErrorDomain);
        XCTAssertNotEqual(error.code, 250);
        XCTAssertGreaterThan(error.localizedDescription, @"Authentication failed: Wrong length on authentication cookie.");
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1.0f handler:nil];
}

- (void)testCookieAuthenticationSuccess {
    XCTestExpectation *expectation = [self expectationWithDescription:@"authenticate callback"];

    [self.controller authenticateWithData:self.cookie completion:^(BOOL success, NSError *error) {
        XCTAssertTrue(success);
        XCTAssertNil(error);
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1.0f handler:nil];
}

- (void)testSessionConfiguration {
    XCTestExpectation *expectation = [self expectationWithDescription:@"tor callback"];

    [self exec:^{
        [self.controller getSessionConfiguration:^(NSURLSessionConfiguration *configuration) {
            NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration];
            [[session dataTaskWithURL:[NSURL URLWithString:@"https://facebookcorewwwi.onion/"] completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                XCTAssertEqual([(NSHTTPURLResponse *)response statusCode], 200);
                XCTAssertNil(error);
                [expectation fulfill];
            }] resume];
        }];
    }];

    [self waitForExpectationsWithTimeout:120.0f handler:nil];
}

- (void)testGetAndCloseCircuits
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"resolution callback"];

    [self exec:^{
        [self.controller getCircuits:^(NSArray<TORCircuit *> * _Nonnull circuits) {
            NSLog(@"circuits=%@", circuits);

            for (TORCircuit *circuit in circuits)
            {
                for (TORNode *node in circuit.nodes) {
                    XCTAssert(node.fingerprint.length > 0, @"A circuit should have a fingerprint.");
                    XCTAssert(node.ipv4Address.length > 0 || node.ipv6Address.length > 0, @"A circuit should have an IPv4 or IPv6 address.");
                }
            }

            [self.controller closeCircuits:circuits completion:^(BOOL success) {
                XCTAssertTrue(success, @"Circuits were closed successfully.");

                [expectation fulfill];
            }];
        }];
    }];

    [self waitForExpectationsWithTimeout:120 handler:nil];
}

- (void)testReset
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"reset callback"];

    [self exec:^{
        [self.controller resetConnection:^(BOOL success) {
            NSLog(@"success=%d", success);

            XCTAssertTrue(success, @"Reset should work correctly.");

            [expectation fulfill];
        }];
    }];

    [self waitForExpectationsWithTimeout:120 handler:nil];
}


// MARK: Helper Properties and Methods

- (NSData *)cookie
{
    return [NSData dataWithContentsOfURL:
            [[self.class configuration].dataDirectory
             URLByAppendingPathComponent:@"control_auth_cookie"]];
}

- (void)exec:(void (^)(void))callback
{
    TORController *controller = self.controller;

    [controller authenticateWithData:self.cookie completion:^(BOOL success, NSError * _Nullable error) {
        XCTAssertTrue(success);
        XCTAssertNil(error);

        [controller addObserverForCircuitEstablished:^(BOOL established) {
            // May be called multiple times. We wait until circuit is established.
            if (!established)
            {
                return;
            }

            callback();
        }];
    }];
}

@end
