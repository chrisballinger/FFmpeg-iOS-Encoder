//
//  FFAVEncoder.h
//  RosyWriter
//
//  Created by Christopher Ballinger on 10/26/12.
//
//

#import <Foundation/Foundation.h>
#include <libavcodec/avcodec.h>
#import "AVEncoder.h"

@interface FFAVEncoder : AVEncoder {
    CMFormatDescriptionRef formatDescription;
    AVCodec *codec;
    AVCodecContext *c;
    AVFrame *frame;
    AVPacket pkt;
}

@end
