//
//  NSCharacterSet+Quotes.h
//  Tor
//
//  Created by Benjamin Erhart on 12.12.19.
//  Copyright © 2019 Conrad Kramer. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSCharacterSet (Quotes)

@property (class, readonly) NSCharacterSet *doubleQuote;
@property (class, readonly) NSCharacterSet *longNameDivider;

@end

NS_ASSUME_NONNULL_END
