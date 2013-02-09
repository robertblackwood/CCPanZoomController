//
//  HelloWorldLayer.m
//  CCPanZoomController
//
//  Created by Robert Blackwood on 7/31/11.
//  Copyright Mobile Bros 2011. All rights reserved.
//


// Import the interfaces
#import "HelloWorldLayer.h"

// HelloWorldLayer implementation
@implementation HelloWorldLayer

+(CCScene *) scene
{
	// 'scene' is an autorelease object.
	CCScene *scene = [CCScene node];
	
	// 'layer' is an autorelease object.
	HelloWorldLayer *layer = [HelloWorldLayer node];
	
	// add layer as a child to scene
	[scene addChild: layer];
	
	// return the scene
	return scene;
}

// on "init" you need to initialize your instance
-(id) init
{
	// always call "super" init
	// Apple recommends to re-assign "self" with the "super" return value
	if( (self=[super init])) 
    {
        // our bounding rect
        CGRect boundingRect = CGRectMake(0, 0, 964, 700);
        
        // background
        CCSprite *background = [CCSprite spriteWithFile:@"background.png"];
        background.anchorPoint = ccp(0,0);
        [self addChild:background];
		
		// create and initialize a Label
		CCLabelTTF *label = [CCLabelTTF labelWithString:@"Hello World, try panning and zooming using drag and pinch" 
                                               fontName:@"Marker Felt" 
                                               fontSize:32];

	
		// position the label on the center of the bounds
		label.position =  ccp(boundingRect.size.width/2 , boundingRect.size.height/2);
        label.color = ccWHITE;
		
		// add the label as a child to this Layer
		[self addChild: label];
        
        // the pan/zoom controller
        _controller = [[CCPanZoomController controllerWithNode:self] retain];
        _controller.boundingRect = boundingRect;
        _controller.zoomOutLimit = _controller.optimalZoomOutLimit;
        _controller.zoomInLimit = 2.0f;
        
        [_controller enableWithTouchPriority:0 swallowsTouches:YES];
	}
	return self;
}

// on "dealloc" you need to release all your retained objects
- (void) dealloc
{
	// disable the controller and release the controller
    [_controller disable];
    [_controller release];
	
	// don't forget to call "super dealloc"
	[super dealloc];
}
@end
