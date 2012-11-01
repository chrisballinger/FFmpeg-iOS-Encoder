/*
     File: RosyWriterVideoProcessor.m
 Abstract: The class that creates and manages the AV capture session and asset writer
  Version: 1.2
 
 Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple
 Inc. ("Apple") in consideration of your agreement to the following
 terms, and your use, installation, modification or redistribution of
 this Apple software constitutes acceptance of these terms.  If you do
 not agree with these terms, please do not use, install, modify or
 redistribute this Apple software.
 
 In consideration of your agreement to abide by the following terms, and
 subject to these terms, Apple grants you a personal, non-exclusive
 license, under Apple's copyrights in this original Apple software (the
 "Apple Software"), to use, reproduce, modify and redistribute the Apple
 Software, with or without modifications, in source and/or binary forms;
 provided that if you redistribute the Apple Software in its entirety and
 without modifications, you must retain this notice and the following
 text and disclaimers in all such redistributions of the Apple Software.
 Neither the name, trademarks, service marks or logos of Apple Inc. may
 be used to endorse or promote products derived from the Apple Software
 without specific prior written permission from Apple.  Except as
 expressly stated in this notice, no other rights or licenses, express or
 implied, are granted by Apple herein, including but not limited to any
 patent rights that may be infringed by your derivative works or by other
 works in which the Apple Software may be incorporated.
 
 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
 MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
 THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
 FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
 OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.
 
 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
 OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
 MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
 AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
 STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.
 
 Copyright (C) 2011 Apple Inc. All Rights Reserved.
 
 */

#import <MobileCoreServices/MobileCoreServices.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import "RosyWriterVideoProcessor.h"



#define INBUF_SIZE 4096
#define AUDIO_INBUF_SIZE 20480
#define AUDIO_REFILL_THRESH 4096

#define BYTES_PER_PIXEL 3

@interface RosyWriterVideoProcessor ()

// Redeclared as readwrite so that we can write to the property and still be atomic with external readers.
@property (readwrite) Float64 videoFrameRate;
@property (readwrite) CMVideoDimensions videoDimensions;
@property (readwrite) CMVideoCodecType videoType;

@property (readwrite, getter=isRecording) BOOL recording;

@end

@implementation RosyWriterVideoProcessor

@synthesize delegate;
@synthesize videoFrameRate, videoDimensions, videoType;
@synthesize videoOrientation;
@synthesize recording;
@synthesize movieURL;
@synthesize segmentationTimer;
@synthesize movieURLs;
@synthesize ffEncoder;
@synthesize appleEncoder1, appleEncoder2;

- (id) init
{
    if (self = [super init]) {
        previousSecondTimestamps = [[NSMutableArray alloc] init];
        self.movieURL = [self newMovieURL];
        self.movieURLs = [NSMutableArray array];
        [movieURLs addObject:movieURL];
        self.ffEncoder = [[FFEncoder alloc] init];
    }
    return self;
}


