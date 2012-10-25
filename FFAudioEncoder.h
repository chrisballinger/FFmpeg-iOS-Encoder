//
//  FFAudioEncoder.h
//  RosyWriter
//
//  Created by Christopher Ballinger on 10/25/12.
//
//

#import <Foundation/Foundation.h>
#import "FFEncoder.h"

@interface FFAudioEncoder : NSObject <FFAVEncoder> {
    AVCodec *codec;
    AVCodecContext *c;
    AVFrame *frame;
    AVPacket pkt;
    int i, j, k, ret, got_output;
    int buffer_size;
    FILE *f;
    uint16_t *samples;
    float t, tincr;
}

@end
