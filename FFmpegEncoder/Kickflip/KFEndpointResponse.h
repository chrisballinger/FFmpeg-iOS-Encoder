//
//  KFEndpointResponse.h
//  FFmpegEncoder
//
//  Created by Christopher Ballinger on 1/16/14.
//  Copyright (c) 2014 Christopher Ballinger. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface KFEndpointResponse : NSObject

@property (nonatomic, strong, readonly) NSURL *broadcastURL;

- (instancetype) initWithResponseInfo:(NSDictionary*)responseInfo;

+ (KFEndpointResponse*) endpointWithResponseInfo:(NSDictionary*)responseInfo;

@end
