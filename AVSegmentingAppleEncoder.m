//
//  AVSegmentingAppleEncoder.m
//  RosyWriter
//
//  Created by Christopher Ballinger on 11/1/12.
//
//

#import "AVSegmentingAppleEncoder.h"
#import <MobileCoreServices/MobileCoreServices.h>

@implementation AVSegmentingAppleEncoder
@synthesize segmentationTimer, queuedAssetWriter;
@synthesize queuedAudioEncoder, queuedVideoEncoder;

- (void) dealloc {
    if (self.segmentationTimer) {
        [self.segmentationTimer invalidate];
        self.segmentationTimer = nil;
    }
}

- (void) finishEncoding {
    if (self.segmentationTimer) {
        [self.segmentationTimer invalidate];
        self.segmentationTimer = nil;
    }
    [super finishEncoding];
}

- (id) initWithURL:(NSURL *)url segmentationInterval:(NSTimeInterval)timeInterval {
    if (self = [super init]) {
        self.segmentationTimer = [NSTimer timerWithTimeInterval:timeInterval target:self selector:@selector(segmentRecording:) userInfo:nil repeats:YES];
        [[NSRunLoop mainRunLoop] addTimer:segmentationTimer forMode:NSDefaultRunLoopMode];
    }
    return self;
}

- (NSURL*) newMovieURL {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    NSString *movieName = [NSString stringWithFormat:@"%d.%f.mp4", fileNumber, [[NSDate date] timeIntervalSince1970]];
    NSURL *newMovieURL = [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@/%@", basePath, movieName]];
    fileNumber++;
    return newMovieURL;
}

- (void) segmentRecording:(NSTimer*)timer {
    AVAssetWriter *tempAssetWriter = self.assetWriter;
    AVAssetWriterInput *tempAudioEncoder = self.audioEncoder;
    AVAssetWriterInput *tempVideoEncoder = self.videoEncoder;
    self.assetWriter = queuedAssetWriter;
    self.audioEncoder = queuedAudioEncoder;
    self.videoEncoder = queuedVideoEncoder;
    //NSLog(@"Switching encoders");
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        [tempAudioEncoder markAsFinished];
        [tempVideoEncoder markAsFinished];
        if (tempAssetWriter.status == AVAssetWriterStatusWriting) {
            if(![tempAssetWriter finishWriting]) {
                [self showError:[tempAssetWriter error]];
            }
        }
        if (self.readyToRecordAudio && self.readyToRecordVideo) {
            NSError *error = nil;
            self.queuedAssetWriter = [[AVAssetWriter alloc] initWithURL:[self newMovieURL] fileType:(NSString *)kUTTypeMPEG4 error:&error];
            if (error) {
                [self showError:error];
            }
            self.queuedVideoEncoder = [self setupVideoEncoderWithAssetWriter:self.queuedAssetWriter formatDescription:videoFormatDescription bitsPerSecond:videoBPS];
            self.queuedAudioEncoder = [self setupAudioEncoderWithAssetWriter:self.queuedAssetWriter formatDescription:audioFormatDescription bitsPerSecond:audioBPS];
            //NSLog(@"Encoder switch finished");

        }
    });
}

- (void) setupVideoEncoderWithFormatDescription:(CMFormatDescriptionRef)formatDescription bitsPerSecond:(int)bps {
    videoFormatDescription = formatDescription;
    videoBPS = bps;
    if (!self.assetWriter) {
        NSError *error = nil;
        self.assetWriter = [[AVAssetWriter alloc] initWithURL:[self newMovieURL] fileType:(NSString *)kUTTypeMPEG4 error:&error];
        if (error) {
            [self showError:error];
        }
    }
    self.videoEncoder = [self setupVideoEncoderWithAssetWriter:self.assetWriter formatDescription:formatDescription bitsPerSecond:bps];
    
    if (!queuedAssetWriter) {
        NSError *error = nil;
        self.queuedAssetWriter = [[AVAssetWriter alloc] initWithURL:[self newMovieURL] fileType:(NSString *)kUTTypeMPEG4 error:&error];
        if (error) {
            [self showError:error];
        }
    }
    self.queuedVideoEncoder = [self setupVideoEncoderWithAssetWriter:self.queuedAssetWriter formatDescription:formatDescription bitsPerSecond:bps];
    self.readyToRecordVideo = YES;
}

- (void) setupAudioEncoderWithFormatDescription:(CMFormatDescriptionRef)formatDescription bitsPerSecond:(int)bps {
    audioFormatDescription = formatDescription;
    audioBPS = bps;
    if (!self.assetWriter) {
        NSError *error = nil;
        self.assetWriter = [[AVAssetWriter alloc] initWithURL:[self newMovieURL] fileType:(NSString *)kUTTypeMPEG4 error:&error];
        if (error) {
            [self showError:error];
        }
    }
    self.audioEncoder = [self setupAudioEncoderWithAssetWriter:self.assetWriter formatDescription:formatDescription bitsPerSecond:bps];
    
    if (!queuedAssetWriter) {
        NSError *error = nil;
        self.queuedAssetWriter = [[AVAssetWriter alloc] initWithURL:[self newMovieURL] fileType:(NSString *)kUTTypeMPEG4 error:&error];
        if (error) {
            [self showError:error];
        }
    }
    self.queuedAudioEncoder = [self setupAudioEncoderWithAssetWriter:self.queuedAssetWriter formatDescription:formatDescription bitsPerSecond:bps];
    self.readyToRecordAudio = YES;
}



@end
