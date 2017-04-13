//
//  AutoDrawNetworkClient.h
//  AutoDraw
//
//  Created by Russell on 12.04.17.
//  Copyright © 2017 Sketch plugin by https://sympli.io All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AutoDrawNetworkClient : NSObject

- (void)receiveMatchesWithPayload:(NSDictionary*)payload success:(void(^)(id))success failure:(void(^)(NSError*))failure;
- (NSURLRequest *)requestForURL:(NSString *)url payload:(NSDictionary *)payload;

@end
