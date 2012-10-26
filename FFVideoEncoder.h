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
}

@end
