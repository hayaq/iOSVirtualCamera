//
//  AppDelegate.m
//  iOSVirtualCamera
//
//  Created by hayashi on 12/21/12.
//  Copyright (c) 2012 hayashi. All rights reserved.
//
#import <OpenGL/OpenGL.h>
#import "AppDelegate.h"
#import "QTCamera.h"
#import "GLView.h"
#import "SHMVideo.h"

static const int fpsList[] = { 0, 1, 10, 15, 24, 30 };
static const int captureSizeList[][2] = { {320,240},{480,360},{640,480} };

@interface AppDelegate() <GLViewDelegate>{
	SHMVideo *shmVideo;
	GLView   *glView;
	QTCamera *camera;
	NSSize    captureSize;
	int       captureFormat;
	BOOL      captureFormatChanged;
	uint32_t  textureId;
	NSOpenGLContext *shareContext;
	IBOutlet NSTextField   *clientInfoLabel;
	IBOutlet NSPopUpButton *inputSourceSelect;
	IBOutlet NSPopUpButton *fpsSelect;
	IBOutlet NSPopUpButton *captureSizeSelect;
	IBOutlet NSPopUpButton *captureFormatSelect;
}
@end

static void CameraCallback(QTCamera *capture, void **buffers, void *context);

@implementation AppDelegate

- (void)dealloc{
    [super dealloc];
}

-(BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender{
	return YES;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	captureFormat = 1;
	captureSize = NSMakeSize(640,480);
	
	camera = [[QTCamera alloc] init];
	[camera setInputSource:@0];
	[camera setCaptureSize:captureSize format:captureFormat];
	[camera setFrameRate:30];
	[camera setCaptureCallback:CameraCallback context:self];
	
	glView = [[GLView alloc] initWithFrame:NSMakeRect(0,0,240,180)];
	glView.delegate = self;
	[self.window.contentView addSubview:glView];
	[glView release];
	
	textureId = [glView initTextureWithSize:captureSize format:captureFormat];
	shareContext = [[glView createShareContext] retain];
	
	NSArray *deviceList = [QTCamera enumerateCameras];
	if( [deviceList count] ){
		[inputSourceSelect addItemsWithTitles:deviceList];
	}
	[inputSourceSelect addItemWithTitle:@"Movie file"];
	
	for (int i=0; i<sizeof(fpsList)/sizeof(int);i++) {
		[fpsSelect addItemWithTitle:[NSString stringWithFormat:@"%d",fpsList[i]]];
	}
	[fpsSelect setTitle:@"30"];
	
	for (int i=0; i<sizeof(captureSizeList)/(sizeof(int)*2);i++) {
		[captureSizeSelect addItemWithTitle:[NSString stringWithFormat:@"%dx%d",
											 captureSizeList[i][0],captureSizeList[i][1]]];
	}
	[captureSizeSelect setTitle:@"640x480"];
	
	[captureFormatSelect addItemsWithTitles:@[@"YUV",@"BGRA"]];
	[[captureFormatSelect itemAtIndex:0] setTag:1];
	[[captureFormatSelect itemAtIndex:1] setTag:4];
	[captureFormatSelect setTag:captureFormat];
	
	[camera start];
	
	shmVideo = [[SHMVideo server] retain];
}

- (void)applicationWillTerminate:(NSNotification *)notification{
	[shmVideo release];
	[camera stop];
}

- (void)setCameraInputSource:(id)source{
	[camera stop];
	[camera setInputSource:source];
	[camera start];
}

- (void)glViewDrawFrame{
	glClearColor(0, 0, 0, 1);
	glClear(GL_COLOR_BUFFER_BIT);
	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();
	glMatrixMode(GL_MODELVIEW);
	glLoadIdentity();
	glColor4f(1, 1, 1, 1);
	glEnable(GL_TEXTURE_2D);
	glBindTexture(GL_TEXTURE_2D,textureId);
	glBegin(GL_QUADS);
	glTexCoord2f(0, 1); glVertex2f(-1, -1);
	glTexCoord2f(1, 1); glVertex2f(+1, -1);
	glTexCoord2f(1, 0); glVertex2f(+1, +1);
	glTexCoord2f(0, 0); glVertex2f(-1, +1);
	glEnd();
	glBindTexture(GL_TEXTURE_2D,0);
	glDisable(GL_TEXTURE_2D);
	
	[clientInfoLabel setStringValue:[NSString stringWithFormat:@"Client: %d",[shmVideo numClients]]];
}

- (void)captureFrame:(void**)buffers{
	if( !shareContext ){ return; }
	
	if( captureFormatChanged || !shmVideo.sharedMemory ){
		[shmVideo allocateBufferWith:NSMakeSize(camera.width,camera.height) format:camera.bpp];
	}
	[shmVideo updateVideoBuffer:buffers];
	
	[shareContext makeCurrentContext];
	glBindTexture(GL_TEXTURE_2D,textureId);
	if( camera.bpp == 1 ){
		if( captureFormatChanged ){
			glTexImage2D(GL_TEXTURE_2D, 0, GL_LUMINANCE, camera.width, camera.height,
						 0, GL_LUMINANCE, GL_UNSIGNED_BYTE, buffers[0]);
		}else{
			glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, camera.width, camera.height,
							GL_LUMINANCE, GL_UNSIGNED_BYTE, buffers[0]);
		}
	}else if( camera.bpp == 4 ){
		if( captureFormatChanged ){
			glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, camera.width, camera.height,
						 0, GL_BGRA, GL_UNSIGNED_BYTE, buffers[0]);
		}else{
			glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, camera.width, camera.height,
							GL_BGRA, GL_UNSIGNED_BYTE, buffers[0]);
		}
	}
	captureFormatChanged = NO;
	glBindTexture(GL_TEXTURE_2D,0);
	glFlush();
	[glView requestRender];
}

