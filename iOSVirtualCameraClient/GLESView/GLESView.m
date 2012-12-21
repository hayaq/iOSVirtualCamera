//
//  GLView.m
//  iOSVirtualCamera
//
//  Created by hayashi on 12/22/12.
//  Copyright (c) 2012 hayashi. All rights reserved.
//

#import "GLESView.h"
#import <QuartzCore/QuartzCore.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>

@interface GLESView(){
	EAGLContext *context;
	GLuint       frameBuffer;
	GLuint       renderBuffer;
	GLuint		 depthRenderbuffer;
	GLint        width;
	GLint		 height;
}
@end

@implementation GLESView

+ (Class) layerClass{
	return [CAEAGLLayer class];
}

- (id)init{
    self = [super init];
    if (self) {
		context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES1 ];
		[EAGLContext setCurrentContext:context];
		CAEAGLLayer *layer = (CAEAGLLayer*)self.layer;
		layer.contentsScale = [UIScreen mainScreen].scale;
		glGenFramebuffers(1, &frameBuffer);
		glBindFramebuffer(GL_FRAMEBUFFER, frameBuffer);
		glGenRenderbuffers(1, &renderBuffer);
		glBindRenderbuffer(GL_RENDERBUFFER, renderBuffer);
		glGenRenderbuffers(1, &depthRenderbuffer);
		glBindRenderbuffer(GL_RENDERBUFFER, depthRenderbuffer);
	}
    return self;
}

- (id)initWithFrame:(CGRect)frame{
	self = [super initWithFrame:frame];
	if (self) {
		context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES1 ];
		[EAGLContext setCurrentContext:context];
		CAEAGLLayer *layer = (CAEAGLLayer*)self.layer;
		layer.contentsScale = [UIScreen mainScreen].scale;
		glGenFramebuffers(1, &frameBuffer);
		glBindFramebuffer(GL_FRAMEBUFFER, frameBuffer);
		glGenRenderbuffers(1, &renderBuffer);
		glBindRenderbuffer(GL_RENDERBUFFER, renderBuffer);
		glGenRenderbuffers(1, &depthRenderbuffer);
		glBindRenderbuffer(GL_RENDERBUFFER, depthRenderbuffer);
		[self resizeFrameBuffer];
	}
	return self;
}

- (BOOL)resizeFromLayer:(CAEAGLLayer *)layer
{
	[self resizeFrameBuffer];
    return YES;
}

-(void)beginRendering
{
	[EAGLContext setCurrentContext:context];
	glBindFramebuffer(GL_FRAMEBUFFER, frameBuffer);
	glViewport(0,0,width,height);
	glClearDepthf(1.f);
	glClearColor(1.f, 1.f, 1.f, 1.f);
    glClear(GL_COLOR_BUFFER_BIT|GL_DEPTH_BUFFER_BIT);
}

-(void)endRendering
{
	glFlush();
	glBindRenderbuffer(GL_RENDERBUFFER, renderBuffer);
	[context presentRenderbuffer:GL_RENDERBUFFER];
}

-(void)resizeFrameBuffer{
	if( context == NULL ){ return; }
	CAEAGLLayer *layer = (CAEAGLLayer*)self.layer;
	glBindFramebuffer(GL_FRAMEBUFFER, frameBuffer);
	glBindRenderbuffer(GL_RENDERBUFFER, renderBuffer);
	[context renderbufferStorage:GL_RENDERBUFFER fromDrawable:layer];
	glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, renderBuffer);
	glGetRenderbufferParameteriv(GL_RENDERBUFFER,GL_RENDERBUFFER_WIDTH,&width);
	glGetRenderbufferParameteriv(GL_RENDERBUFFER,GL_RENDERBUFFER_HEIGHT,&height);
	
	glBindRenderbuffer(GL_RENDERBUFFER, depthRenderbuffer);
	glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT,GL_RENDERBUFFER, depthRenderbuffer);
	glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT16, width, height);
}

@end
