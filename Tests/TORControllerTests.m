//
//  Tests.m
//  Tests
//
//  Created by Conrad Kramer on 8/10/15.
//
//

#import <XCTest/XCTest.h>
#import <Tor/Tor.h>

@interface TORControllerTests : XCTestCase

@property (nonatomic, strong) TORController *controller;

@end

@implementation TORControllerTests

+ (TORConfiguration *)configuration {
    TORConfiguration *configuration = [TORConfiguration new];
    configuration.cookieAuthentication = YES;
    configuration.dataDirectory = NSTemporaryDirectory();
    configuration.controlSocket = @"/Users/conradev/.Trash/control_port";
    configuration.arguments = @[@"--ignore-missing-torrc"];
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
    
    self.controller = [[TORController alloc] initWithControlSocketPath:[[[self class] configuration] controlSocket]];
}

- (void)testCookieAuthenticationFailure {
    XCTestExpectation *expectation = [self expectationWithDescription:@"authenticate callback"];
    [self.controller authenticateWithData:[@"invalid" dataUsingEncoding:NSUTF8StringEncoding] completion:^(BOOL success, NSError *error) {
        XCTAssertFalse(success);
        XCTAssertEqualObjects(error.domain, TORControllerErrorDomain);
        XCTAssertNotEqual(error.code, 250);
        XCTAssertGreaterThan(error.localizedDescription.length, 0);
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1.0f handler:nil];
}

- (void)testCookieAuthenticationSuccess {
    XCTestExpectation *expectation = [self expectationWithDescription:@"authenticate callback"];
    
    NSString *cookiePath = [[[[self class] configuration] dataDirectory] stringByAppendingPathComponent:@"control_auth_cookie"];
    NSData *cookie = [NSData dataWithContentsOfFile:cookiePath];
    [self.controller authenticateWithData:cookie completion:^(BOOL success, NSError *error) {
        XCTAssertTrue(success);
        XCTAssertNil(error);
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1.0f handler:nil];
}

@end
