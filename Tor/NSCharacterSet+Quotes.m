//
//  NSCharacterSet+Quotes.m
//  Tor
//
//  Created by Benjamin Erhart on 12.12.19.
//  Copyright © 2019 Conrad Kramer. All rights reserved.
//

#import "NSCharacterSet+Quotes.h"

@implementation NSCharacterSet (Quotes)

static NSCharacterSet *_doubleQuote;
static NSCharacterSet *_longNameDivider;

+ (NSCharacterSet *)doubleQuote
{
    if (!_doubleQuote)
    {
        _doubleQuote = [NSCharacterSet characterSetWithCharactersInString:@"\""];
    }

    return _doubleQuote;
}

+ (NSCharacterSet *)longNameDivider
{
    if (!_longNameDivider)
    {
        _longNameDivider = [NSCharacterSet characterSetWithCharactersInString:@"~="];
    }

    return _longNameDivider;
}

@end
