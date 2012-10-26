//
//  FFAVEncoder.m
//  RosyWriter
//
//  Created by Christopher Ballinger on 10/26/12.
//
//

#import "FFAVEncoder.h"

@implementation FFAVEncoder
@synthesize readyToEncode, formatDescription;

- (id) init {
    if (self = [super init]) {
        readyToEncode = NO;
    }
    return self;
}

- (void) setupEncoderWithFormatDescription:(CMFormatDescriptionRef)newFormatDescription {
    formatDescription = newFormatDescription;
    CFRetain(formatDescription);
    readyToEncode = YES;
}
- (void) finishEncoding {
    CFRelease(formatDescription);
    formatDescription = NULL;
    readyToEncode = NO;
}
- (void) encodeSampleBuffer:(CMSampleBufferRef)sampleBuffer {}

@end
