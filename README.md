# Tor.framework

[![Version](https://img.shields.io/cocoapods/v/Tor.svg?style=flat)](https://cocoapods.org/pods/Tor)
[![License](https://img.shields.io/cocoapods/l/Tor.svg?style=flat)](https://cocoapods.org/pods/Tor)
[![Platform](https://img.shields.io/cocoapods/p/Tor.svg?style=flat)](https://cocoapods.org/pods/Tor)

Tor.framework is the easiest way to embed Tor in your iOS application. The API is *not* stable yet, and subject to change.

Currently, the framework compiles in the following versions of `tor`, `libevent`, `openssl`, and `liblzma`:

| Component | Version  |
|:--------- | --------:|
| tor       | 0.4.9.8  |
| libevent  | 2.1.12   |
| OpenSSL   | 3.6.2    |
| liblzma   | 5.8.3    |
| Arti      | 1.7.0    |
| Onionmasq | 0.6.2    |


## LATEST CHANGES

- No inline compilation necessary anymore: Now uses precompiled `tor.xcframework`, 
  `tor-nolzma.xcframework` and `arti.xcframework`which will be downloaded from 
  https://github.com/iCepa/Tor.framework/releases on install/update. 
- Finally removed `TorStatic.podspec` as there was no feedback about it and it started to be in the way.


## Example

To run the example project, clone the repo, and run `pod install` from the Example directory first.

## Requirements

- iOS 15.0 or later
- MacOS 11.0 or later
- Xcode 26.0 or later


## Installation

C-Tor is available through [CocoaPods](https://cocoapods.org). To install it, 
simply add the following line to your Podfile:

```ruby
use_frameworks!
pod 'Tor', '~> 409'
```

(or `Tor/GeoIP` - see below.)


Arti is available through it's own Podspec. To install it,
simply add the following line to your Podfile:

```ruby
use_frameworks!
pod 'Tor/Arti', 
  :podspec => 'https://raw.githubusercontent.com/iCepa/Tor.framework/refs/heads/pure_pod/Arti.podspec'
```

## Compiling yourself

Prerequesite:
- [Homebrew](https://brew.sh)

```sh
git clone https://github.com/iCepa/Tor.framework.git
cd Tor.framework
brew bundle
rustup default stable 
rustup target add aarch64-apple-darwin
rustup target add x86_64-apple-darwin
rustup target add aarch64-apple-ios
rustup target add aarch64-apple-ios-sim
rustup target add x86_64-apple-ios
cargo install cbindgen
./build-xcframework.sh -ac
```

*NOTE*: Builds are not reproducible.

## Preparing a new release

For maintainers/contributors of Tor.framework, a new release should be prepared by 
doing the following:

- Update the version numbers of the libraries used in [`build-xcframework.sh`](build-xcframework.sh).

- Follow the instructions in [Compiling yourself](#compiling-yourself)

- Check the logs and test the created `tor.xcframework`, `tor-nolzma.xcframework` and `arti.xcframework` 
  with the contained example apps.
  
- Update info, version numbers and checksums in `README.md`, `Tor.podspec` and `Arti.podspec`!

- Commit, tag and push new release.

- Create a pre-release on https://github.com/iCepa/Tor.framework/releases with the latest 
  info as per older releases and upload the created `tor.xcframework.zip`, 
  `tor-nolzma.framework.zip` and `arti.framework.zip` files.

- Then lint like this:

```sh
pod lib lint --allow-warnings Tor.podspec
```

- If the linting went well, publish to CocoaPods:

```sh
pod trunk push --allow-warnings Tor.podspec 
```

- Then update the [release](https://github.com/iCepa/Tor.framework/releases) in GitHub, 
  setting it as the latest release.


## Usage

### All-in-one `TorManager`

For a headache-free start into the world of Tor on iOS and macOS, check out
the new [`TorManager` project](https://github.com/tladesignz/TorManager)!

### Do-it-yourself

Starting an instance of Tor involves using three classes: `TORThread`, `TORConfiguration` and `TORController`.

Here is an example of integrating Tor with `NSURLSession`:

```objc
TORConfiguration *configuration = [TORConfiguration new];
configuration.ignoreMissingTorrc = YES;
configuration.cookieAuthentication = YES;
configuration.dataDirectory = [NSURL fileURLWithPath:NSTemporaryDirectory()];
configuration.controlSocket = [configuration.dataDirectory URLByAppendingPathComponent:@"control_port"];

TORThread *thread = [[TORThread alloc] initWithConfiguration:configuration];
[thread start];

NSData *cookie = configuration.cookie;
TORController *controller = [[TORController alloc] initWithSocketURL:configuration.controlSocket];

NSError *error;
[controller connect:&error];

if (error) {
    NSLog(@"Error: %@", error);
    return;
}

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


### GeoIP

In your `Podfile` use the subspec `GeoIP` instead of the root spec:

```ruby
use_frameworks!
pod 'Tor/GeoIP'
```

The subspec will create a "GeoIP" bundle with the appropriate GeoIP files.

To use it with Tor, add this to your configuration:

```objc
TORConfiguration *configuration = [TORConfiguration new];
configuration.geoipFile = NSBundle.geoIpBundle.geoipFile;
configuration.geoip6File = NSBundle.geoIpBundle.geoip6File;
```

### Experimental Arti and Onionmasq podspec

Since I while, this project also contains a podspec, which uses Arti (A Rust Tor Implementation)
or Onionmasq (Arti with a wrapper taking in IP packets, useful for VPN-style apps.)

```ruby
pod 'Tor/Arti', :podspec => 'https://raw.githubusercontent.com/iCepa/Tor.framework/pure_pod/Arti.podspec'
```

or

```ruby
pod 'Tor/Onionmasq', :podspec => 'https://raw.githubusercontent.com/iCepa/Tor.framework/pure_pod/Arti.podspec'
```

There's currently a known issue: Onionmasq won't compile if you build for iOS or an iOS simulator right away,
since some Rust dependencies use custom build scripts which need to get compiled for MacOS, but will try
to use the wrong platform (iOS) in this case. 
This can be fixed, if you compile for your machine first:

```sh
cd Pods/Tor/Tor/onionmasq
make macos-debug-aarch64-apple-darwin # If you run on Apple Silicon
make macos-debug-x86_64-apple-darwin # If you're still on Intel
```

Then, the Rust dependency build scripts will be compiled correctly and the 
Xcode build will run correctly.

You can also precompile your debug and release targets on the command line, if you like:

```sh
make macos-release-universal-macos # Release build for MacOS as universal binary
make ios-release-aarch64-apple-ios # Release build for iOS
make ios-debug-aarch64-apple-ios # Debug build for iOS device
make ios-debug-aarch64-apple-ios-sim # Debug build for iOS simulator running on Apple Silicon
make ios-debug-x86_64-apple-ios # Debug build for iOS simulator running on Intel
```


## Further reading

https://tordev.guardianproject.info


## Authors

- Conrad Kramer, conrad@conradkramer.com
- Chris Ballinger, chris@chatsecure.org
- Mike Tigas, mike@tig.as
- Benjamin Erhart, berhart@netzarchitekten.com


## License

Tor.framework is available under the MIT license. See the 
[`LICENSE`](https://github.com/iCepa/Tor.framework/blob/master/LICENSE) file for more info.
