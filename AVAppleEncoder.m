//
//  AVAppleEncoder.m
//  RosyWriter
//
//  Created by Christopher Ballinger on 10/29/12.
//
//

#import "AVAppleEncoder.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CMBufferQueue.h>
#import <MobileCoreServices/MobileCoreServices.h>


@implementation AVAppleEncoder
@synthesize assetWriter, audioEncoder, videoEncoder, movieURL, readyToRecordAudio, readyToRecordVideo, referenceOrientation, videoOrientation;


- (id) initWithURL:(NSURL *)url {
    if (self = [super init]) {
        self.movieURL = url;
        NSError *error = nil;
        self.assetWriter = [[AVAssetWriter alloc] initWithURL:movieURL fileType:(NSString *)kUTTypeMPEG4 error:&error];
        if (error) {
            [self showError:error];
        }
        referenceOrientation = UIDeviceOrientationPortrait;
    }
    return self;
}

- (void) setupVideoEncoderWithFormatDescription:(CMFormatDescriptionRef)formatDescription;
{
	float bitsPerPixel;
	CMVideoDimensions dimensions = CMVideoFormatDescriptionGetDimensions(formatDescription);
    CGFloat width = dimensions.width;
    CGFloat height = dimensions.height;
	int numPixels = width * height;
	int bitsPerSecond;
	
	// Assume that lower-than-SD resolutions are intended for streaming, and use a lower bitrate
	if ( numPixels < (640 * 480) )
		bitsPerPixel = 4.05; // This bitrate matches the quality produced by AVCaptureSessionPresetMedium or Low.
	else
		bitsPerPixel = 11.4; // This bitrate matches the quality produced by AVCaptureSessionPresetHigh.
	
	bitsPerSecond = numPixels * bitsPerPixel;
	
	NSDictionary *videoCompressionSettings = [NSDictionary dictionaryWithObjectsAndKeys:
											  AVVideoCodecH264, AVVideoCodecKey,
											  [NSNumber numberWithInteger:width], AVVideoWidthKey,
											  [NSNumber numberWithInteger:height], AVVideoHeightKey,
											  [NSDictionary dictionaryWithObjectsAndKeys:
											   [NSNumber numberWithInteger:bitsPerSecond], AVVideoAverageBitRateKey,
											   [NSNumber numberWithInteger:30], AVVideoMaxKeyFrameIntervalKey,
											   nil], AVVideoCompressionPropertiesKey,
											  nil];
	if ([assetWriter canApplyOutputSettings:videoCompressionSettings forMediaType:AVMediaTypeVideo]) {
		videoEncoder = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeVideo outputSettings:videoCompressionSettings];
		videoEncoder.expectsMediaDataInRealTime = YES;
		videoEncoder.transform = [self transformFromCurrentVideoOrientationToOrientation:self.referenceOrientation];
		if ([assetWriter canAddInput:videoEncoder])
			[assetWriter addInput:videoEncoder];
		else {
			NSLog(@"Couldn't add asset writer video input.");
		}
	}
	else {
		NSLog(@"Couldn't apply video output settings.");
	}
    self.readyToRecordVideo = YES;
}

- (CGFloat)angleOffsetFromPortraitOrientationToOrientation:(AVCaptureVideoOrientation)orientation
{
	CGFloat angle = 0.0;
	
	switch (orientation) {
		case AVCaptureVideoOrientationPortrait:
			angle = 0.0;
			break;
		case AVCaptureVideoOrientationPortraitUpsideDown:
			angle = M_PI;
			break;
		case AVCaptureVideoOrientationLandscapeRight:
			angle = -M_PI_2;
			break;
		case AVCaptureVideoOrientationLandscapeLeft:
			angle = M_PI_2;
			break;
		default:
			break;
	}
    
	return angle;
}