- (NSURL*) newMovieURL {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    NSString *movieName = [NSString stringWithFormat:@"%f.mp4",[[NSDate date] timeIntervalSince1970]];
    NSURL *newMovieURL = [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@/%@", basePath, movieName]];
    return newMovieURL;
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

#pragma mark Utilities

- (void) calculateFramerateAtTimestamp:(CMTime) timestamp
{
	[previousSecondTimestamps addObject:[NSValue valueWithCMTime:timestamp]];
    
	CMTime oneSecond = CMTimeMake( 1, 1 );
	CMTime oneSecondAgo = CMTimeSubtract( timestamp, oneSecond );
    
	while( CMTIME_COMPARE_INLINE( [[previousSecondTimestamps objectAtIndex:0] CMTimeValue], <, oneSecondAgo ) )
		[previousSecondTimestamps removeObjectAtIndex:0];
    
	Float64 newRate = (Float64) [previousSecondTimestamps count];
	self.videoFrameRate = (self.videoFrameRate + newRate) / 2;
}

- (void)removeFile:(NSURL *)fileURL
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *filePath = [fileURL path];
    if ([fileManager fileExistsAtPath:filePath]) {
        NSError *error;
        BOOL success = [fileManager removeItemAtPath:filePath error:&error];
		if (!success)
			[self showError:error];
    }
}



#pragma mark Recording







- (void) startRecording
{
	dispatch_async(movieWritingQueue, ^{
	
		if ( recordingWillBeStarted || self.recording )
			return;

		recordingWillBeStarted = YES;

		// recordingDidStart is called from captureOutput:didOutputSampleBuffer:fromConnection: once the asset writer is setup
		[self.delegate recordingWillStart];
			
        [self initializeAssetWriters];
	});


}

- (void) initializeAssetWriters {
    // Create an asset writer
    self.appleEncoder1 = [[AVAppleEncoder alloc] initWithURL:[self newMovieURL]];
    self.appleEncoder2 = [[AVSegmentingAppleEncoder alloc] initWithURL:[self newMovieURL] segmentationInterval:5.0f];
}

- (void) stopRecording
{
    /*
    dispatch_async(ffmpegWritingQueue, ^{
        [self.ffEncoder.videoEncoder finishEncoding];
        [self.ffEncoder.audioEncoder finishEncoding];
    });
     */
	dispatch_async(movieWritingQueue, ^{
		if ( recordingWillBeStopped || self.recording == NO)
			return;
		
		recordingWillBeStopped = YES;
		
		// recordingDidStop is called from saveMovieToCameraRoll
		[self.delegate recordingWillStop];
        [appleEncoder1 finishEncoding];
        [appleEncoder2 finishEncoding];
        recordingWillBeStopped = NO;
        self.recording = NO;
        [self.delegate recordingDidStop];
        [self clearMovieURLs];
        self.movieURL = [self newMovieURL];
        [self initializeAssetWriters];
	});
    [self.segmentationTimer invalidate];
    self.segmentationTimer = nil;
}

- (void) clearMovieURLs {
    // TODO: write out movie file names to file
    self.movieURLs = [NSMutableArray array];
}

#pragma mark Processing

- (void)processPixelBuffer: (CVImageBufferRef)pixelBuffer
{
	CVPixelBufferLockBaseAddress( pixelBuffer, 0 );
	
	int bufferWidth = CVPixelBufferGetWidth(pixelBuffer);
	int bufferHeight = CVPixelBufferGetHeight(pixelBuffer);
	unsigned char *pixel = (unsigned char *)CVPixelBufferGetBaseAddress(pixelBuffer);

	for( int row = 0; row < bufferHeight; row++ ) {		
		for( int column = 0; column < bufferWidth; column++ ) {
			pixel[1] = 0; // De-green (second pixel in BGRA is green)
			pixel += BYTES_PER_PIXEL;
		}
	}
	
	CVPixelBufferUnlockBaseAddress( pixelBuffer, 0 );
}

#pragma mark Capture

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection 
{	
	CMFormatDescriptionRef formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer);
    
	if ( connection == videoConnection ) {
		
		// Get framerate
		CMTime timestamp = CMSampleBufferGetPresentationTimeStamp( sampleBuffer );
		[self calculateFramerateAtTimestamp:timestamp];
        
		// Get frame dimensions (for onscreen display)
		if (self.videoDimensions.width == 0 && self.videoDimensions.height == 0)
			self.videoDimensions = CMVideoFormatDescriptionGetDimensions( formatDescription );
		
		// Get buffer type
		if ( self.videoType == 0 )
			self.videoType = CMFormatDescriptionGetMediaSubType( formatDescription );

		//CVImageBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
		
		// Synchronously process the pixel buffer to de-green it.
		//[self processPixelBuffer:pixelBuffer];
		
		// Enqueue it for preview.  This is a shallow queue, so if image processing is taking too long,
		// we'll drop this frame for preview (this keeps preview latency low).
		OSStatus err = CMBufferQueueEnqueue(previewBufferQueue, sampleBuffer);
		if ( !err ) {        
			dispatch_async(dispatch_get_main_queue(), ^{
				CMSampleBufferRef sbuf = (CMSampleBufferRef)CMBufferQueueDequeueAndRetain(previewBufferQueue);
				if (sbuf) {
					CVImageBufferRef pixBuf = CMSampleBufferGetImageBuffer(sbuf);
					[self.delegate pixelBufferReadyForDisplay:pixBuf];
					CFRelease(sbuf);
				}
			});
		}
	}
    //
    CFRetain(sampleBuffer);
    //CFRetain(sampleBuffer);
	CFRetain(formatDescription);
    //CFRetain(formatDescription);
    /*
    dispatch_async(ffmpegWritingQueue, ^{
        if (self.recording || recordingWillBeStarted) {
            if (connection == videoConnection) {
                // Write video data to file
				if (!self.ffEncoder.videoEncoder.readyToEncode) {
					[self.ffEncoder.videoEncoder setupEncoderWithFormatDescription:formatDescription];
                }
                OSStatus err = CMBufferQueueEnqueue(ffmpegBufferQueue, sampleBuffer);
                if ( !err ) {
                    CMSampleBufferRef sbuf = (CMSampleBufferRef)CMBufferQueueDequeueAndRetain(ffmpegBufferQueue);
                    if (sbuf) {
                        [self.ffEncoder.videoEncoder encodeSampleBuffer:sbuf];
                        CFRelease(sbuf);
                    }
                }
            }
            else if (connection == audioConnection) {
                if (!self.ffEncoder.audioEncoder.readyToEncode) {
					[self.ffEncoder.audioEncoder setupEncoderWithFormatDescription:formatDescription];
                }
                [self.ffEncoder.audioEncoder encodeSampleBuffer:sampleBuffer];
            }
        }
        CFRelease(sampleBuffer);
        CFRelease(formatDescription);
    });
     */
    
	dispatch_async(movieWritingQueue, ^{
		if ( appleEncoder1 && (self.recording || recordingWillBeStarted)) {
		
			BOOL wasReadyToRecord = (appleEncoder1.readyToRecordAudio && appleEncoder1.readyToRecordVideo);
			
			if (connection == videoConnection) {
				
				// Initialize the video input if this is not done yet
				if (!appleEncoder1.readyToRecordVideo) {
					[appleEncoder1 setupVideoEncoderWithFormatDescription:formatDescription];
                }
				
				// Write video data to file
				if (appleEncoder1.readyToRecordVideo && appleEncoder1.readyToRecordAudio) {
					[appleEncoder1 writeSampleBuffer:sampleBuffer ofType:AVMediaTypeVideo];
                }
			}
			else if (connection == audioConnection) {
				
				// Initialize the audio input if this is not done yet
				if (!appleEncoder1.readyToRecordAudio) {
                    [appleEncoder1 setupAudioEncoderWithFormatDescription:formatDescription];
                }
				
				// Write audio data to file
				if (appleEncoder1.readyToRecordAudio && appleEncoder1.readyToRecordVideo)
					[appleEncoder1 writeSampleBuffer:sampleBuffer ofType:AVMediaTypeAudio];
			}
			
			BOOL isReadyToRecord = (appleEncoder1.readyToRecordAudio && appleEncoder1.readyToRecordVideo);
			if ( !wasReadyToRecord && isReadyToRecord ) {
				recordingWillBeStarted = NO;
				self.recording = YES;
				[self.delegate recordingDidStart];
			}
		}
        if ( appleEncoder2 && (self.recording || recordingWillBeStarted)) {
            
			BOOL wasReadyToRecord = (appleEncoder2.readyToRecordAudio && appleEncoder2.readyToRecordVideo);
			
			if (connection == videoConnection) {
				
				// Initialize the video input if this is not done yet
				if (!appleEncoder2.readyToRecordVideo) {
					[appleEncoder2 setupVideoEncoderWithFormatDescription:formatDescription bitsPerSecond:800000];
                }
				
				// Write video data to file
				if (appleEncoder2.readyToRecordVideo && appleEncoder2.readyToRecordAudio) {
					[appleEncoder2 writeSampleBuffer:sampleBuffer ofType:AVMediaTypeVideo];
                }
			}
			else if (connection == audioConnection) {
				
				// Initialize the audio input if this is not done yet
				if (!appleEncoder2.readyToRecordAudio) {
                    [appleEncoder2 setupAudioEncoderWithFormatDescription:formatDescription];
                }
				
				// Write audio data to file
				if (appleEncoder2.readyToRecordAudio && appleEncoder2.readyToRecordVideo)
					[appleEncoder2 writeSampleBuffer:sampleBuffer ofType:AVMediaTypeAudio];
			}
			
			BOOL isReadyToRecord = (appleEncoder2.readyToRecordAudio && appleEncoder2.readyToRecordVideo);
			if ( !wasReadyToRecord && isReadyToRecord ) {
				recordingWillBeStarted = NO;
				self.recording = YES;
				[self.delegate recordingDidStart];
			}
		}
		CFRelease(sampleBuffer);
		CFRelease(formatDescription);
	});
    
}

