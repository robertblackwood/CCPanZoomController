//
//  HelloWorldLayer.h
//  CCPanZoomController
//
//  Created by Robert Blackwood on 7/31/11.
//  Copyright Mobile Bros 2011. All rights reserved.
//


// When you import this file, you import all the cocos2d classes
#import "cocos2d.h"
#import "CCPanZoomController.h"

// HelloWorldLayer
@interface HelloWorldLayer : CCLayer
{
    CCPanZoomController *_controller;
}

// returns a CCScene that contains the HelloWorldLayer as the only child
+(CCScene *) scene;

@end
