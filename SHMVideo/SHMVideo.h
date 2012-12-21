//
//  SHMVideoBuffer.h
//  iOSDebugCapture
//
//  Created by hayashi on 12/21/12.
//  Copyright (c) 2012 hayashi. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SHMVideo : NSObject
@property (readonly) int width;
@property (readonly) int height;
@property (readonly) int bpp;
@property (readonly) void* sharedMemory;
@property (readonly) void* videoBuffer;
@property (readonly) int numClients;
+(id)server;
+(id)client;
-(id)initWithMode:(int)mode;
-(void*)allocateBuffer;
-(void*)allocateBufferWithSize:(CGSize)size format:(int)bpp;
-(void)updateVideoBuffer:(void**)src;
@end
