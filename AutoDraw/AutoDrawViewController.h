//
//  AutoDrawViewController.h
//  AutoDraw
//
//  Created by Russell on 12.04.17.
//  Copyright © 2017 Sketch plugin by https://sympli.io All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

@protocol AutoDrawViewControllerDelegate <NSObject>
-(void)drawViewControllerDidSendRequest:(NSURLRequest*)request;

-(void)removeSourceLayers:(BOOL)remove;

@end

@interface AutoDrawViewController : NSViewController <WebResourceLoadDelegate, WebFrameLoadDelegate, WebUIDelegate>
@property (strong) id<AutoDrawViewControllerDelegate> delegate;
@property (nonatomic) BOOL deleteSourceLayers;

@property (nonatomic, weak) IBOutlet WebView *previewWebView;
@property (nonatomic, weak) IBOutlet WebView *disclWebView;
@property (nonatomic, weak) IBOutlet NSButton *deleteSourceLayersCheckbox;

- (void)update:(NSArray*)urls;
- (void)setDeleteSourceLayers:(BOOL)deleteSourceLayers;
@end
