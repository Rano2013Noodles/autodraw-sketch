//
//  SketchPluginDemo.m
//  SketchPluginDemo
//
//  Created by Sergey on 1/23/17.
//  Copyright © 2017 Sketch plugin by https://sympli.io All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AutoDrawPlugin.h"
#import "AutoDrawNetworkClient.h"

@interface AutoDrawPlugin ()
@property (nonatomic, strong) NSWindow *window;
@end

@implementation AutoDrawPlugin : NSObject
@synthesize window=_window;
@synthesize autoDrawViewController=_autoDrawViewController;

-(NSRect) getRectForLayers:layers method:(NSString*)method {
    NSRect result = CGRectNull;
    BOOL first = YES;
    for(id layer in layers) {
        NSRect rect = [self getRectForLayer:layer method:@"frame"];
        result = NSUnionRect(result, rect);
    }
    return result;
}

-(NSRect) getRectForLayer:(id)layer method:(NSString*)method {
    id absoluteRect = [layer valueForKey:method];
    
    NSRect returnValue = CGRectZero;
    
    if(absoluteRect) {
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:
                                    [[absoluteRect class] instanceMethodSignatureForSelector:@selector(rect)]];
        [invocation setSelector:@selector(rect)];
        [invocation setTarget:absoluteRect];
        [invocation invoke];
        
        [invocation getReturnValue:&returnValue];
        
    }
    
    return returnValue;
    
}

- (void)adjustThickness:(id)layer withValue:(double)thickness {
    if(![layer respondsToSelector:@selector(layers)]) {
        return;
    }
    NSArray * sublayers = [layer valueForKey:@"layers"];
    if (sublayers) {
        for (id _layerItem in sublayers) {
            
            id layerItem = _layerItem;
            
            id style = [layerItem valueForKey:@"style"];
            
            if(!style) {
                style = [[layerItem valueForKey:@"styledLayer"] valueForKey:@"style"];
            }
            
            if(style) {
                id border = [style valueForKey:@"border"];
                if(border) {
                    [border setValue:[NSNumber numberWithDouble:thickness] forKey:@"thickness"];
                }
                
            }
            
            
            [self adjustThickness:layerItem withValue:thickness];
        }
    }
}

-(NSArray*)selectedArtboards:(id)document {
    NSArray * selectedArtboards = [document performSelector:@selector(selectedLayers)];
    
    if(![selectedArtboards respondsToSelector:@selector(count)]) {
        selectedArtboards = [selectedArtboards valueForKey:@"layers"];
    }
    
    if(![selectedArtboards count]) {
        id page = [document performSelector:@selector(currentPage)];
        NSArray * artboards = [page performSelector:@selector(artboards)];
        
        selectedArtboards = artboards;
    }
    
    NSArray * choosenArtboards = [selectedArtboards valueForKeyPath:@"parentArtboard.@distinctUnionOfObjects.self"];
    if(choosenArtboards) {
        NSPredicate * notNSNullPredicate = [NSPredicate predicateWithFormat:@"self!=nil AND NOT self isKindOfClass: %@",
                                            [NSNull class]];
        choosenArtboards = [choosenArtboards filteredArrayUsingPredicate:notNSNullPredicate];
    }
    
    return choosenArtboards;
}


-(void) removeLayers:(id) layers {
    for(id layer in layers) {
        [layer performSelector:@selector(removeFromParent)];
    }
}


- (id) appendLayer:(id)layer toParent:(id)parent  {
    if(parent && [parent respondsToSelector:@selector(addLayers:)]) {
        NSArray * layers = [NSArray arrayWithObjects:layer, nil];
        [parent performSelector:@selector(addLayers:) withObject:layers];
        return layer;
    }
    return nil;
}

