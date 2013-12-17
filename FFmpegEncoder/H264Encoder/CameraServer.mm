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
        _encoder = [AVEncoder encoderForHeight:480 andWidth:720];
        [_encoder encodeWithBlock:^int(NSArray* dataArray, double pts) {
            [self writeDebugFileForDataArray:dataArray pts:pts];
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

- (void) writeDebugFileForDataArray:(NSArray*)dataArray pts:(double)pts {
    if (!_debugFileHandle) {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
        NSTimeInterval time = [[NSDate date] timeIntervalSince1970];
        NSString *folderName = [NSString stringWithFormat:@"%f", time];
        NSString *debugDirectoryPath = [basePath stringByAppendingPathComponent:folderName];
        [[NSFileManager defaultManager] createDirectoryAtPath:debugDirectoryPath withIntermediateDirectories:YES attributes:nil error:nil];
        NSUInteger naluLength = 3;
        uint8_t *nalu = (uint8_t*)malloc(naluLength * sizeof(uint8_t));
        nalu[0] = 0x00;
        nalu[1] = 0x00;
        nalu[2] = 0x01;
        _naluStartCode = [NSData dataWithBytesNoCopy:nalu length:naluLength freeWhenDone:YES];
        
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
        int cx = seqParams.EncodedWidth();
        int cy = seqParams.EncodedHeight();
        
        NSString* profile_level_id = [NSString stringWithFormat:@"%02x%02x%02x", seqParams.Profile(), seqParams.Compat(), seqParams.Level()];
        
        NSData* spsData = [NSData dataWithBytes:avcC.sps()->Start() length:avcC.sps()->Length()];
        NSData *ppsData = [NSData dataWithBytes:avcC.pps()->Start() length:avcC.pps()->Length()];
        
        [_debugFileHandle writeData:_naluStartCode];
        [_debugFileHandle writeData:spsData];
        [_debugFileHandle writeData:_naluStartCode];
        [_debugFileHandle writeData:ppsData];
    }
    
    for (NSData *data in dataArray) {
        /*unsigned char* pNal = (unsigned char*)[data bytes];
        int idc = pNal[0] & 0x60;
        int naltype = pNal[0] & 0x1f;
        NSLog(@"idc: %d, naltype: %d", idc, naltype);
        if (naltype == 5) {
            [_debugFileHandle writeData:_naluStartCode];
            [_debugFileHandle writeData:_encoder.getConfigData];
        }
         */
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
