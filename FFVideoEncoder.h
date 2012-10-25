//
//  FFVideoEncoder.h
//  RosyWriter
//
//  Created by Christopher Ballinger on 10/25/12.
//
//

#import <Foundation/Foundation.h>
#include <libavcodec/avcodec.h>
#import "FFEncoder.h"

@interface FFVideoEncoder : NSObject <FFAVEncoderDelegate> {
    AVCodec *codec;
    AVCodecContext *c;
    int frameNumber, ret, got_output;
    FILE *f;
    AVFrame *frame;
    AVPacket pkt;
}

@end
