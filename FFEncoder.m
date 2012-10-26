//
//  FFEncoder.m
//  RosyWriter
//
//  Created by Christopher Ballinger on 10/25/12.
//
//

#import "FFEncoder.h"

@implementation FFEncoder
@synthesize videoEncoder, audioEncoder;

- (id) init {
    if (self = [super init]) {
        self.videoEncoder = [[FFVideoEncoder alloc] init];
        self.audioEncoder = [[FFAudioEncoder alloc] init];
        /* register all the codecs */
        avcodec_register_all();
    }
    return self;
}

@end
