//
//  FFEncoder.h
//  RosyWriter
//
//  Created by Christopher Ballinger on 10/25/12.
//
//

#import <Foundation/Foundation.h>
#import "FFVideoEncoder.h"
#import "FFAudioEncoder.h"

@interface FFEncoder : NSObject

@property (nonatomic, strong) FFVideoEncoder *videoEncoder;
@property (nonatomic, strong) FFAudioEncoder *audioEncoder;

@end