- (AVCaptureDevice *)videoDeviceWithPosition:(AVCaptureDevicePosition)position 
{
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in devices)
        if ([device position] == position)
            return device;
    
    return nil;
}

- (AVCaptureDevice *)audioDevice
{
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio];
    if ([devices count] > 0)
        return [devices objectAtIndex:0];
    
    return nil;
}

- (BOOL) setupCaptureSession 
{
	/*
		Overview: RosyWriter uses separate GCD queues for audio and video capture.  If a single GCD queue
		is used to deliver both audio and video buffers, and our video processing consistently takes
		too long, the delivery queue can back up, resulting in audio being dropped.
		
		When recording, RosyWriter creates a third GCD queue for calls to AVAssetWriter.  This ensures
		that AVAssetWriter is not called to start or finish writing from multiple threads simultaneously.
		
		RosyWriter uses AVCaptureSession's default preset, AVCaptureSessionPresetHigh.
	 */
	 
    /*
	 * Create capture session
	 */
    captureSession = [[AVCaptureSession alloc] init];
    captureSession.sessionPreset = AVCaptureSessionPreset640x480;
    
    /*
	 * Create audio connection
	 */
    AVCaptureDeviceInput *audioIn = [[AVCaptureDeviceInput alloc] initWithDevice:[self audioDevice] error:nil];
    if ([captureSession canAddInput:audioIn])
        [captureSession addInput:audioIn];
	
	AVCaptureAudioDataOutput *audioOut = [[AVCaptureAudioDataOutput alloc] init];
	dispatch_queue_t audioCaptureQueue = dispatch_queue_create("Audio Capture Queue", DISPATCH_QUEUE_SERIAL);
	[audioOut setSampleBufferDelegate:self queue:audioCaptureQueue];
	dispatch_release(audioCaptureQueue);
	if ([captureSession canAddOutput:audioOut])
		[captureSession addOutput:audioOut];
	audioConnection = [audioOut connectionWithMediaType:AVMediaTypeAudio];
    
	/*
	 * Create video connection
	 */
    AVCaptureDeviceInput *videoIn = [[AVCaptureDeviceInput alloc] initWithDevice:[self videoDeviceWithPosition:AVCaptureDevicePositionBack] error:nil];
    if ([captureSession canAddInput:videoIn])
        [captureSession addInput:videoIn];
    
	AVCaptureVideoDataOutput *videoOut = [[AVCaptureVideoDataOutput alloc] init];
	/*
		RosyWriter prefers to discard late video frames early in the capture pipeline, since its
		processing can take longer than real-time on some platforms (such as iPhone 3GS).
		Clients whose image processing is faster than real-time should consider setting AVCaptureVideoDataOutput's
		alwaysDiscardsLateVideoFrames property to NO. 
	 */
	[videoOut setAlwaysDiscardsLateVideoFrames:NO];
        /*
     2012-10-24 22:09:13.074 RosyWriter[86513:707] kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
     2012-10-24 22:09:13.080 RosyWriter[86513:707] kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
     2012-10-24 22:09:13.081 RosyWriter[86513:707] kCVPixelFormatType_32BGRA
     */
	[videoOut setVideoSettings:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange] forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
	dispatch_queue_t videoCaptureQueue = dispatch_queue_create("Video Capture Queue", DISPATCH_QUEUE_SERIAL);
	[videoOut setSampleBufferDelegate:self queue:videoCaptureQueue];
	dispatch_release(videoCaptureQueue);
	if ([captureSession canAddOutput:videoOut])
		[captureSession addOutput:videoOut];
	videoConnection = [videoOut connectionWithMediaType:AVMediaTypeVideo];
	self.videoOrientation = [videoConnection videoOrientation];
    
	return YES;
}

