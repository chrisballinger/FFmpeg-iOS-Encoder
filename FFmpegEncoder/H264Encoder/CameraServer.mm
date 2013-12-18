//
//  CameraServer.m
//  Encoder Demo
//
//  Created by Geraint Davies on 19/02/2013.
//  Copyright (c) 2013 GDCL http://www.gdcl.co.uk/license.htm
//

#import "CameraServer.h"
#import "AVEncoder.h"
#import "RTSPServer.h"
#import "NALUnit.h"
#import "HLSWriter.h"

static const int VIDEO_WIDTH = 1280;
static const int VIDEO_HEIGHT = 720;

static CameraServer* theServer;

@interface CameraServer  () <AVCaptureVideoDataOutputSampleBufferDelegate>
{
    AVCaptureSession* _session;
    AVCaptureVideoPreviewLayer* _preview;
    AVCaptureVideoDataOutput* _output;
    dispatch_queue_t _captureQueue;
    
    AVEncoder* _encoder;
    
    RTSPServer* _rtsp;
}

@property (nonatomic, strong) NSData *naluStartCode;
@property (nonatomic, strong) NSFileHandle *debugFileHandle;
@property (nonatomic, strong) HLSWriter *hlsWriter;
@property (nonatomic, strong) NSMutableData *videoSPSandPPS;

@end


@implementation CameraServer

+ (void) initialize
{
    // test recommended to avoid duplicate init via subclass
    if (self == [CameraServer class])
    {
        theServer = [[CameraServer alloc] init];
    }
}

+ (CameraServer*) server
{
    return theServer;
}

- (void) startup
{
    if (_session == nil)
    {
        NSLog(@"Starting up server");
        NSUInteger naluLength = 4;
        uint8_t *nalu = (uint8_t*)malloc(naluLength * sizeof(uint8_t));
        nalu[0] = 0x00;
        nalu[1] = 0x00;
        nalu[2] = 0x00;
        nalu[3] = 0x01;
        _naluStartCode = [NSData dataWithBytesNoCopy:nalu length:naluLength freeWhenDone:YES];
        
        // create capture device with video input
        _session = [[AVCaptureSession alloc] init];
        AVCaptureDevice* dev = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        AVCaptureDeviceInput* input = [AVCaptureDeviceInput deviceInputWithDevice:dev error:nil];
        [_session addInput:input];
        
        // create an output for YUV output with self as delegate
        _captureQueue = dispatch_queue_create("uk.co.gdcl.avencoder.capture", DISPATCH_QUEUE_SERIAL);
        _output = [[AVCaptureVideoDataOutput alloc] init];
        [_output setSampleBufferDelegate:self queue:_captureQueue];
        NSDictionary* setcapSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                        [NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange], kCVPixelBufferPixelFormatTypeKey,
                                        nil];
        _output.videoSettings = setcapSettings;
        [_session addOutput:_output];
        
        
        // create an encoder
        _encoder = [AVEncoder encoderForHeight:VIDEO_HEIGHT andWidth:VIDEO_WIDTH];
        [_encoder encodeWithBlock:^int(NSArray* dataArray, double pts) {
            [self writeVideoFrames:dataArray pts:pts];
            //[self writeDebugFileForDataArray:dataArray pts:pts];
            if (_rtsp != nil)
            {
                _rtsp.bitrate = _encoder.bitspersecond;
                [_rtsp onVideoData:dataArray time:pts];
            }
            return 0;
        } onParams:^int(NSData *data) {
            _rtsp = [RTSPServer setupListener:data];
            return 0;
        }];
        
        // start capture and a preview layer
        [_session startRunning];
        
        
        _preview = [AVCaptureVideoPreviewLayer layerWithSession:_session];
        _preview.videoGravity = AVLayerVideoGravityResizeAspectFill;
        

    }
}

