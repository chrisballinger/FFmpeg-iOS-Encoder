//
//  AVEncoder.m
//  RosyWriter
//
//  Created by Christopher Ballinger on 10/29/12.
//
//

#import "AVEncoder.h"

@implementation AVEncoder
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
