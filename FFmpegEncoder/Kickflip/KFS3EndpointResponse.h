//
//  KFS3EndpointResponse.h
//  FFmpegEncoder
//
//  Created by Christopher Ballinger on 1/16/14.
//  Copyright (c) 2014 Christopher Ballinger. All rights reserved.
//

#import "KFEndpointResponse.h"

@interface KFS3EndpointResponse : KFEndpointResponse

@property (nonatomic, strong, readonly) NSString *awsSecretKey;
@property (nonatomic, strong, readonly) NSString *awsAccessKey;
@property (nonatomic, strong, readonly) NSString *bucket;
@property (nonatomic, strong, readonly) NSString *key;

@end
