# Tor.framework

[![Carthage Compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage) [![Travis CI](https://img.shields.io/travis/iCepa/Tor.framework.svg)](https://travis-ci.org/iCepa/Tor.framework)

Tor.framework is the easiest way to embed Tor in your iOS application. The API is *not* stable yet, and subject to change.

Currently, the framework compiles in static versions of `tor`, `libevent`, `openssl`, and `liblzma`:

|          |         |
|:-------- | -------:|
| tor      | 0.3.3.5-rc |
| libevent | 2.1.8   |
| OpenSSL  | 1.1.0g  |
| liblzma  | 5.2.3   |

## Requirements

- iOS 8.0 or later
- Xcode 7.0 or later
- `autoconf`, `automake`, `libtool` and `gettext` in your `PATH`

## Installation

Embedded frameworks require a minimum deployment target of iOS 8 or OS X Mavericks (10.9).

If you use `brew`, make sure to install `autoconf`, `automake`, `libtool` and `gettext`:

```
brew install automake autoconf libtool gettext
```

### Carthage

To integrate Tor into your Xcode project using Carthage, specify it in your `Cartfile`:

```ogdl
github "iCepa/Tor.framework" "master"
```

## Usage

Starting an instance of Tor involves using three classes: `TORThread`, `TORConfiguration` and `TORController`.

Here is an example of integrating Tor with `NSURLSession`:

```objc
TORConfiguration *configuration = [TORConfiguration new];
configuration.cookieAuthentication = @(YES);
configuration.dataDirectory = [NSURL URLWithString:NSTemporaryDirectory()];
configuration.controlSocket = [configuration.dataDirectory URLByAppendingPathComponent:@"control_port"];
configuration.arguments = @[@"--ignore-missing-torrc"];

TORThread *thread = [[TORThread alloc] initWithConfiguration:configuration];
[thread start];

NSURL *cookieURL = [configuration.dataDirectory URLByAppendingPathComponent:@"control_auth_cookie"];
NSData *cookie = [NSData dataWithContentsOfURL:cookieURL];
TORController *controller = [[TORController alloc] initWithSocketURL:configuration.controlSocket];
[controller authenticateWithData:cookie completion:^(BOOL success, NSError *error) {
    if (!success)
        return;
    
    [controller addObserverForCircuitEstablished:^(BOOL established) {
        if (!established)
            return;
        
        [controller getSessionConfiguration:^(NSURLSessionConfiguration *configuration) {
            NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration];
            ...
        }];
    }];
}];
```

## License

Tor.framework is available under the MIT license. See the [`LICENSE`](https://github.com/iCepa/Tor.framework/blob/master/LICENSE) file for more info.
