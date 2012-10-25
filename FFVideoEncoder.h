//
//  FFVideoEncoder.h
//  RosyWriter
//
//  Created by Christopher Ballinger on 10/25/12.
//
//

#import <Foundation/Foundation.h>
#import "FFEncoder.h"

@interface FFVideoEncoder : NSObject <FFAVEncoder> {
    AVCodec *codec;
    AVCodecContext *c;
    int frameNumber, ret, got_output;
    FILE *f;
    AVFrame *frame;
    AVPacket pkt;
}

@end
