//
//  KFAPIClient.m
//  FFmpegEncoder
//
//  Created by Christopher Ballinger on 1/16/14.
//  Copyright (c) 2014 Christopher Ballinger. All rights reserved.
//

#import "KFAPIClient.h"
#import "OWSecrets.h"
#import "AFOAuth2Client.h"


@implementation KFAPIClient

+ (KFAPIClient*) sharedClient {
    static KFAPIClient *_sharedClient = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedClient = [[KFAPIClient alloc] init];
    });
    return _sharedClient;
}

- (instancetype) init {
    NSURL *url = [NSURL URLWithString:KICKFLIP_API_BASE_URL];
    if (self = [super initWithBaseURL:url]) {
        [self registerHTTPOperationClass:[AFJSONRequestOperation class]];
        [self checkOAuthCredentials];
        [self setDefaultHeader:@"Accept" value:@"application/json"];
    }
    return self;
}

- (void) checkOAuthCredentials {
    NSURL *url = [NSURL URLWithString:KICKFLIP_API_BASE_URL];
    AFOAuth2Client *oauthClient = [AFOAuth2Client clientWithBaseURL:url clientID:KICKFLIP_PRODUCTION_API_ID secret:KICKFLIP_PRODUCTION_API_SECRET];
    
    AFOAuthCredential *credential = [AFOAuthCredential retrieveCredentialWithIdentifier:oauthClient.serviceProviderIdentifier];
    
    void (^callbackBlock)(KFEndpointResponse *endpointResponse, NSError *error) = ^(KFEndpointResponse *endpointResponse, NSError *error){
        if (error) {
            NSLog(@"Error: %@", error);
        } else {
            NSLog(@"endpoint: %@", endpointResponse);
        }
    };
    
    if (!credential || credential.isExpired) {
        [oauthClient authenticateUsingOAuthWithPath:@"/o/token/" parameters:@{@"grant_type": kAFOAuthClientCredentialsGrantType} success:^(AFOAuthCredential *credential) {
            NSLog(@"I have a token! %@", credential.accessToken);
            [AFOAuthCredential storeCredential:credential withIdentifier:oauthClient.serviceProviderIdentifier];
            [self setAuthorizationHeaderWithCredential:credential];
            [self requestRecordingEndpoint:callbackBlock];
        } failure:^(NSError *error) {
            NSLog(@"Error: %@", error);
        }];
    } else {
        [self setAuthorizationHeaderWithCredential:credential];
        [self requestRecordingEndpoint:callbackBlock];
    }
}

- (void) setAuthorizationHeaderWithCredential:(AFOAuthCredential*)credential {
    [self setDefaultHeader:@"Authorization" value:[NSString stringWithFormat:@"Bearer %@", credential.accessToken]];
}


- (void) requestRecordingEndpoint:(void (^)(KFEndpointResponse *, NSError *))endpointCallback {
    [self postPath:@"/api/new/user/" parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
        if (responseObject && [responseObject isKindOfClass:[NSDictionary class]]) {
            NSDictionary *responseDictionary = (NSDictionary*)responseObject;
            NSLog(@"response: %@", responseDictionary);
        }
        KFEndpointResponse *response = [[KFEndpointResponse alloc] init];
        if (endpointCallback) {
            endpointCallback(response, nil);
        }
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if (error && endpointCallback) {
            endpointCallback(nil, error);
        }
    }];
}


@end
