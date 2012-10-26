//
//  FFAudioEncoder.h
//  RosyWriter
//
//  Created by Christopher Ballinger on 10/25/12.
//
//

#import <Foundation/Foundation.h>
#import "FFAVEncoder.h"

@interface FFAudioEncoder : FFAVEncoder {
    const AudioStreamBasicDescription *currentASBD;
    int ret, got_output;
    int buffer_size;
    FILE *f;
    short *samples;
    float t, tincr;
}

@end
