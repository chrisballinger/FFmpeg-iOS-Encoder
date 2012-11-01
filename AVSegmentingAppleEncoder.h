//
//  AVSegmentingAppleEncoder.h
//  RosyWriter
//
//  Created by Christopher Ballinger on 11/1/12.
//
//

#import "AVAppleEncoder.h"

@interface AVSegmentingAppleEncoder : AVAppleEncoder {
    int videoBPS;
    int audioBPS;
}

@property (nonatomic, retain) AVAssetWriter *queuedAssetWriter;
@property (nonatomic, retain) AVAssetWriterInput *queuedAudioEncoder;
@property (nonatomic, retain) AVAssetWriterInput *queuedVideoEncoder;

@property (nonatomic, retain) NSTimer *segmentationTimer;

- (id) initWithURL:(NSURL *)url segmentationInterval:(NSTimeInterval)timeInterval;

@end
