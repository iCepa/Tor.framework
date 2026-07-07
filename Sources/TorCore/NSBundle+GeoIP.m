//
//  NSBundle+GeoIP.m
//  Tor
//
//  Created by Benjamin Erhart on 02.12.21.
//

#import "NSBundle+GeoIP.h"
#import "TORConfiguration.h"

@implementation NSBundle (GeoIP)

+ (NSBundle *)geoIpBundle
{
    NSURL *url = [[NSBundle bundleForClass:TORConfiguration.class] URLForResource:@"GeoIP" withExtension:@"bundle"];
    if (!url) return nil;

    return [NSBundle bundleWithURL:url];
}

- (NSURL *)geoipFile
{
    return [self URLForResource:@"geoip" withExtension:nil];
}

- (NSURL *)geoip6File
{
    return [self URLForResource:@"geoip6" withExtension:nil];
}

@end
