//
//  SketchPluginDemo.h
//  SketchPluginDemo
//
//  Created by Sergey on 1/23/17.
//  Copyright © 2017 Sketch plugin by https://sympli.io All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "AutoDrawViewController.h"
#import "AutoDrawNetworkClient.h"

@interface AutoDrawPlugin : NSObject <AutoDrawViewControllerDelegate>

@property double thickness;
@property BOOL removeOriginalLayers;
@property (strong) NSArray *layers;
@property (nonatomic, strong) AutoDrawViewController *autoDrawViewController;
@property (strong) AutoDrawNetworkClient *networkClient;

-(void)processDocument:(id)document;

@end