- (CGAffineTransform)transformFromCurrentVideoOrientationToOrientation:(AVCaptureVideoOrientation)orientation
{
	CGAffineTransform transform = CGAffineTransformIdentity;
    
	// Calculate offsets from an arbitrary reference orientation (portrait)
	CGFloat orientationAngleOffset = [self angleOffsetFromPortraitOrientationToOrientation:orientation];
	CGFloat videoOrientationAngleOffset = [self angleOffsetFromPortraitOrientationToOrientation:self.videoOrientation];
	
	// Find the difference in angle between the passed in orientation and the current video orientation
	CGFloat angleOffset = orientationAngleOffset - videoOrientationAngleOffset;
	transform = CGAffineTransformMakeRotation(angleOffset);
	
	return transform;
}

- (void) setupAudioEncoderWithFormatDescription:(CMFormatDescriptionRef)formatDescription;
{
	const AudioStreamBasicDescription *currentASBD = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription);
    
	size_t aclSize = 0;
	const AudioChannelLayout *currentChannelLayout = CMAudioFormatDescriptionGetChannelLayout(formatDescription, &aclSize);
	NSData *currentChannelLayoutData = nil;
	
	// AVChannelLayoutKey must be specified, but if we don't know any better give an empty data and let AVAssetWriter decide.
	if ( currentChannelLayout && aclSize > 0 )
		currentChannelLayoutData = [NSData dataWithBytes:currentChannelLayout length:aclSize];
	else
		currentChannelLayoutData = [NSData data];
	
	NSDictionary *audioCompressionSettings = [NSDictionary dictionaryWithObjectsAndKeys:
											  [NSNumber numberWithInteger:kAudioFormatMPEG4AAC], AVFormatIDKey,
											  [NSNumber numberWithFloat:currentASBD->mSampleRate], AVSampleRateKey,
											  [NSNumber numberWithInt:64000], AVEncoderBitRatePerChannelKey,
											  [NSNumber numberWithInteger:currentASBD->mChannelsPerFrame], AVNumberOfChannelsKey,
											  currentChannelLayoutData, AVChannelLayoutKey,
											  nil];
	if ([assetWriter canApplyOutputSettings:audioCompressionSettings forMediaType:AVMediaTypeAudio]) {
		audioEncoder = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeAudio outputSettings:audioCompressionSettings];
		audioEncoder.expectsMediaDataInRealTime = YES;
		if ([assetWriter canAddInput:audioEncoder])
			[assetWriter addInput:audioEncoder];
		else {
			NSLog(@"Couldn't add asset writer audio input.");
		}
	}
	else {
		NSLog(@"Couldn't apply audio output settings.");
	}
    self.readyToRecordAudio = YES;
}

- (void) writeSampleBuffer:(CMSampleBufferRef)sampleBuffer ofType:(NSString *)mediaType
{
	if ( assetWriter.status == AVAssetWriterStatusUnknown ) {
		
        if ([assetWriter startWriting]) {
			[assetWriter startSessionAtSourceTime:CMSampleBufferGetPresentationTimeStamp(sampleBuffer)];
		}
		else {
			[self showError:[assetWriter error]];
		}
	}
	
	if ( assetWriter.status == AVAssetWriterStatusWriting ) {
		
		if (mediaType == AVMediaTypeVideo) {
			if (videoEncoder.readyForMoreMediaData) {
				if (![videoEncoder appendSampleBuffer:sampleBuffer]) {
					[self showError:[assetWriter error]];
				}
			}
		}
		else if (mediaType == AVMediaTypeAudio) {
			if (audioEncoder.readyForMoreMediaData) {
				if (![audioEncoder appendSampleBuffer:sampleBuffer]) {
					[self showError:[assetWriter error]];
				}
			}
		}
	}
}

- (void) finishEncoding {
    self.readyToRecordAudio = NO;
    self.readyToRecordVideo = NO;
    [self.audioEncoder markAsFinished];
    [self.videoEncoder markAsFinished];
    if (![assetWriter finishWriting]) {
        [self showError:[assetWriter error]];
    }
}

- (void) showError:(NSError*)error {
    NSLog(@"Error: %@%@", [error localizedDescription], [error userInfo]);
}

@end
