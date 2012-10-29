//
//  FFVideoEncoder.h
//  RosyWriter
//
//  Created by Christopher Ballinger on 10/25/12.
//
//

#import <Foundation/Foundation.h>
#import "FFAVEncoder.h"

@interface FFVideoEncoder : FFAVEncoder {
    int frameNumber, ret, got_output;
    FILE *f;
    CMVideoDimensions outputSize;
    CMVideoDimensions inputSize;
    struct SwsContext *sws_ctx;
    AVFrame *scaledFrame;
}

- (void) setupEncoderWithFormatDescription:(CMFormatDescriptionRef)newFormatDescription desiredOutputSize:(CMVideoDimensions)desiredOutputSize;

@end
