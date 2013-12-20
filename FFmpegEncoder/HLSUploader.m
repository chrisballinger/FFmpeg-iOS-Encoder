//
//  HLSUploader.m
//  FFmpegEncoder
//
//  Created by Christopher Ballinger on 12/20/13.
//  Copyright (c) 2013 Christopher Ballinger. All rights reserved.
//

#import "HLSUploader.h"
#import "OWSharedS3Client.h"

#define BUCKET_NAME @"openwatch-livestreamer"

@interface HLSUploader()
@end

@implementation HLSUploader

- (id) initWithDirectoryPath:(NSString *)directoryPath remoteFolderName:(NSString *)remoteFolderName {
    if (self = [super init]) {
        _directoryPath = [directoryPath copy];
        _directoryWatcher = [DirectoryWatcher watchFolderWithPath:_directoryPath delegate:self];
        _files = [NSMutableDictionary dictionary];
        _uploadQueue = [NSMutableArray array];
        _remoteFolderName = [remoteFolderName copy];
        _scanningQueue = dispatch_queue_create("Scanning Queue", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void) uploadFilesFromQueue {
    while (_uploadQueue.count > 0) {
        NSString *fileName = [_uploadQueue objectAtIndex:0];
        [_uploadQueue removeObjectAtIndex:0];
        [_files setObject:@"uploading" forKey:fileName];
        NSString *filePath = [_directoryPath stringByAppendingPathComponent:fileName];
        NSString *key = [NSString stringWithFormat:@"%@/%@", _remoteFolderName, fileName];
        [[OWSharedS3Client sharedClient] postObjectWithFile:filePath bucket:BUCKET_NAME key:key acl:@"public-read" success:^(S3PutObjectResponse *responseObject) {
            NSLog(@"Uploaded %@", fileName);
            NSError *error = nil;
            [[NSFileManager defaultManager] removeItemAtPath:filePath error:&error];
            if (error) {
                NSLog(@"Error removing uploaded file: %@", error.description);
            }
            [_files removeObjectForKey:fileName];
            [self updateManifest];
        } failure:^(NSError *error) {
            NSLog(@"Failed to upload %@: %@", fileName, error.description);
        }];
    }
}

- (void) updateManifest {
    NSString *key = [NSString stringWithFormat:@"%@/%@", _remoteFolderName, [_manifestPath lastPathComponent]];
    [[OWSharedS3Client sharedClient] postObjectWithFile:_manifestPath bucket:BUCKET_NAME key:key acl:@"public-read" success:^(S3PutObjectResponse *responseObject) {
        NSLog(@"Manifest updated");
    } failure:^(NSError *error) {
        NSLog(@"Error updating manifest: %@", error.description);
    }];
}

- (void) directoryDidChange:(DirectoryWatcher *)folderWatcher {
    dispatch_async(_scanningQueue, ^{
        NSError *error = nil;
        NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:_directoryPath error:&error];
        NSLog(@"Directory changed, fileCount: %d", files.count);
        if (error) {
            NSLog(@"Error listing directory contents");
        }
        for (NSString *fileName in files) {
            if ([fileName rangeOfString:@"m3u8"].location == NSNotFound) {
                NSString *uploadState = [_files objectForKey:fileName];
                if (!uploadState) {
                    [self uploadFilesFromQueue];
                    NSLog(@"new file detected: %@", fileName);
                    [_files setObject:@"queued" forKey:fileName];
                    [_uploadQueue insertObject:fileName atIndex:0];
                }
            } else if (!_manifestPath) {
                _manifestPath = [_directoryPath stringByAppendingPathComponent:fileName];
            }
        }
    });
}

- (NSURL*) manifestURL {
    NSString *urlString = [NSString stringWithFormat:@"http://%@.s3.amazonaws.com/%@/%@", BUCKET_NAME, _remoteFolderName, [_manifestPath lastPathComponent]];
    return [NSURL URLWithString:urlString];
}

@end
