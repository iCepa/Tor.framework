//
//  main.m
//  test
//
//  Created by Conrad Kramer on 11/14/16.
//  Copyright © 2016 Conrad Kramer. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (weak) IBOutlet NSWindow *window;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

@end

int main(int argc, const char * argv[]) {
    return NSApplicationMain(argc, argv);
}
