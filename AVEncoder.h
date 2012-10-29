//
//  AVEncoder.h
//  RosyWriter
//
//  Created by Christopher Ballinger on 10/29/12.
//
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@interface AVEncoder : NSObject

- (void) setupEncoderWithFormatDescription:(CMFormatDescriptionRef)formatDescription;
- (void) finishEncoding;
- (void) encodeSampleBuffer:(CMSampleBufferRef)sampleBuffer;

@property (nonatomic) BOOL readyToEncode;
@property (nonatomic) CMFormatDescriptionRef formatDescription;

@end