- (void) setLocation:(NSRect)rect forLayer:(id)layer isAbsolute:(BOOL)absolute {
    if(absolute) {
        id absoluteRect = [layer valueForKey:@"absoluteRect"];
        
        if(absoluteRect) {
            
            NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:
                                        [[absoluteRect class] instanceMethodSignatureForSelector:@selector(setRect:)]];
            [invocation setSelector:@selector(setRect:)];
            [invocation setTarget:absoluteRect];
            [invocation setArgument:&rect atIndex:2];
            [invocation invoke];
            
        }
        
    } else {
        id frame = [layer valueForKey:@"frame"];
        
        NSValue *frameValue = (NSValue*)[[layer valueForKey:@"frame"] valueForKey:@"rect"];
        CGFloat aspectRatio = MAX((frameValue.rectValue.size.width/rect.size.width), (frameValue.rectValue.size.height/rect.size.height));
        
        CGFloat width = frameValue.rectValue.size.width/aspectRatio;
        CGFloat height = frameValue.rectValue.size.height/aspectRatio;
        
        CGFloat centerX = rect.origin.x + rect.size.width/2;
        CGFloat centerY = rect.origin.y + rect.size.height/2;
        
        NSRect resultRect = NSMakeRect(centerX - width/2, centerY - height/2, width, height);
        
        if(frame) {
            NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:
                                        [[frame class] instanceMethodSignatureForSelector:@selector(setRect:)]];
            [invocation setSelector:@selector(setRect:)];
            [invocation setTarget:frame];
            [invocation setArgument:&resultRect atIndex:2];
            [invocation invoke];
        }
    }
}

+ (id)alloc {
    static id sharedInstance = nil;
    @synchronized(self) {
        if (!sharedInstance) {
            sharedInstance = [super alloc];
        }
        return sharedInstance;
    }
}

- (instancetype)init {
    self = [super init];
    if (self) {
        NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
        NSDictionary *dict = [ud objectForKey:@"sketch-autodraw"];
        
        self.removeOriginalLayers = [(dict[@"removeOriginalLayers"] ?: @(YES)) boolValue];
        self.networkClient = [AutoDrawNetworkClient new];
    }
    return self;
}
    
