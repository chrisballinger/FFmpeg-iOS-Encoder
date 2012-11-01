//
//  AVSegmentingAppleEncoder.m
//  RosyWriter
//
//  Created by Christopher Ballinger on 11/1/12.
//
//

#import "AVSegmentingAppleEncoder.h"

@implementation AVSegmentingAppleEncoder
@synthesize segmentationTimer, assetWriter1, assetWriter2;
@synthesize videoEncoder1, videoEncoder2, audioEncoder1, audioEncoder2;

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
    if (self = [super initWithURL:url]) {
        self.segmentationTimer = [NSTimer scheduledTimerWithTimeInterval:timeInterval target:self selector:@selector(segmentRecording:) userInfo:nil repeats:YES];
    }
    return self;
}

- (void) segmentRecording:(NSTimer*)timer {
    
}

- (void) setupVideoEncoderWithFormatDescription:(CMFormatDescriptionRef)formatDescription bitsPerSecond:(int)bps {
    videoFormatDescription = formatDescription;
    self.videoEncoder = [self setupVideoEncoderWithAssetWriter:self.assetWriter formatDescription:formatDescription bitsPerSecond:bps];
    self.readyToRecordVideo = YES;
}

- (void) setupAudioEncoderWithFormatDescription:(CMFormatDescriptionRef)formatDescription bitsPerSecond:(int)bps {
    audioFormatDescription = formatDescription;
    self.audioEncoder = [self setupAudioEncoderWithAssetWriter:self.assetWriter formatDescription:formatDescription bitsPerSecond:bps];
    self.readyToRecordAudio = YES;
}



@end
