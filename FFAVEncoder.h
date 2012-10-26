//
//  FFAVEncoder.h
//  RosyWriter
//
//  Created by Christopher Ballinger on 10/26/12.
//
//

#import <Foundation/Foundation.h>
#include <libavcodec/avcodec.h>
#import <AVFoundation/AVFoundation.h>

@interface FFAVEncoder : NSObject {
    CMFormatDescriptionRef formatDescription;
    AVCodec *codec;
    AVCodecContext *c;
    AVFrame *frame;
    AVPacket pkt;
}

- (void) setupEncoderWithFormatDescription:(CMFormatDescriptionRef)formatDescription;
- (void) finishEncoding;
- (void) encodeSampleBuffer:(CMSampleBufferRef)sampleBuffer;

@property (nonatomic) BOOL readyToEncode;
@property (nonatomic) CMFormatDescriptionRef formatDescription;

@end
