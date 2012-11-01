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
}

- (id) initWithURL:(NSURL *)url segmentationInterval:(NSTimeInterval)timeInterval {
    if (self = [super initWithURL:url]) {
        self.segmentationTimer = [NSTimer scheduledTimerWithTimeInterval:timeInterval target:self selector:@selector(segmentRecording:) userInfo:nil repeats:YES];
    }
    return self;
}

- (void) segmentRecording:(NSTimer*)timer {
    
}


@end
