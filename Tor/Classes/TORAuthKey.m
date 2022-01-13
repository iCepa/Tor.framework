//
//  TORAuthKey.m
//  Tor
//
//  Created by Benjamin Erhart on 29.09.21.
//

#import "TORAuthKey.h"

@implementation TORAuthKey

- (instancetype)initFromUrl:(NSURL *)url
{
    if ((self = [super init]))
    {
        NSError *error;
        NSString *raw = [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:&error];

        if (error)
        {
            NSLog(@"[%@] Error while setting key: %@", NSStringFromClass(self.class), error.localizedDescription);

            return nil;
        }

        _file = url;

        NSMutableArray *parts = [raw componentsSeparatedByString:@":"].mutableCopy;

        NSString *piece = [TORAuthKey getNextPieceOf:parts];
        if (!piece) return nil;

        if (self.isPrivate) {
            _onionAddress = [[NSURL alloc] initWithString:[NSString stringWithFormat:@"http://%@.onion", piece]];

            piece = [TORAuthKey getNextPieceOf:parts];
            if (!piece) return nil;
        }

        _authType = piece;

        piece = [TORAuthKey getNextPieceOf:parts];
        if (!piece) return nil;
        _keyType = piece;

        piece = [TORAuthKey getNextPieceOf:parts];
        if (!piece) return nil;
        _key = piece;
    }

    return self;
}

- (instancetype)initFromFile:(NSString *)path
{
    return [self initFromUrl:[NSURL fileURLWithPath:path]];
}

- (instancetype)initPrivate:(NSString * _Nonnull)key forDomain:(NSURL * _Nonnull)url
{
    if ((self = [super init]))
    {
        NSString *name = url.host.stringByDeletingPathExtension;

        if (!name || [name isEqualToString:@""]) name = [NSUUID UUID].UUIDString;

        _file = [[NSURL alloc] initFileURLWithPath:[NSString stringWithFormat:@"%@.auth_private", name]];
        _onionAddress = url;
        _authType = @"descriptor"; // Currently the only allowed value.
        _keyType = @"x25519"; // Currently the only allowed value.
        _key = key;
    }

    return self;
}

- (instancetype)initPublic:(NSString * _Nonnull)key withName: (NSString * _Nonnull)name
{
    if ((self = [super init]))
    {
        if (!name || [name isEqualToString:@""]) name = [NSUUID UUID].UUIDString;

        _file = [[NSURL alloc] initFileURLWithPath:[NSString stringWithFormat:@"%@.auth", name]];
        _onionAddress = nil;
        _authType = @"descriptor"; // Currently the only allowed value.
        _keyType = @"x25519"; // Currently the only allowed value.
        _key = key;
    }
    
    return self;
}


// MARK: Public Methods

- (BOOL)isPrivate
{
    return [_file.pathExtension isEqualToString:@"auth_private"];
}

- (void)setDirectory:(NSURL *)directory
{
    NSString *filename = _file.lastPathComponent;

    if (filename)
    {
        NSURL *file = [directory URLByAppendingPathComponent:filename];

        if (file) _file = file;
    }
}

- (BOOL)persist
{
    NSError *error;
    [self.description writeToURL:_file atomically:YES encoding:NSUTF8StringEncoding error:&error];

    if (error)
    {
        NSLog(@"[%@] Error while persisting key: %@", NSStringFromClass(self.class), error.localizedDescription);
        NSLog(@"%@", self.debugDescription);

        return NO;
    }

    return YES;
}


- (NSString *)description
{
    if (self.isPrivate) {
        // Spec says: "MUST NOT have the ".onion" suffix.

        return [NSString stringWithFormat:@"%@:%@:%@:%@",
                _onionAddress.host.stringByDeletingPathExtension,
                _authType, _keyType, _key];
    }

    return [NSString stringWithFormat:@"%@:%@:%@", _authType, _keyType, _key];
}

- (NSString *)debugDescription
{
    return [NSString stringWithFormat:@"%@: file: %@, isPrivate: %d, onionAddress: %@, authType: %@, keyType: %@, key: %@",
            NSStringFromClass(self.class), _file, self.isPrivate, _onionAddress, _authType, _keyType, _key];
}


// MARK: Equality

- (BOOL)isEqualToAuthKey:(TORAuthKey *)authKey
{
    NSString *url2 = authKey.file.absoluteString;

    if (!url2)
    {
        return NO;
    }

    return [_file.absoluteString isEqualToString:url2];
}

- (BOOL)isEqual:(id)object
{
    if (self == object)
    {
        return YES;
    }

    if (![object isKindOfClass:[TORAuthKey class]])
    {
        return NO;
    }

    return [self isEqualToAuthKey:object];
}

- (NSUInteger)hash
{
    return _file.hash;
}


// MARK: Class Methods

+ (BOOL)isAuthFile:(NSURL *)url
{
    return [url.pathExtension isEqualToString:@"auth"] || [url.pathExtension isEqualToString:@"auth_private"];
}


// MARK: Private Methods

+ (NSString *)getNextPieceOf:(NSMutableArray *)parts
{
    NSString *piece = parts.firstObject;

    if (parts.count > 0) [parts removeObjectAtIndex: 0];

    if (!piece) NSLog(@"Invalid format of auth key file!");

    return piece;
}


@end
