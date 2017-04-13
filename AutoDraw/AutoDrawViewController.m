//
//  AutoDrawViewController.m
//  AutoDraw
//
//  Created by Russell on 12.04.17.
//  Copyright © 2017 Sketch plugin by https://sympli.io All rights reserved.
//

#import "AutoDrawViewController.h"
#import <WebKit/WebPolicyDelegate.h>

@interface AutoDrawViewController () <WebPolicyDelegate>
-(IBAction)deleteSourceLayersClicked:(id)sender;
@end

@implementation AutoDrawViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.previewWebView.policyDelegate = self;
    [self setDeleteSourceLayers:self.deleteSourceLayers];
    
    NSString *html = @"<html><body topmargin=0 leftmargin=8 rightmargin=0><span style='color: gray; font-size: 9pt; font-family: Helvetica;' href='safari://www.autodraw.com'>Select shape layers and press <b>ctrl + shift + m</b> to search.<br/>Sketch plugin by <a style='color: gray; font-size: 9pt; font-family: Helvetica;' href='safari://sympli.io'>sympli.io</a>, amazing <a style='color: gray; font-size: 9pt; font-family: Helvetica;' href='safari://www.autodraw.com/'>autodraw.com</a> by <a style='color: gray; font-size: 9pt; font-family: Helvetica;' href='safari://aiexperiments.withgoogle.com/'>Google</a>. Read more on <a style='color: gray; font-size: 9pt; font-family: Helvetica;' href='safari://github.com/sympli/autodraw-sketch'>GitHub</a></span></body></html>";
    NSURL *baseURL = [NSURL URLWithString:@"https://storage.googleapis.com"];
    [[self.disclWebView mainFrame] loadHTMLString:html baseURL:baseURL];
}

-(void) deleteSourceLayersClicked: (id) sender {
    BOOL deleteSourceLayers = self.deleteSourceLayersCheckbox.state == NSOnState;
    [self.delegate removeSourceLayers:deleteSourceLayers];
    
}

- (void)update:(NSArray*)urls {
    id script = [self.previewWebView windowScriptObject];
    [script setValue:self forKey:@"objc"];
    
    NSMutableString *html = [NSMutableString string];
    [html appendString:@"<html><body><div style=\"white-space: nowrap\">"];
    
    for (NSString *url in urls) {
        NSString *div = [NSString stringWithFormat:@"<div style=\"display: inline-block; width: 50px; height: 50px\"><a href=\"%@?1\"><img src=\"%@\"></a></div>", url, url];
        [html appendString:div];
    }
    [html appendString:@"</div>"];
    [html appendString:@"</body></html>"];
    
    NSURL *baseURL = [NSURL URLWithString:@"https://storage.googleapis.com"];
    [[self.previewWebView mainFrame] loadHTMLString:html baseURL:baseURL];
}

- (void)webView:(WebView *)sender decidePolicyForNavigationAction:(NSDictionary *)actionInformation request:(NSURLRequest *)request frame:(WebFrame *)frame decisionListener:(id <WebPolicyDecisionListener>)listener {
    if ([request.URL.relativeString hasSuffix:@".svg?1"]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate drawViewControllerDidSendRequest:request];
        });
        [listener ignore];
    } else if ([request.URL.scheme isEqualToString:@"safari"]) {
        NSURL* url = [NSURL URLWithString:[[request.URL absoluteString] stringByReplacingOccurrencesOfString:@"safari://" withString:@"http://"]];
        
        [[NSWorkspace sharedWorkspace] openURL:url];
    } else {
        [listener use];
    }
}

- (void)setDeleteSourceLayers:(BOOL)deleteSourceLayers {
    _deleteSourceLayers = deleteSourceLayers;
    self.deleteSourceLayersCheckbox.state = deleteSourceLayers ? NSOnState : NSOffState;
}

@end