- (void) writeVideoFrames:(NSArray*)frames pts:(double)pts {
    if (pts == 0) {
        NSLog(@"PTS of 0, skipping frame");
        return;
    }
    NSError *error = nil;
    if (!_hlsWriter) {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
        NSTimeInterval time = [[NSDate date] timeIntervalSince1970];
        NSString *folderName = [NSString stringWithFormat:@"%f.hls", time];
        NSString *hlsDirectoryPath = [basePath stringByAppendingPathComponent:folderName];
        [[NSFileManager defaultManager] createDirectoryAtPath:hlsDirectoryPath withIntermediateDirectories:YES attributes:nil error:nil];
        self.hlsWriter = [[HLSWriter alloc] initWithDirectoryPath:hlsDirectoryPath];
        [_hlsWriter setupVideoWithWidth:VIDEO_WIDTH height:VIDEO_HEIGHT];
        [_hlsWriter prepareForWriting:&error];
        if (error) {
            NSLog(@"Error preparing for writing: %@", error);
        }
        NSData* config = _encoder.getConfigData;
        
        avcCHeader avcC((const BYTE*)[config bytes], [config length]);
        SeqParamSet seqParams;
        seqParams.Parse(avcC.sps());
        
        NSData* spsData = [NSData dataWithBytes:avcC.sps()->Start() length:avcC.sps()->Length()];
        NSData *ppsData = [NSData dataWithBytes:avcC.pps()->Start() length:avcC.pps()->Length()];
        
        _videoSPSandPPS = [NSMutableData dataWithCapacity:avcC.sps()->Length() + avcC.pps()->Length() + _naluStartCode.length * 2];
        [_videoSPSandPPS appendData:_naluStartCode];
        [_videoSPSandPPS appendData:spsData];
        [_videoSPSandPPS appendData:_naluStartCode];
        [_videoSPSandPPS appendData:ppsData];
        
        /*NSMutableData *naluSPS = [[NSMutableData alloc] initWithData:_naluStartCode];
        [naluSPS appendData:spsData];
        NSMutableData *naluPPS = [[NSMutableData alloc] initWithData:_naluStartCode];
        [naluPPS appendData:ppsData];
         */
        //[_hlsWriter processVideoData:videoSPSandPPS presentationTimestamp:pts-200];
        //[_hlsWriter processVideoData:ppsData presentationTimestamp:pts-100];
    }
    
    for (NSData *data in frames) {
        unsigned char* pNal = (unsigned char*)[data bytes];
        //int idc = pNal[0] & 0x60;
        int naltype = pNal[0] & 0x1f;
        NSData *videoData = nil;
        if (naltype == 5) { // IDR
            NSMutableData *IDRData = [NSMutableData dataWithData:_videoSPSandPPS];
            [IDRData appendData:_naluStartCode];
            [IDRData appendData:data];
            videoData = IDRData;
        } else {
            NSMutableData *regularData = [NSMutableData dataWithData:_naluStartCode];
            [regularData appendData:data];
            videoData = regularData;
        }
        //NSMutableData *nalu = [[NSMutableData alloc] initWithData:_naluStartCode];
        //[nalu appendData:data];
        //NSLog(@"%f: %@", pts, videoData.description);
        [_hlsWriter processVideoData:videoData presentationTimestamp:pts];
    }
    
}

- (void) writeDebugFileForDataArray:(NSArray*)dataArray pts:(double)pts {
    if (!_debugFileHandle) {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
        NSTimeInterval time = [[NSDate date] timeIntervalSince1970];
        NSString *folderName = [NSString stringWithFormat:@"%f", time];
        NSString *debugDirectoryPath = [basePath stringByAppendingPathComponent:folderName];
        [[NSFileManager defaultManager] createDirectoryAtPath:debugDirectoryPath withIntermediateDirectories:YES attributes:nil error:nil];

        
        NSString *fileName = [NSString stringWithFormat:@"test.h264"];
        NSString *outputFilePath = [debugDirectoryPath stringByAppendingPathComponent:fileName];
        NSURL *fileURL = [NSURL fileURLWithPath:outputFilePath];
        NSError *error = nil;
        [[NSFileManager defaultManager] createFileAtPath:outputFilePath contents:nil attributes:nil];
        _debugFileHandle = [NSFileHandle fileHandleForWritingToURL:fileURL error:&error];
        if (error) {
            NSLog(@"Error opening file for writing: %@", error.description);
        }
        
        NSData* config = _encoder.getConfigData;
        
        avcCHeader avcC((const BYTE*)[config bytes], [config length]);
        SeqParamSet seqParams;
        seqParams.Parse(avcC.sps());
        
        NSData* spsData = [NSData dataWithBytes:avcC.sps()->Start() length:avcC.sps()->Length()];
        NSData *ppsData = [NSData dataWithBytes:avcC.pps()->Start() length:avcC.pps()->Length()];
        
        [_debugFileHandle writeData:_naluStartCode];
        [_debugFileHandle writeData:spsData];
        [_debugFileHandle writeData:_naluStartCode];
        [_debugFileHandle writeData:ppsData];
    }
    
    for (NSData *data in dataArray) {
        [_debugFileHandle writeData:_naluStartCode];
        [_debugFileHandle writeData:data];
    }
    [_debugFileHandle synchronizeFile];
}

- (void) captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    // pass frame to encoder
    [_encoder encodeFrame:sampleBuffer];
}

- (void) shutdown
{
    NSLog(@"shutting down server");
    if (_session)
    {
        [_session stopRunning];
        _session = nil;
    }
    if (_rtsp)
    {
        [_rtsp shutdownServer];
    }
    if (_encoder)
    {
        [ _encoder shutdown];
    }
    if (_debugFileHandle) {
        [_debugFileHandle closeFile];
    }
}

- (NSString*) getURL
{
    NSString* ipaddr = [RTSPServer getIPAddress];
    NSString* url = [NSString stringWithFormat:@"rtsp://%@/", ipaddr];
    return url;
}

- (AVCaptureVideoPreviewLayer*) getPreviewLayer
{
    return _preview;
}

@end