- (void) setupAndStartCaptureSession
{
	// Create a shallow queue for buffers going to the display for preview.
	OSStatus err = CMBufferQueueCreate(kCFAllocatorDefault, 1, CMBufferQueueGetCallbacksForUnsortedSampleBuffers(), &previewBufferQueue);
	if (err)
		[self showError:[NSError errorWithDomain:NSOSStatusErrorDomain code:err userInfo:nil]];
    err = CMBufferQueueCreate(kCFAllocatorDefault, 1, CMBufferQueueGetCallbacksForUnsortedSampleBuffers(), &ffmpegBufferQueue);
	if (err)
		[self showError:[NSError errorWithDomain:NSOSStatusErrorDomain code:err userInfo:nil]];
    
	// Create serial queue for movie writing
	movieWritingQueue = dispatch_queue_create("Movie Writing Queue", DISPATCH_QUEUE_SERIAL);
	ffmpegWritingQueue = dispatch_queue_create("FFmpeg Writing Queue", DISPATCH_QUEUE_SERIAL);
    
    if ( !captureSession )
		[self setupCaptureSession];
	
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(captureSessionStoppedRunningNotification:) name:AVCaptureSessionDidStopRunningNotification object:captureSession];
	
	if ( !captureSession.isRunning )
		[captureSession startRunning];
}

