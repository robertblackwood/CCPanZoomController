/* Copyright (c) 2011 Robert Blackwood
 * 
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

#import "CCPanZoomController.h"

//Special scale action so view stays centered on a given point
@interface CCPanZoomControllerScale : CCScaleTo
{
    CCPanZoomController *_controller;
    CGPoint _point;
}

+(id) actionWithDuration:(ccTime)duration scale:(float)s controller:(CCPanZoomController*)controller point:(CGPoint)pt;
-(id) initWithDuration:(ccTime)duration scale:(float)s controller:(CCPanZoomController*)controller point:(CGPoint)pt;

@end

@interface CCPanZoomController (Private)
- (void) updateTime:(ccTime)dt;
- (CGPoint) boundPos:(CGPoint)pos;
- (void) handleDoubleTapAt:(CGPoint)pt;

- (void) beginScroll:(CGPoint)pos;
- (void) moveScroll:(CGPoint)pos;
- (void) endScroll:(CGPoint)pos;

- (void) beginZoom:(CGPoint)pt otherPt:(CGPoint)pt2;
- (void) moveZoom:(CGPoint)pt otherPt:(CGPoint)pt2;
- (void) endZoom:(CGPoint)pt otherPt:(CGPoint)pt2;
@end

//Will return value between 0 and 1, think of it as a percentage of rotation
static inline float vectorsDeviation(CGPoint v1, CGPoint v2)
{
    return ccpLength(ccpSub(ccpNormalize(v1), ccpNormalize(v2)))/2.0f;
}

#define GET_PINCH_PTS(touches, pt1, pt2)\
UITouch *touch1 = [touches objectAtIndex:0];\
UITouch *touch2 = [touches objectAtIndex:1];\
CGPoint pt1 = [touch1 locationInView:[touch view]];\
CGPoint pt2 = [touch2 locationInView:[touch view]]

@implementation CCPanZoomControllerScale

+(id) actionWithDuration:(ccTime)duration 
                   scale:(float)s 
              controller:(CCPanZoomController*)controller
                   point:(CGPoint)pt
{
    return [[[self alloc] initWithDuration:duration scale:s controller:controller point:pt] autorelease];
}

-(id) initWithDuration:(ccTime)duration 
                 scale:(float)s 
            controller:(CCPanZoomController*)controller
                 point:(CGPoint)pt
{
    [super initWithDuration:duration scale:s];
    _controller = [controller retain];
    _point = pt;
    return self;
}

-(void) update: (ccTime) t
{
    [super update:t];
    
    //use damping, but make sure we get there
    if (t < 1.0f)
        [_controller centerOnPoint:_point damping:_controller.zoomCenteringDamping];
    else
        [_controller centerOnPoint:_point];
}

-(void) dealloc
{
    [_controller release];
    [super dealloc];
}

@end

@implementation CCPanZoomController

@synthesize centerOnPinch = _centerOnPinch;
@synthesize zoomOnDoubleTap = _zoomOnDoubleTap;
@synthesize zoomRate = _zoomRate;
@synthesize zoomInLimit = _zoomInLimit;
@synthesize zoomOutLimit = _zoomOutLimit;
@synthesize scrollRate = _scrollRate;
@synthesize scrollDamping = _scrollDamping;
@synthesize zoomCenteringDamping = _zoomCenteringDamping;
@synthesize pinchDamping = _pinchDamping;
@synthesize pinchDistanceThreshold = _pinchDistanceThreshold;
@synthesize doubleTapZoomDuration = _doubleTapZoomDuration;

+ (id) controllerWithNode:(CCNode*)node
{
	return [[[self alloc] initWithNode:node] autorelease];
}

- (id) initWithNode:(CCNode*)node;
{
	[super init];
	
	_touches = [[NSMutableArray alloc] init];
	
    //use the content size to determine the default scrollable area
	_node = node;
    _tr = ccp(0, 0);
    _bl = ccp(node.contentSize.width, node.contentSize.height);
    
    //use the screen size to determine the default window
    CGSize winSize = [[CCDirector sharedDirector] winSize];
	_winTr.x = winSize.width;
	_winTr.y = winSize.height;
    _winBl.x = 0;
    _winBl.y = 0;
    
    //default props
    _centerOnPinch = YES;
    _zoomOnDoubleTap = YES;
    _zoomRate = 1/500.0f;
    _zoomInLimit = 1.0f;
    _zoomOutLimit = 0.5f;
    _scrollRate = 9;
    _scrollDamping = .85;
    _zoomCenteringDamping = .1;
    _pinchDamping = .9;
    _pinchDistanceThreshold = 3;
    _doubleTapZoomDuration = .2;
	
	return self;
}

- (void) dealloc
{
	[_touches release];
	[super dealloc];
}

- (void) setBoundingRect:(CGRect)rect
{	
    _bl = rect.origin;
	_tr = ccpAdd(_bl, ccp(rect.size.width, rect.size.height));
}

-(CGRect) boundingRect
{
    CGPoint size = ccpSub(_tr, _bl);
    return CGRectMake(_bl.x, _bl.y, size.x, size.y);
}

- (void) setWindowRect:(CGRect)rect
{	
    _winBl = rect.origin;
	_winTr = ccpAdd(_winBl, ccp(rect.size.width, rect.size.height));
}

-(CGRect) windowRect
{
    CGPoint size = ccpSub(_winTr, _winBl);
    return CGRectMake(_winBl.x, _winBl.y, size.x, size.y);
}

-(float) optimalZoomOutLimit
{
    //default to 100%
    float xMaxZoom = 1;
    float yMaxZoom = 1;

    float width = (_tr.x - _bl.x);
    float height = (_tr.y - _bl.y);
    
    //don't divide by zero
    if (width)
        xMaxZoom = (_winTr.x - _winBl.x) / width;
    if (height)
        yMaxZoom = (_winTr.y - _winBl.y) / height;
    
    //give the best out of the 2 zooms
    return (xMaxZoom > yMaxZoom) ? xMaxZoom : yMaxZoom;
}

- (CGPoint) boundPos:(CGPoint)pos
{
	float scale = _node.scale;

    //Correct for anchor
    CGPoint anchor = ccp(_node.contentSize.width*_node.anchorPoint.x,
                         _node.contentSize.height*_node.anchorPoint.y);
    anchor = ccpMult(anchor, (1.0f - scale));
    
    //Calculate corners
    CGPoint topRight = ccpAdd(ccpSub(ccpMult(_tr, scale), _winTr), anchor);
    CGPoint bottomLeft = ccpSub(ccpAdd(ccpMult(_bl, scale), _winBl), anchor);
    
    //bound x
	if (pos.x > bottomLeft.x)
		pos.x = bottomLeft.x;
	else if (pos.x < -topRight.x)
		pos.x = -topRight.x;
	
    //bound y
	if (pos.y > bottomLeft.y)
		pos.y = bottomLeft.y;
	else if (pos.y < -topRight.y)
		pos.y = -topRight.y;
	
	return pos;
}

- (void) updatePosition:(CGPoint)pos
{	
    //user interface to boundPos basically
	pos = [self boundPos:pos];
    
    //debug
    //NSLog(@"Position set to: (%.2f, %.2f)", pos.x, pos.y);
    
	[_node setPosition:pos];
}

- (void) enableWithTouchPriority:(int)priority swallowsTouches:(BOOL)swallowsTouches
{
#if (COCOS2D_VERSION < 0x00020000)
	[[CCTouchDispatcher sharedDispatcher] addTargetedDelegate:self
													 priority:priority 
											  swallowsTouches:swallowsTouches];
	[[CCScheduler sharedScheduler] scheduleSelector:@selector(updateTime:) forTarget:self interval:0 paused:NO];
#else
    [[[CCDirector sharedDirector] touchDispatcher] addTargetedDelegate:self
                                                              priority:priority
                                                       swallowsTouches:swallowsTouches];
    [[[CCDirector sharedDirector] scheduler] scheduleSelector:@selector(updateTime:) forTarget:self interval:0 paused:NO];
#endif
}

-(void) disable
{
#if (COCOS2D_VERSION < 0x00020000)
	[[CCTouchDispatcher sharedDispatcher] removeDelegate:self];
	[[CCScheduler sharedScheduler] unscheduleSelector:@selector(updateTime:) forTarget:self];
#else
    [[[CCDirector sharedDirector] touchDispatcher]removeDelegate:self];
    [[[CCDirector sharedDirector] scheduler] unscheduleSelector:@selector(updateTime:) forTarget:self];
#endif
    
    //Clean up any stray touches
    for (UITouch *touch in _touches)
        [self ccTouchCancelled:touch withEvent:nil];
}

- (void) updateTime:(ccTime)dt
{    
    float degrade = dt*(_momentum.x*_scrollRate);
    _momentum.x -= degrade;
    
    degrade = dt*(_momentum.y*_scrollRate);
    _momentum.y -= degrade;
    
    if (![_touches count])
    {
        // Apply momentum
        [self updatePosition:ccpAdd(_node.position, ccpMult(_momentum, _scrollDamping))];
    }
}

-(BOOL) ccTouchBegan:(UITouch*)touch withEvent:(UIEvent *)event
{	    
	[_touches addObject:touch];
	
	BOOL multitouch = [_touches count] > 1;
	
	if (multitouch)
	{
        //reset history so auto scroll doesn't happen
        _momentum = CGPointZero;
        
        //end the first touche's panning
		[self endScroll:_firstTouch];
        
        //get the 2 points
        GET_PINCH_PTS(_touches, pt1, pt2);

        //setup to zoom
		[self beginZoom:pt1 otherPt:pt2];		
	}
	else 
    {
        //Start scrolling
        [self beginScroll:[_node convertTouchToNodeSpace:touch]];
    }
	
	return YES;
}

-(void) ccTouchMoved:(UITouch*)touch withEvent:(UIEvent *)event
{
    //pinching case (zooming)
	BOOL multitouch = [_touches count] > 1;
	if (multitouch)
	{
        //get the 2 points
        GET_PINCH_PTS(_touches, pt1, pt2);
		
        //zoom it!
		[self moveZoom:pt1 otherPt:pt2];
	}
	else
	{
        //pan around
		[self moveScroll:[_node convertTouchToNodeSpace:touch]];
	}
}

- (void)ccTouchEnded:(UITouch*)touch withEvent:(UIEvent *)event
{
    //pinching case (zooming)
	BOOL multitouch = [_touches count] > 1;
	if (multitouch)
	{
        //get the 2 points, UITouch* touch1 and touch2 are declared here too
        GET_PINCH_PTS(_touches, pt1, pt2);
		
        //doesn't really do anything right now
		[self endZoom:pt1 otherPt:pt2];
		
		//which touch remains?
		if (touch == touch2)
			[self beginScroll:[_node convertTouchToNodeSpace:touch1]];
		else
			[self beginScroll:[_node convertTouchToNodeSpace:touch2]];
	}
    
    //one finger case (panning)
	else
	{		
        //end scroll
        CGPoint pt = [_node convertTouchToNodeSpace:touch];
		[self endScroll:pt];
        
        //handle double-tap zooming
        if (_zoomOnDoubleTap && [touch tapCount] == 2)
            [self handleDoubleTapAt:pt];
	}
	
	[_touches removeObject:touch];
}

- (void)ccTouchCancelled:(UITouch*)touch withEvent:(UIEvent *)event
{
	[self ccTouchEnded:touch withEvent:event];
}

- (void) handleDoubleTapAt:(CGPoint)pt
{
    float mid = (_zoomInLimit + _zoomOutLimit)/2;
    
    //closer to being zoomed out? then zoom in, else zoom out
    if (_node.scale < mid)
        [self zoomInOnPoint:pt duration:_doubleTapZoomDuration];
    else
        [self zoomOutOnPoint:pt duration:_doubleTapZoomDuration];
}

- (void) zoomInOnPoint:(CGPoint)pt duration:(float)duration
{
    [self zoomOnPoint:pt duration:duration scale:_zoomInLimit];
}

- (void) zoomOutOnPoint:(CGPoint)pt duration:(float)duration
{
    [self zoomOnPoint:pt duration:duration scale:_zoomOutLimit];
}

- (void) zoomOnPoint:(CGPoint)pt duration:(float)duration scale:(float)scale
{
    [_node runAction:[CCPanZoomControllerScale actionWithDuration:duration scale:scale controller:self point:pt]];
}


- (void) beginScroll:(CGPoint)pos
{
    //reset
	_momentum = CGPointZero;
	_firstTouch = pos;
}

- (void) moveScroll:(CGPoint)pos
{
    // diff
	pos = ccpSub(pos, _firstTouch);
    
    // apply momentum
    _momentum.x += pos.x;
    _momentum.y += pos.y;

    //dampen value
	pos = ccpMult(pos, _scrollDamping * _node.scale);
    
    //debug
    //NSLog(@"Moving to: (%.2f, %.2f)", pos.x, pos.y);
	
	[self updatePosition:ccpAdd(_node.position, pos)];
}

- (void) endScroll:(CGPoint)pos
{
}

- (void) beginZoom:(CGPoint)pt otherPt:(CGPoint)pt2
{
    //initialize our zoom vars
	_firstLength = ccpDistance(pt, pt2);
	_oldScale = _node.scale;
    
    //get the mid point of pinch
    _firstTouch = [_node convertToNodeSpace:[[CCDirector sharedDirector] convertToGL:ccpMidpoint(pt, pt2)]];
}

- (void) moveZoom:(CGPoint)pt otherPt:(CGPoint)pt2
{
    //what's the difference in length since we began
	float length = ccpDistance(pt, pt2);	
	float diff = (length-_firstLength);
    
    //ignore small movements
    if (fabs(diff) < _pinchDistanceThreshold)
        return;

	//calculate new scale
	float factor = diff * _zoomRate;
	float scaleTo = (_oldScale + factor);
    float absScaleTo = fabs(scaleTo);
    float mult = absScaleTo/scaleTo;
    
    //paranoia
    if (!_oldScale)
        _oldScale = 0.001;
    
    //dampen
    float newScale = _oldScale*mult*pow(absScaleTo/_oldScale, _pinchDamping);
	
    if (isnormal(newScale))
    {
        //bound scale
        if (newScale > _zoomInLimit)
            newScale = _zoomInLimit;
        else if (newScale < _zoomOutLimit)
            newScale = _zoomOutLimit;
        
        //set the new scale
        _node.scale = newScale;
        
        //NSLog(@"Scale:%.2f", newScale);
        
        //center on midpoint of pinch
        if (_centerOnPinch)
            [self centerOnPoint:_firstTouch damping:_zoomCenteringDamping];
        else
            [self updatePosition:_node.position];
    }
    else
        NSLog(@"CCPanZoomController - Bad scale!");
}

- (void) centerOnPoint:(CGPoint)pt
{
    [self centerOnPoint:pt damping:1.0f];
}

- (void) centerOnPoint:(CGPoint)pt damping:(float)damping
{
    //calc the difference between the window middle and the pt, apply the damping
    CGPoint mid = [_node convertToNodeSpace:ccpMidpoint(_winTr, _winBl)];
    CGPoint diff = ccpMult(ccpSub(mid, pt), damping);
    CGPoint oldPos = _node.position;
    CGPoint newPos = ccpAdd(oldPos, diff);
    
    //NSLog(@"Centering on: (%.2f, %.2f)", newPos.x, newPos.y);
            
    [self updatePosition:newPos];
}

- (void) centerOnPoint:(CGPoint)pt duration:(float)duration rate:(float)rate
{
    //calc the difference between the window middle and the pt
    CGPoint mid = [_node convertToNodeSpace:ccpMidpoint(_winTr, _winBl)];
    CGPoint diff = ccpSub(mid, pt);
    
    //get the final destination
    CGPoint final = [self boundPos:ccpAdd(_node.position, diff)];
    
    //move to new position, with an ease
    id moveTo = [CCMoveTo actionWithDuration:duration position:final];
    id ease = [CCEaseOut actionWithAction:moveTo rate:rate];
    
    [_node runAction:ease];
}

- (void) endZoom:(CGPoint)pt otherPt:(CGPoint)pt2
{
	//[self moveZoom:pt otherPt:pt2];
}

@end