- (void)dropFile:(NSString *)path{
	[camera setInputSource:path];
	[camera start];
}

- (void)keyDown:(NSEvent*)event{
	if( [event keyCode] == 53 ){
		[[NSApplication sharedApplication] terminate:self];
	}else if( [event keyCode] == 123 ){
		[camera prevFrame];
	}else if( [event keyCode] == 124 ){
		[camera nextFrame];
	}else if( [event keyCode] == 49 ){
		if( [camera isRunning] ){
			[camera stop];
		}else{
			[camera start];
		}
	}else if( [event keyCode]==15 ){
		[camera stop];
		[camera reset];
		[camera start];
	}
}

-(IBAction)inputSourceChanged:(id)sender{
	NSInteger index = [inputSourceSelect indexOfSelectedItem];
	if( index == [inputSourceSelect numberOfItems]-1 ){
		NSString *path = [self selectOpenPath];
		if( path ){
			[self setCameraInputSource:path];
		}
	}else{
		[self setCameraInputSource:[NSNumber numberWithInteger:index]];
	}
}

-(NSString*)selectOpenPath{
	NSOpenPanel *panel = [NSOpenPanel openPanel];
	[panel setAllowsMultipleSelection:NO];
	[panel setAllowedFileTypes:@[@"mov",@"m4v",@"mp4"]];
	if( [panel runModal] != NSOKButton ){ return nil; }
	return [[panel URL] path];
}

-(IBAction)fpsChanged:(id)sender{
	[camera stop];
	[camera setFrameRate:fpsList[[fpsSelect indexOfSelectedItem]]];
	[camera start];
}

-(IBAction)captureSizeChanged:(id)sender{
	const int *size = captureSizeList[[captureSizeSelect indexOfSelectedItem]];
	captureSize = NSMakeSize(size[0],size[1]);
	captureFormatChanged = YES;
	[camera stop];
	[camera setCaptureSize:captureSize format:captureFormat];
	[camera start];
}

-(IBAction)captureFormatChanged:(id)sender{
	captureFormat = (int)[captureFormatSelect selectedTag];
	captureFormatChanged = YES;
	[camera stop];
	[camera setCaptureSize:captureSize format:captureFormat];
	[camera start];
}

@end

static void CameraCallback(QTCamera *capture, void **buffers, void *context){
	[(AppDelegate*)context captureFrame:buffers];
}

@interface MainWindow (){
	NSArray *acceptFileTypes;
}
@end

@implementation MainWindow

- (void)dealloc{
    [acceptFileTypes release];
    [super dealloc];
}

-(void)awakeFromNib{
	acceptFileTypes = @[@"mov",@"m4v",@"mp4"].retain;
	[self registerForDraggedTypes:[NSArray arrayWithObjects:NSFilenamesPboardType,nil]];
}

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
    NSArray *files = [[sender draggingPasteboard] propertyListForType:NSFilenamesPboardType];
	if( !files || [files count] == 0 ) {
		return NSDragOperationNone;
    }
	BOOL isdir;
	NSFileManager *mgr = [NSFileManager defaultManager];
	for( NSString *path in files ){
		[mgr fileExistsAtPath:path isDirectory: &isdir];
		if( isdir ){ continue; }
		NSString *ext = [path pathExtension];
		for( NSString *type in acceptFileTypes ){
			if( [ext caseInsensitiveCompare:type]==0 ){
				return NSDragOperationCopy;
			}
		}
	}
	return NSDragOperationNone;
}

- (void)draggingExited:(id <NSDraggingInfo>)sender{}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender{
	NSArray *files = [[sender draggingPasteboard] propertyListForType:NSFilenamesPboardType];
	if ( !files || [files count] == 0 ) {
		return NO;
    }
	return YES;
}

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender
{
	NSArray *files = [[sender draggingPasteboard] propertyListForType:NSFilenamesPboardType];
	if ( !files || [files count] == 0 ) {return;}
	for( NSString *path in files ){
		NSString *ext = [path pathExtension];
		for( NSString *type in acceptFileTypes ){
			if( [ext caseInsensitiveCompare:type]==0 ){
				[(AppDelegate*)[NSApp delegate] dropFile:path];
			}
		}
	}
}

-(void)keyDown:(NSEvent *)theEvent{
	[(AppDelegate*)[NSApp delegate] keyDown:theEvent];
}

@end

