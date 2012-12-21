//
//  ViewController.m
//  iOSVirtualCameraClient
//
//  Created by hayashi on 12/22/12.
//  Copyright (c) 2012 hayashi. All rights reserved.
//
#import "ViewController.h"
#import "SHMVideo.h"
#import "GLESView.h"
#import <OpenGLES/ES1/gl.h>
#import <QuartzCore/QuartzCore.h>

@interface ViewController (){
	SHMVideo *shmVideo;
	GLESView *glView;
	uint32_t  textureId;
}
@end

@implementation ViewController

#if TARGET_IPHONE_SIMULATOR

-(void)viewDidAppear:(BOOL)animated{
	[super viewDidAppear:animated];
	
	if( !glView ){
		
		shmVideo = [[SHMVideo client] retain];
		if( ![shmVideo allocateBuffer] ){
			return;
		}
		
		int cw = shmVideo.width;
		int ch = shmVideo.height;
		int vw = self.view.frame.size.width;
		int vh = self.view.frame.size.height;
		int gw = vw;
		int gh = vw*cw/ch;
		if( gh > vh ){
			gh = vh;
			gw = vh*ch/cw;
		}
		CGRect frame = CGRectMake(0.5*(vw-gw), 0.5*(vh-gh), gw, gh);
		glView = [[GLESView alloc] initWithFrame:frame];
		[self.view addSubview:glView];
		[glView release];
		
		
		glGenTextures(1,&textureId);
		glBindTexture(GL_TEXTURE_2D,textureId);
		if( shmVideo.bpp == 1 ){
			glTexImage2D(GL_TEXTURE_2D,0,GL_LUMINANCE,cw, ch, 0,
						 GL_LUMINANCE, GL_UNSIGNED_BYTE, shmVideo.videoBuffer);
		}else if( shmVideo.bpp == 4 ){
			glTexImage2D(GL_TEXTURE_2D,0,GL_RGBA,cw, ch, 0,
						 GL_BGRA, GL_UNSIGNED_BYTE, shmVideo.videoBuffer);
		}
		glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_WRAP_S,GL_CLAMP_TO_EDGE);
		glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_WRAP_T,GL_CLAMP_TO_EDGE);
		glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,GL_LINEAR);
		glBindTexture(GL_TEXTURE_2D,0);
		
		CADisplayLink *displayLink = [[UIScreen mainScreen] displayLinkWithTarget:self selector:@selector(displayCallback:)];
		[displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
	}
}

-(void)displayCallback:(CADisplayLink*)displayLink{
	[glView beginRendering];
	
	glEnable(GL_TEXTURE_2D);
	glBindTexture(GL_TEXTURE_2D,textureId);
	
	if( shmVideo.bpp == 1 ){
		glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, shmVideo.width, shmVideo.height,
						GL_LUMINANCE, GL_UNSIGNED_BYTE, shmVideo.videoBuffer);
	}else if( shmVideo.bpp == 4 ){
		glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, shmVideo.width, shmVideo.height,
						GL_BGRA, GL_UNSIGNED_BYTE, shmVideo.videoBuffer);
	}
	const float v[8] = { -1, -1, +1, -1, +1, +1, -1, +1 };
	const float t[8] = {  +1,  1, +1,  0,  0,  0, 0,  1 };
	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();
	glMatrixMode(GL_MODELVIEW);
	glLoadIdentity();
	glColor4f(1, 1, 1, 1);
	glEnableClientState(GL_VERTEX_ARRAY);
	glEnableClientState(GL_TEXTURE_COORD_ARRAY);
	glVertexPointer(2, GL_FLOAT, 0, v);
	glTexCoordPointer(2, GL_FLOAT, 0, t);
	glDrawArrays(GL_TRIANGLE_FAN, 0, 4);
	glDisableClientState(GL_VERTEX_ARRAY);
	glDisableClientState(GL_TEXTURE_COORD_ARRAY);
	glBindTexture(GL_TEXTURE_2D,0);
	glDisable(GL_TEXTURE_2D);
	
	[glView endRendering];
}

#else
#warning This target is only valid for iOS simulator.
#endif

@end
