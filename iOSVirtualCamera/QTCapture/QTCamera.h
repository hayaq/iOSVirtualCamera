//
//  QTCapture.h
//  QTCapture
//
//  Created by hayashi on 9/13/12.
//  Copyright (c) 2012 hayashi. All rights reserved.
//

#import <Foundation/Foundation.h>

@class QTCamera;
typedef void (*QTCameraCallback)(QTCamera *capture, void **buffers, void *context);

@interface QTCamera : NSObject
@property (nonatomic,readonly) int width;
@property (nonatomic,readonly) int height;
@property (nonatomic,readonly) int bpp;
-(void)start;
-(void)stop;
-(void)reset;
-(void)setInputSource:(id)source;
-(void)setFrameRate:(int)fps;
-(void)setCaptureSize:(NSSize)size format:(int)bpp;
-(void)setCaptureCallback:(QTCameraCallback)callback context:(void*)context;
-(void)nextFrame;
-(void)prevFrame;
-(BOOL)isRunning;
+(NSArray*)enumerateCameras;
@end


