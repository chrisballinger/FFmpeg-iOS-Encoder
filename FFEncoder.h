//
//  FFEncoder.h
//  RosyWriter
//
//  Created by Christopher Ballinger on 10/25/12.
//
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#include <libavcodec/avcodec.h>

@protocol FFAVEncoder <NSObject>
- (void) setupEncoder;
- (void) finishEncoding;
- (void) encodeSampleBuffer:(CMSampleBufferRef)sampleBuffer;
@end

@interface FFEncoder : NSObject

@property (nonatomic, strong) id<FFAVEncoder> videoEncoder;
@property (nonatomic, strong) id<FFAVEncoder> audioEncoder;

@end