- (void) pauseCaptureSession
{
	if ( captureSession.isRunning )
		[captureSession stopRunning];
}

- (void) resumeCaptureSession
{
	if ( !captureSession.isRunning )
		[captureSession startRunning];
}

- (void)captureSessionStoppedRunningNotification:(NSNotification *)notification
{
	dispatch_async(movieWritingQueue, ^{
		if ( [self isRecording] ) {
			[self stopRecording];
		}
	});
}

- (void) stopAndTearDownCaptureSession
{
    [captureSession stopRunning];
	if (captureSession)
		[[NSNotificationCenter defaultCenter] removeObserver:self name:AVCaptureSessionDidStopRunningNotification object:captureSession];
	captureSession = nil;
	if (previewBufferQueue) {
		CFRelease(previewBufferQueue);
		previewBufferQueue = NULL;	
	}
    if (ffmpegBufferQueue) {
		CFRelease(ffmpegBufferQueue);
		ffmpegBufferQueue = NULL;
	}
	if (movieWritingQueue) {
		dispatch_release(movieWritingQueue);
		movieWritingQueue = NULL;
	}
    if (ffmpegWritingQueue) {
		dispatch_release(ffmpegWritingQueue);
		ffmpegWritingQueue = NULL;
	}
}

#pragma mark Error Handling

- (void)showError:(NSError *)error
{
    NSLog(@"Error: %@%@",[error localizedDescription], [error userInfo]);
    CFRunLoopPerformBlock(CFRunLoopGetMain(), kCFRunLoopCommonModes, ^(void) {
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:[error localizedDescription]
                                                            message:[error localizedFailureReason]
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
        [alertView show];
    });
}

@end
