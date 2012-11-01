//
//  AVAppleEncoder.h
//  RosyWriter
//
//  Created by Christopher Ballinger on 10/29/12.
//
//

#import "AVEncoder.h"
#import <AVFoundation/AVFoundation.h>

@interface AVAppleEncoder : NSObject {
    unsigned long long fileOffset;
    __block dispatch_source_t source;
    int fileNumber;
    
    CMFormatDescriptionRef videoFormatDescription;
    CMFormatDescriptionRef audioFormatDescription;
}

@property (nonatomic, retain) NSURL *movieURL;

@property (nonatomic, retain) AVAssetWriterInput *audioEncoder;
@property (nonatomic, retain) AVAssetWriterInput *videoEncoder;
@property (nonatomic, retain) AVAssetWriter *assetWriter;

@property (nonatomic) BOOL readyToRecordAudio;
@property (nonatomic) BOOL readyToRecordVideo;
@property (nonatomic) AVCaptureVideoOrientation referenceOrientation;
@property (nonatomic) AVCaptureVideoOrientation videoOrientation;

- (id) initWithURL:(NSURL*)url;
- (id) initWithURL:(NSURL *)url movieFragmentInterval:(CMTime)fragmentInterval;
- (void) writeSampleBuffer:(CMSampleBufferRef)sampleBuffer ofType:(NSString *)mediaType;
- (void) setupAudioEncoderWithFormatDescription:(CMFormatDescriptionRef)formatDescription;
- (void) setupAudioEncoderWithFormatDescription:(CMFormatDescriptionRef)formatDescription bitsPerSecond:(int)bps;
- (void) setupVideoEncoderWithFormatDescription:(CMFormatDescriptionRef)formatDescription;
- (void) setupVideoEncoderWithFormatDescription:(CMFormatDescriptionRef)formatDescription bitsPerSecond:(int)bps;

- (void) setupVideoEncoder:(AVAssetWriterInput**)currentVideoEncoder assetWriter:(AVAssetWriter**)currentAssetWriter withFormatDescription:(CMFormatDescriptionRef)formatDescription bitsPerSecond:(int)bps;
- (void) setupAudioEncoder:(AVAssetWriterInput**)currentAudioEncoder assetWriter:(AVAssetWriter**)currentAssetWriter withFormatDescription:(CMFormatDescriptionRef)formatDescription bitsPerSecond:(int)bps;

@property (nonatomic) BOOL watchOutputFile;

- (void) finishEncoding;

@end
