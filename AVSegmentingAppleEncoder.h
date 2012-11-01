//
//  AVSegmentingAppleEncoder.h
//  RosyWriter
//
//  Created by Christopher Ballinger on 11/1/12.
//
//

#import "AVAppleEncoder.h"

@interface AVSegmentingAppleEncoder : AVAppleEncoder

@property (nonatomic, retain) AVAssetWriter *assetWriter1;
@property (nonatomic, retain) AVAssetWriterInput *audioEncoder1;
@property (nonatomic, retain) AVAssetWriterInput *videoEncoder1;
@property (nonatomic, retain) AVAssetWriter *assetWriter2;
@property (nonatomic, retain) AVAssetWriterInput *audioEncoder2;
@property (nonatomic, retain) AVAssetWriterInput *videoEncoder2;

@property (nonatomic, retain) NSTimer *segmentationTimer;

- (id) initWithURL:(NSURL *)url segmentationInterval:(NSTimeInterval)timeInterval;

@end
