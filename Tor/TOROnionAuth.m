//
//  TOROnionAuth.m
//  Tor
//
//  Created by Benjamin Erhart on 29.09.21.
//

#import "TOROnionAuth.h"

@implementation TOROnionAuth

- (instancetype)initWithDirUrl:(NSURL *)url
{
    if ((self = [super init]))
    {
        _directory = url;
        _keys = [NSMutableArray new];

        NSError *error;
        NSArray<NSURL *> *files = [NSFileManager.defaultManager
                                   contentsOfDirectoryAtURL:url
                                   includingPropertiesForKeys:nil options:0
                                   error:&error];

        if (error)
        {
            NSLog(@"[%@] Error while reading keys: %@", NSStringFromClass(self.class), error.localizedDescription);
        }
        else {
            for (NSURL *file in files)
            {
                if ([TORAuthKey isAuthFile:file])
                {
                    TORAuthKey *key = [[TORAuthKey alloc] initFromUrl:file];

                    if (key) [((NSMutableArray *)_keys) addObject:key];
                }
            }
        }
    }

    return self;
}

- (instancetype)initWithDir:(NSString *)path
{
    return [self initWithDirUrl:[NSURL fileURLWithPath:path]];
}


// MARK: Public Methods

- (void)set:(TORAuthKey *)key
{
    [key setDirectory:_directory];

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
    }
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
