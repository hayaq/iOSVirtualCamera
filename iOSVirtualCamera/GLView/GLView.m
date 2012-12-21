//
//  GLView.m
//  QQQ
//
//  Created by hayashi on 2/29/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//
#import "GLView.h"
#import <OpenGL/OpenGL.h>
#import <OpenGL/glu.h>
#import <OpenGL/glext.h>

@interface GLView ()
@end

@implementation GLView

@synthesize delegate;
@synthesize acceptFileTypes = _acceptFileTypes;

-(id)initWithFrame:(NSRect)frameRect{
	NSOpenGLPixelFormatAttribute attributes[] = {
		NSOpenGLPFADoubleBuffer,
		NSOpenGLPFAAccelerated,
		NSOpenGLPFAColorSize , 32,
		NSOpenGLPFADepthSize , 32,
		0
	};
	NSOpenGLPixelFormat* pixelFormat = [[[NSOpenGLPixelFormat alloc] initWithAttributes:attributes] autorelease];
	self = [super initWithFrame:frameRect pixelFormat:pixelFormat];
	[self setWantsBestResolutionOpenGLSurface:NO];
	[self bindContext];
	return self;
}

-(BOOL)acceptFirstResponder{
    return YES;
}

-(void)awakeFromNib{
	[self bindContext];
}

-(void)bindContext{
	[[self openGLContext] makeCurrentContext]; 
}

-(void)requestRender{
	[self setNeedsDisplay:YES];
}

-(NSOpenGLContext*)createShareContext{
	return [[[NSOpenGLContext alloc] initWithFormat:self.pixelFormat shareContext:[self openGLContext]] autorelease];
}

-(GLuint)initTextureWithSize:(CGSize)size format:(int)fmt{
	int w = (int)size.width;
	int h = (int)size.height;
	GLuint format = GL_LUMINANCE;
	if( fmt == 2 ){ format = GL_LUMINANCE_ALPHA; }
	else if( fmt == 3 ){ format = GL_RGB; }
	else if( fmt == 4 ){ format = GL_RGBA; }
	GLuint textureId = 0;
	glGenTextures(1,&textureId);
	glBindTexture(GL_TEXTURE_2D,textureId);
	glTexImage2D(GL_TEXTURE_2D,0,format,w, h, 0, format,GL_UNSIGNED_BYTE,NULL);
	glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_WRAP_S,GL_CLAMP_TO_EDGE);
	glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_WRAP_T,GL_CLAMP_TO_EDGE);
	glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,GL_LINEAR);
	glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,GL_LINEAR);
	glBindTexture(GL_TEXTURE_2D,0);
	return textureId;
}

-(void)updateTexture:(GLuint)textureId withSize:(CGSize)size format:(int)fmt buffer:(uint8_t*)buffer{
	int w = (int)size.width;
	int h = (int)size.height;
	GLuint format = GL_LUMINANCE;
	if( fmt == 2 ){ format = GL_LUMINANCE_ALPHA; }
	else if( fmt == 3 ){ format = GL_RGB; }
	else if( fmt == 4 ){ format = GL_RGBA; }
	glBindTexture(GL_TEXTURE_2D,textureId);
	glTexSubImage2D(GL_TEXTURE_2D,0,0,0,w,h,format,GL_UNSIGNED_BYTE,buffer);
	glBindTexture(GL_TEXTURE_2D,0);
}

-(void)drawRect:(NSRect)dirtyRect
{
	[[self openGLContext] makeCurrentContext]; 
	if( [delegate respondsToSelector:@selector(glViewDrawFrame)] ){
		[delegate performSelector:@selector(glViewDrawFrame)];
	}else{
		glClearColor(0.8f, 0.8f, 0.8f, 1);
		glClear(GL_COLOR_BUFFER_BIT|GL_DEPTH_BUFFER_BIT);
	}
	[[self openGLContext] flushBuffer];	
	[super drawRect:dirtyRect];
}

-(void)flush{
	[[self openGLContext] flushBuffer];	
}

@end