-(void)processDocument:(id)document {
    
    NSWindow * docWindow = [document valueForKey:@"documentWindow"];
    NSBundle * bundle = [NSBundle bundleForClass:[AutoDrawPlugin class]];

    
    id selectedElements = [document valueForKey:@"selectedLayers"];
    self.layers = [selectedElements valueForKey:@"layers"];
    
    if(!self.layers || [self.layers count] == 0) {
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText:@"Please select one or more shape layer"];
        [alert runModal];
        return;
    }
    
    NSMutableArray * shapes = [NSMutableArray array];
    NSMutableArray * shapeLayers = [NSMutableArray array];
    for(id layer in self.layers) {
        if(![layer respondsToSelector:@selector(bezierPathWithTransforms)]) {
            continue;
        }
        NSBezierPath * originalPath = [layer valueForKey:@"bezierPathWithTransforms"];
        if(!originalPath) {
            continue;
        }
        [shapeLayers addObject:layer];
        
        id style = [layer valueForKey:@"style"];
        
        if(!style) {
            style = [[layer valueForKey:@"styledLayer"] valueForKey:@"style"];
        }
        
        if(style) {
            id border = [style valueForKey:@"border"];
            if(border) {
                id thicknessId = [border valueForKey:@"thickness"];
                
                if(thicknessId) {
                    CGFloat thickness = [thicknessId doubleValue];
                    [self setThickness:thickness];
                }
            }
            
        }
    }
    
    for(id layer in shapeLayers) {
        
        NSMutableDictionary * shape = [NSMutableDictionary dictionary];
        
        if(![layer respondsToSelector:@selector(bezierPathWithTransforms)]) {
            continue;
        }
        
        NSBezierPath * originalPath = [layer valueForKey:@"bezierPathWithTransforms"];
        if(!originalPath) {
            continue;
        }
     
        NSMutableArray * Xs = [NSMutableArray array];
        NSMutableArray * Ys = [NSMutableArray array];

        NSBezierPath *flatPath = [originalPath bezierPathByFlatteningPath];
        NSInteger count = [flatPath elementCount];
        NSPoint prev, curr;
        NSInteger i;

        for(i = 0; i < count; ++i) {
            // Since we are using a flattened path, no element will contain more than one point
            NSBezierPathElement type = [flatPath elementAtIndex:i associatedPoints:&curr];
            if(type == NSLineToBezierPathElement) {
                NSLog(@"Line from %@ to %@",NSStringFromPoint(prev),NSStringFromPoint(curr));
            } else if(type == NSClosePathBezierPathElement) {
                // Get the first point in the path as the line's end. The first element in a path is a move to operation
                [flatPath elementAtIndex:0 associatedPoints:&curr];
                NSLog(@"Close line from %@ to %@",NSStringFromPoint(prev),NSStringFromPoint(curr));
            }
            if(i < count - 1) {
                [Xs addObject: [NSNumber numberWithFloat: prev.x]];
                [Ys addObject:[NSNumber numberWithFloat: prev.y]];
            } else {
                [Xs addObject: [NSNumber numberWithFloat: curr.x]];
                [Ys addObject: [NSNumber numberWithFloat: curr.y]];
            }

            // set location
            prev = curr;
        }
        [shape setValue:Xs forKey:@"x"];
        [shape setValue:Ys forKey:@"y"];
        [shapes addObject:shape];
    }
    
    NSRect frame = [self getRectForLayers:self.layers method:@"frame"];
    
    [self showAutoDrawWindow: docWindow bundle:bundle];
    [self processMatches:shapes outputSize:frame.size success:^(NSArray *names) {

        NSURL *baseURL = [NSURL URLWithString:@"https://storage.googleapis.com/artlab-public.appspot.com/stencils/selman/"];
        NSMutableArray *paths = [NSMutableArray array];
        for (NSString *name in names) {
            NSString * escapedName = [name stringByReplacingOccurrencesOfString:@" " withString:@"-"];
            [paths addObject:[baseURL URLByAppendingPathComponent:[escapedName stringByAppendingString:@"-01.svg"]]];
            [paths addObject:[baseURL URLByAppendingPathComponent:[escapedName stringByAppendingString:@"-02.svg"]]];
            [paths addObject:[baseURL URLByAppendingPathComponent:[escapedName stringByAppendingString:@"-03.svg"]]];
        }
        dispatch_async(dispatch_get_main_queue(), ^(void){
            [self.autoDrawViewController update:paths];
        });
        
    } failure:^(NSError *error) {
        
        NSLog(@"ERROR: receive matches");
    }];
}

- (void)processMatches:(NSArray*)points outputSize:(CGSize)outputSize success:(void(^)(NSArray*))success failure:(void(^)(NSError*))failure {
    
    NSDictionary *writingGuideDict = @{
                                       @"width": @(outputSize.width),
                                       @"height": @(outputSize.height)
                                       };
    
    NSMutableArray *inkArray = [NSMutableArray array];
    
    NSUInteger delayTime = 1;
    for (NSDictionary *dict in points) {
        
        NSArray *xPoints = [dict objectForKey:@"x"];
        NSArray *yPoints = [dict objectForKey:@"y"];
        
        NSMutableArray *delays = [NSMutableArray array];
        for (NSNumber *point in xPoints) {
            [delays addObject:@(delayTime+=50)];
        }
        
        [inkArray addObject:@[xPoints, yPoints, delays]];
    }
    
    NSDictionary *requestsDict = @{
                                   @"language": @"autodraw",
                                   @"writing_guide": writingGuideDict,
                                   @"ink": inkArray
                                   };
    
    NSDictionary *payloadDict = @{
                                  @"input_type": @0,
                                  @"requests": @[requestsDict]
                                  };
    
    [self.networkClient receiveMatchesWithPayload:payloadDict success:^(id jsonObject) {
        
        if ([jsonObject isKindOfClass: [NSArray class]]) {
            
            NSArray *responseArray = (NSArray *)jsonObject;
            NSArray *array1 = (NSArray *)[responseArray objectAtIndex:1];
            NSArray *array2 = (NSArray *)[array1 firstObject];
            NSArray *names = (NSArray *)[array2 objectAtIndex:1];
            
            success(names);
        }
        
    } failure:^(NSError *error) {
        failure(error);
    }];
}

