//
//  TOROnionAuth.m
//  Tor
//
//  Created by Benjamin Erhart on 29.09.21.
//

#import "TOROnionAuth.h"

@implementation TOROnionAuth

- (instancetype)initWithPrivateDirUrl:(nullable NSURL *)privateUrl andPublicDirUrl:(nullable NSURL *)publicUrl
{
    if ((self = [super init]))
    {
        if (![publicUrl.lastPathComponent isEqualToString:@"authorized_clients"])
        {
            publicUrl = [publicUrl URLByAppendingPathComponent:@"authorized_clients" isDirectory:YES];
        }

        _privateUrl = privateUrl;
        _publicUrl = publicUrl;
        _keys = [NSMutableArray new];

        NSMutableArray<NSURL *> *files = [NSMutableArray new];
        NSError *error;

        NSURL *privateUrl = _privateUrl;
        if (privateUrl) {
            NSArray<NSURL *> *privateFiles = [NSFileManager.defaultManager
                                              contentsOfDirectoryAtURL:privateUrl
                                              includingPropertiesForKeys:nil options:0
                                              error:&error];

            if (error)
            {
                NSLog(@"[%@] Error while reading keys: %@", NSStringFromClass(self.class), error.localizedDescription);
            }
            else {
                if (privateFiles) [files addObjectsFromArray:privateFiles];
            }
        }

        NSURL *publicUrl = _publicUrl;
        if (publicUrl) {
            NSArray<NSURL *> *publicFiles = [NSFileManager.defaultManager
                                              contentsOfDirectoryAtURL:publicUrl
                                              includingPropertiesForKeys:nil options:0
                                              error:&error];

            if (error)
            {
                NSLog(@"[%@] Error while reading keys: %@", NSStringFromClass(self.class), error.localizedDescription);
            }
            else {
                if (publicFiles) [files addObjectsFromArray:publicFiles];
            }
        }

        for (NSURL *file in files)
        {
            if ([TORAuthKey isAuthFile:file])
            {
                TORAuthKey *key = [[TORAuthKey alloc] initFromUrl:file];

                if (key) [((NSMutableArray *)_keys) addObject:key];
            }
        }
    }

    return self;
}

- (instancetype)initWithPrivateDir:(NSString *)privatePath andPublicDir:(NSString *)publicPath
{
    return [self initWithPrivateDirUrl:[NSURL fileURLWithPath:privatePath] andPublicDirUrl:[NSURL fileURLWithPath:publicPath]];
}


// MARK: Public Methods

- (BOOL)set:(TORAuthKey *)key
{
    NSURL *privateUrl = _privateUrl;
    NSURL *publicUrl = _publicUrl;

    if (key.isPrivate) {
        if (privateUrl) {
            [key setDirectory:privateUrl];
        }
        else if (publicUrl) {
            [key setDirectory:publicUrl];
        }
    }
    else {
        if (publicUrl) {
            [key setDirectory:publicUrl];
        }
        else if (privateUrl) {
            [key setDirectory:privateUrl];
        }
    }

    if ([key persist])
    {
        NSUInteger i = [_keys indexOfObject:key];

        if (i == NSNotFound)
        {
            [((NSMutableArray *)_keys) addObject:key];
        }
        else {
            ((NSMutableArray *)_keys)[i] = key;
        }

        return YES;
    }

    return NO;
}

- (BOOL)removeKeyAtIndex:(NSInteger)idx
{
    if (idx < 0 || (NSUInteger)idx >= _keys.count) return NO;

    TORAuthKey *key = _keys[idx];

    NSError *error;
    [NSFileManager.defaultManager removeItemAtURL:key.file error:&error];

    if (error)
    {
        NSLog(@"[%@] Error while removing key: %@", NSStringFromClass(self.class), error.localizedDescription);

        return NO;
    }

    [((NSMutableArray *)_keys) removeObjectAtIndex:idx];

    return YES;
}


@end
