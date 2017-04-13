//
//  AutoDrawNetworkClient.m
//  AutoDraw
//
//  Created by Russell on 12.04.17.
//  Copyright © 2017 Sketch plugin by https://sympli.io All rights reserved.
//

#import "AutoDrawNetworkClient.h"

#define NETWORK_ERROR  [NSError errorWithDomain:@"sympli.io" code:0 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Error", @"")}]

@implementation AutoDrawNetworkClient

- (void)receiveMatchesWithPayload:(NSDictionary*)payload success:(void(^)(id))success failure:(void(^)(NSError*))failure {
    
    NSString *url = @"https://inputtools.google.com/request?ime=handwriting&app=autodraw&dbg=1&cs=1&oe=UTF-8";
    NSURLRequest *req = [self requestForURL:url payload:payload];
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        
        if (error) {
            failure(NETWORK_ERROR);
            return;
        }
        
        if (data) {
            NSError *jsonError;
            id json = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&jsonError];
            
            if (jsonError) {
                failure(NETWORK_ERROR);
                return;
            }
            
            if (json) {
                success(json);
            } else {
                failure(NETWORK_ERROR);
            }
        }
        
    }] resume];
}

- (NSURLRequest *)requestForURL:(NSString *)url payload:(NSDictionary *)payload {
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:url]];
    [request setHTTPMethod:@"POST"];
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:payload options:NSJSONWritingPrettyPrinted error:nil];
    [request setHTTPBody:jsonData];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"UTF-8" forHTTPHeaderField:@"Accept-Charset"];
    return [request mutableCopy];
}

@end