- (NSWindow *)window {
    if (!_window) {
        _window = [[NSPanel alloc] initWithContentRect:CGRectMake(0, 0, 480, 270) styleMask:NSWindowStyleMaskUtilityWindow + NSWindowStyleMaskClosable + NSWindowStyleMaskTitled backing:NSBackingStoreRetained defer:NO];
        _window.contentViewController = self.autoDrawViewController;
    }
    _window.title = @"Do you mean:";
    return _window;
}

- (AutoDrawViewController *)autoDrawViewController {
    if (!_autoDrawViewController) {
        NSBundle *bundle = [NSBundle bundleForClass:[AutoDrawPlugin class]];
        self.autoDrawViewController = [[AutoDrawViewController alloc] initWithNibName:@"AutoDrawViewController" bundle:bundle];
        [self.autoDrawViewController setDeleteSourceLayers:self.removeOriginalLayers];
        [self.autoDrawViewController setDelegate:self];
    }
    return _autoDrawViewController;
}

- (void)showAutoDrawWindow: (NSWindow*)docWindow bundle:(NSBundle*)bundle  {
    CGSize size = CGSizeMake(480, 150);
    CGRect frame = docWindow.frame;
    CGFloat x = frame.origin.x + (frame.size.width - size.width) / 2;
    CGFloat y = frame.origin.y + (frame.size.height - size.height) / 2;
    CGPoint point = CGPointMake(x, y);
    if (!_window.isVisible) {
        [self.window setFrameOrigin:point];
        [self.window setContentSize:size];
        [docWindow addChildWindow:[self window] ordered:NSWindowAbove];
    }
    [self.window makeKeyWindow];
    
    NSLog(@"Sketch Plugin Launched");
}

-(void)drawViewControllerDidSendRequest:(NSURLRequest*)request {
    
    // import svg
    id svgImporter = [NSClassFromString(@"MSSVGImporter") performSelector:@selector(svgImporter)];
    NSURL *fileURL = request.URL;
    
    
    
    [svgImporter performSelector:@selector(prepareToImportFromURL:) withObject:fileURL];
    
    id layer =[svgImporter performSelector:@selector(importAsLayer)];

    if(!self.layers) {
        return; // TODO Display warning
    }
    // get parent
    id donorLayer = [self.layers objectAtIndex:0];
    NSRect frame = [self getRectForLayers:self.layers method:@"frame"];
    
    if([donorLayer respondsToSelector:@selector(parentGroup)]) {
        id parent = [donorLayer performSelector:@selector(parentGroup)];
        [self adjustThickness:layer withValue:self.thickness];
        [self appendLayer: layer toParent:parent];
        [self setLocation:frame forLayer:layer isAbsolute:false];
    }
    if(self.removeOriginalLayers) {
        [self removeLayers:self.layers];
    }
}


-(void)removeSourceLayers:(BOOL)remove {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary *dict = [[ud objectForKey:@"sketch-autodraw"] mutableCopy] ?: [NSMutableDictionary dictionary];
    dict[@"removeOriginalLayers"] = @(remove);
    [[NSUserDefaults standardUserDefaults] setObject:dict forKey:@"sketch-autodraw"];
    
    self.removeOriginalLayers = remove;
}

@end
